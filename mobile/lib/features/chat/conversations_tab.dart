import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';

class ConversationsTab extends ConsumerWidget {
  const ConversationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // si aggiorna da solo quando arriva una nuova notifica di messaggio/match
    ref.listen(notificationsStreamProvider, (prev, next) {
      if ((prev?.valueOrNull?.length ?? 0) != (next.valueOrNull?.length ?? 0)) {
        ref.invalidate(conversationsProvider);
      }
    });
    final convs = ref.watch(conversationsProvider);
    final me = ref.watch(currentUserIdProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(conversationsProvider.future),
      child: asyncView(
        convs,
        (list) => list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Nessuna conversazione',
                  message: 'Le chat si aprono quando c\'è un match o un\'amicizia accettata.',
                  action: FilledButton(
                    onPressed: () => context.push('/fanfinder'),
                    child: const Text('Trova fan'),
                  ),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final last = c.lastMessage;
                  String preview;
                  if (last == null) {
                    preview = c.matchMode == 'dating' ? 'Nuovo match! Rompi il ghiaccio 💜' : 'Salutalo per primo 👋';
                  } else if (last['deleted'] == true) {
                    preview = 'Messaggio eliminato';
                  } else if (last['has_image'] == true) {
                    preview = '📷 Immagine';
                  } else {
                    preview = (last['body'] ?? '') as String;
                  }
                  if (last != null && last['sender_id'] == me) preview = 'Tu: $preview';
                  return FadeSlideIn(
                    index: i,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(name: c.otherName, path: c.otherAvatar, size: 52, ring: c.unread > 0),
                          if (c.matchMode == 'dating')
                            const Positioned(
                              right: -2,
                              bottom: -2,
                              child: Icon(Icons.favorite_rounded, size: 18, color: WgfColors.electricViolet),
                            ),
                        ],
                      ),
                      title: Text(
                        c.otherName,
                        style: TextStyle(fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600),
                      ),
                      subtitle: Text(
                        c.isActive ? preview : 'Conversazione chiusa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.unread > 0 ? WgfColors.white : WgfColors.muted),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(timeAgo(c.lastActivity), style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                          const SizedBox(height: 4),
                          if (c.unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: WgfColors.brandGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${c.unread}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      onTap: () async {
                        await context.push('/chat/${c.id}');
                        ref.invalidate(conversationsProvider);
                      },
                    ),
                  );
                },
              ),
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
    );
  }
}
