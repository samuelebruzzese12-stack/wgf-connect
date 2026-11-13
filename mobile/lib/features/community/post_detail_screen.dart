import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../moderation/report_sheet.dart';
import 'post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _ctrl = TextEditingController();
  String? _replyTo;
  String? _replyToName;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepoProvider).comment(widget.postId, text, parentId: _replyTo);
      _ctrl.clear();
      setState(() {
        _replyTo = null;
        _replyToName = null;
      });
      ref.invalidate(commentsProvider(widget.postId));
      ref.invalidate(postProvider(widget.postId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postProvider(widget.postId));
    final comments = ref.watch(commentsProvider(widget.postId));
    final me = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: asyncView(
              post,
              (p) => p == null
                  ? const EmptyState(icon: Icons.visibility_off_rounded, title: 'Post non disponibile')
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        PostCard(post: p, openOnTap: false),
                        const SizedBox(height: 16),
                        Text('Commenti', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...comments.when<List<Widget>>(
                          data: (list) => list.isEmpty
                              ? [const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Nessun commento. Scrivi il primo!', style: TextStyle(color: WgfColors.muted)),
                                )]
                              : [
                                  for (final c in list)
                                    _CommentTile(
                                      c: c,
                                      isReply: c['parent_id'] != null,
                                      isMine: c['author_id'] == me,
                                      onReply: () => setState(() {
                                        _replyTo = c['id'] as String;
                                        _replyToName = (c['profiles']?['username'] ?? '') as String;
                                      }),
                                    ),
                                ],
                          loading: () => [const Center(child: CircularProgressIndicator())],
                          error: (_, __) => [const Text('Impossibile caricare i commenti')],
                        ),
                      ],
                    ),
              onRetry: () => ref.invalidate(postProvider(widget.postId)),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              color: WgfColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyTo != null)
                    Row(
                      children: [
                        Text('Rispondi a @$_replyToName', style: const TextStyle(color: WgfColors.muted)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() => _replyTo = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(hintText: 'Scrivi un commento…', counterText: ''),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded, color: WgfColors.electricViolet),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.c, required this.isReply, required this.isMine, required this.onReply});
  final Map<String, dynamic> c;
  final bool isReply;
  final bool isMine;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prof = (c['profiles'] as Map?) ?? const {};
    final name = (prof['display_name'] ?? prof['username'] ?? 'utente') as String;
    final postId = context.findAncestorWidgetOfExactType<PostDetailScreen>()!.postId;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 36 : 0, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${c['author_id']}'),
            child: UserAvatar(name: name, path: prof['avatar_path'] as String?, size: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: WgfColors.anthracite, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text(timeAgo(DateTime.parse(c['created_at'] as String).toLocal()),
                          style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  HashtagText(c['body'] as String),
                  Row(
                    children: [
                      TextButton(onPressed: onReply, child: const Text('Rispondi')),
                      if (isMine)
                        TextButton(
                          onPressed: () async {
                            await ref.read(communityRepoProvider).deleteComment(c['id'] as String);
                            ref.invalidate(commentsProvider(postId));
                          },
                          child: const Text('Elimina'),
                        )
                      else
                        TextButton(
                          onPressed: () => showReportSheet(
                            context,
                            ref,
                            targetType: 'comment',
                            targetId: c['id'] as String,
                            userIdToBlock: c['author_id'] as String,
                          ),
                          child: const Text('Segnala'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
