import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../moderation/report_sheet.dart';

const _quickEmoji = ['🦁', '😂', '❤️', '🔥', '👍', '😮', '😢', '🎮', '💜'];

/// Chat in tempo reale (Supabase Realtime).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _showEmoji = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(chatRepoProvider).markRead(widget.conversationId);
      await ref.read(notificationRepoProvider).markConversationRead(widget.conversationId);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepoProvider).sendText(widget.conversationId, text);
      _ctrl.clear();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      _snack('Immagine troppo grande (max 5 MB).');
      return;
    }
    try {
      await ref.read(chatRepoProvider).sendImage(widget.conversationId, bytes);
      _snack('Immagine inviata: sarà visibile dopo la revisione di sicurezza.');
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _messageMenu(ChatMessage m, bool mine) async {
    final canDelete = mine && !m.isDeleted && DateTime.now().difference(m.createdAt).inHours < 24;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Elimina per tutti'),
                subtitle: const Text('Possibile entro 24 ore dall\'invio'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: WgfColors.danger),
                title: const Text('Segnala messaggio'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await ref.read(chatRepoProvider).deleteMessage(m.id);
    } else if (action == 'report') {
      await showReportSheet(
        context,
        ref,
        targetType: m.imagePath != null ? 'image' : 'message',
        targetId: m.id,
        userIdToBlock: m.senderId,
      );
    }
  }

  Future<void> _chatMenu(Conversation? c) async {
    if (c == null || c.otherId == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Vedi profilo'),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            if (c.kind == 'match' && c.isActive)
              ListTile(
                leading: const Icon(Icons.heart_broken_rounded),
                title: const Text('Annulla match'),
                onTap: () => Navigator.pop(ctx, 'unmatch'),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: WgfColors.danger),
              title: const Text('Segnala utente'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: WgfColors.danger),
              title: const Text('Blocca'),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'profile':
        context.push('/user/${c.otherId}');
      case 'unmatch':
        final matchId = await ref.read(discoverRepoProvider).matchIdForConversation(c.id);
        if (matchId != null) await ref.read(discoverRepoProvider).unmatch(matchId);
        ref.invalidate(conversationsProvider);
        if (mounted) context.pop();
      case 'report':
        await showReportSheet(context, ref, targetType: 'profile', targetId: c.otherId!, userIdToBlock: c.otherId);
      case 'block':
        if (await confirmBlock(context, ref, c.otherId!, c.otherName) && mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final conv = ref.watch(conversationsProvider).valueOrNull?.where((c) => c.id == widget.conversationId).firstOrNull;

    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      final list = next.valueOrNull ?? const <ChatMessage>[];
      if (list.length != _lastCount) {
        _lastCount = list.length;
        if (list.isNotEmpty && list.last.senderId != me) _markRead();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          }
        });
      }
    });

    final active = conv?.isActive ?? true;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: conv?.otherId == null ? null : () => context.push('/user/${conv!.otherId}'),
          child: Row(
            children: [
              UserAvatar(name: conv?.otherName ?? '', path: conv?.otherAvatar, size: 38),
              const SizedBox(width: 10),
              Expanded(child: Text(conv?.otherName ?? 'Chat', overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        actions: [IconButton(onPressed: () => _chatMenu(conv), icon: const Icon(Icons.more_vert_rounded))],
      ),
      body: AuroraBackground(
        intensity: 0.35,
        child: Column(
          children: [
            Expanded(
              child: asyncView(
                messages,
                (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.waving_hand_rounded,
                      title: 'Inizia la conversazione',
                      message: 'Sii gentile. Non condividere indirizzi, numeri di telefono o dati bancari.',
                    );
                  }
                  final reversed = list.reversed.toList();
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: reversed.length,
                    itemBuilder: (_, i) {
                      final m = reversed[i];
                      final mine = m.senderId == me;
                      final next = i > 0 ? reversed[i - 1] : null;
                      final grouped = next != null && next.senderId == m.senderId;
                      return _Bubble(
                        key: ValueKey(m.id),
                        m: m,
                        mine: mine,
                        grouped: grouped,
                        isLastMine: mine && i == reversed.indexWhere((x) => x.senderId == me),
                        onLongPress: () => _messageMenu(m, mine),
                      );
                    },
                  );
                },
              ),
            ),
            if (!active)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: WgfColors.surface,
                child: const Text(
                  'Questa conversazione è stata chiusa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: WgfColors.muted),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Container(
                  color: WgfColors.surface,
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _showEmoji
                            ? SizedBox(
                                height: 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final e in _quickEmoji)
                                      TextButton(
                                        onPressed: () {
                                          _ctrl.text += e;
                                          _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
                                        },
                                        child: Text(e, style: const TextStyle(fontSize: 22)),
                                      ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _showEmoji = !_showEmoji),
                            icon: const Icon(Icons.emoji_emotions_outlined),
                          ),
                          IconButton(onPressed: _sendImage, icon: const Icon(Icons.image_outlined)),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 2000,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(hintText: 'Messaggio…', counterText: ''),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Pressable(
                            onTap: _send,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.brandGradient),
                              child: const Icon(Icons.send_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.m,
    required this.mine,
    required this.grouped,
    required this.isLastMine,
    required this.onLongPress,
  });
  final ChatMessage m;
  final bool mine;
  final bool grouped;
  final bool isLastMine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(mine ? 20 : 6),
      bottomRight: Radius.circular(mine ? 6 : 20),
    );

    Widget content;
    if (m.isDeleted) {
      content = const Text('Messaggio eliminato', style: TextStyle(fontStyle: FontStyle.italic, color: WgfColors.muted));
    } else if (m.imageStatus == 'rejected') {
      content = const Text('Immagine rimossa dalla moderazione', style: TextStyle(color: WgfColors.muted));
    } else if (m.imagePath != null) {
      if (m.imageStatus == 'approved') {
        content = PrivateImage(bucket: 'chat-images', path: m.imagePath!, height: 220);
      } else {
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.hourglass_top_rounded, size: 16),
          const SizedBox(width: 6),
          Text(mine ? 'Immagine in revisione' : 'Immagine in arrivo (in revisione)'),
        ]);
      }
    } else {
      content = Text(m.body ?? '', style: const TextStyle(fontSize: 15.5));
    }

    IconData? tick;
    Color tickColor = WgfColors.muted;
    if (mine && !m.isDeleted) {
      if (m.readAt != null) {
        tick = Icons.done_all_rounded;
        tickColor = const Color(0xFFC084FC);
      } else if (m.deliveredAt != null) {
        tick = Icons.done_all_rounded;
      } else {
        tick = Icons.done_rounded;
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: child),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: EdgeInsets.only(top: grouped ? 2 : 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
            decoration: BoxDecoration(
              gradient: mine ? WgfColors.brandGradient : null,
              color: mine ? null : WgfColors.anthracite,
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.centerLeft, widthFactor: 1, child: content),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(clock(m.createdAt), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    if (tick != null && (isLastMine || m.readAt == null)) ...[
                      const SizedBox(width: 4),
                      Icon(tick, size: 14, color: tickColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
