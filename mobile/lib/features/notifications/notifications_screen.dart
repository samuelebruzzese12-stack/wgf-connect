import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../announcements/announcements.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  (IconData, String) _describe(AppNotification n) => switch (n.kind) {
        'match' => (Icons.favorite_rounded, 'Nuovo match! Scrivi il primo messaggio'),
        'message' => (Icons.chat_bubble_rounded, 'Nuovo messaggio'),
        'like' => (n.payload['super'] == true ? Icons.star_rounded : Icons.thumb_up_alt_rounded,
            n.payload['super'] == true ? 'Qualcuno ti ha mandato un Super Like!' : 'Il tuo post è piaciuto'),
        'comment' => (Icons.mode_comment_rounded, 'Nuovo commento al tuo post'),
        'reply' => (Icons.reply_rounded, 'Hanno risposto al tuo commento'),
        'event' => (Icons.event_rounded, 'Novità su un evento'),
        'community' => (Icons.groups_rounded, 'Aggiornamento della community'),
        'creator' => (Icons.auto_awesome_rounded, 'Sentinel: ${n.payload['title'] ?? 'nuovo aggiornamento'}'),
        'friend_request' => (Icons.person_add_rounded, 'Nuova richiesta di amicizia'),
        'moderation' => (Icons.shield_rounded, 'Comunicazione dai moderatori'),
        'announcement' => (Icons.campaign_rounded, '📢 ${n.payload['title'] ?? 'Comunicazione ufficiale'}'),
        _ => (Icons.notifications_rounded, 'Notifica'),
      };

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    final p = n.payload;
    switch (n.kind) {
      case 'announcement':
        final id = p['announcement_id'] as String?;
        if (id == null) return;
        final a = await ref.read(announcementsRepoProvider).byId(id);
        if (a != null && context.mounted) await showAnnouncementDialog(context, a);
      case 'match':
      case 'message':
        if (p['conversation_id'] != null) context.push('/chat/${p['conversation_id']}');
      case 'comment':
      case 'reply':
      case 'like':
        if (p['post_id'] != null) context.push('/post/${p['post_id']}');
      case 'creator':
        context.push('/sentinel');
      case 'event':
        if (p['event_id'] != null) context.push('/events/${p['event_id']}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsStreamProvider);
    final requests = ref.watch(pendingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationRepoProvider).markAllRead(),
            child: const Text('Segna tutte lette'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ...requests.when<List<Widget>>(
            data: (list) => list.isEmpty
                ? []
                : [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Richieste di amicizia', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    for (final r in list) _FriendRequestTile(r: r),
                    const Divider(),
                  ],
            loading: () => [],
            error: (_, __) => [],
          ),
          ...notifs.when<List<Widget>>(
            data: (list) => list.isEmpty
                ? [const SizedBox(height: 80), const EmptyState(icon: Icons.notifications_none_rounded, title: 'Tutto tranquillo')]
                : [
                    for (var i = 0; i < list.length; i++)
                      FadeSlideIn(
                        index: i,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: list[i].isRead ? null : WgfColors.brandGradient,
                              color: list[i].isRead ? WgfColors.anthracite : null,
                            ),
                            child: Icon(_describe(list[i]).$1, size: 20),
                          ),
                          title: Text(
                            _describe(list[i]).$2,
                            style: TextStyle(fontWeight: list[i].isRead ? FontWeight.w400 : FontWeight.w700),
                          ),
                          subtitle: Text(timeAgo(list[i].createdAt)),
                          onTap: () {
                            ref.read(notificationRepoProvider).markRead(list[i].id);
                            _open(context, ref, list[i]);
                          },
                        ),
                      ),
                  ],
            loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
            error: (_, __) => [const EmptyState(icon: Icons.wifi_off_rounded, title: 'Impossibile caricare')],
          ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends ConsumerWidget {
  const _FriendRequestTile({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileCardProvider(r['requester_id'] as String)).valueOrNull;
    final name = profile?.name ?? 'Un fan';
    return ListTile(
      leading: UserAvatar(name: name, path: profile?.avatarPath, size: 44),
      title: Text(name),
      subtitle: profile == null ? null : Text('${profile.city} · @${profile.username}'),
      onTap: profile == null ? null : () => context.push('/user/${profile.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rifiuta',
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              await ref.read(discoverRepoProvider).respondFriendRequest(r['id'] as String, false);
              ref.invalidate(pendingFriendRequestsProvider);
            },
          ),
          IconButton.filled(
            tooltip: 'Accetta',
            icon: const Icon(Icons.check_rounded),
            onPressed: () async {
              final conv = await ref.read(discoverRepoProvider).respondFriendRequest(r['id'] as String, true);
              ref.invalidate(pendingFriendRequestsProvider);
              ref.invalidate(conversationsProvider);
              if (conv != null && context.mounted) context.push('/chat/$conv');
            },
          ),
        ],
      ),
    );
  }
}
