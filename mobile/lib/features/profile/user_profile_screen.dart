import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../community/post_card.dart';
import '../discover/profile_card_view.dart';

/// Profilo di un altro utente (solo se compatibile: stessa fascia, nessun blocco).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    if (userId == me) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
    }
    final profile = ref.watch(profileCardProvider(userId));
    final posts = ref.watch(feedProvider(FeedQuery(authorId: userId)));

    return Scaffold(
      appBar: AppBar(),
      body: asyncView(
        profile,
        (p) => p == null
            ? const EmptyState(
                icon: Icons.visibility_off_rounded,
                title: 'Profilo non disponibile',
                message: 'L\'utente potrebbe aver cambiato le impostazioni o non essere raggiungibile.',
              )
            : ListView(
                children: [
                  ProfileDetails(profile: p),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GradientButton(
                      label: 'Chiedi l\'amicizia',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(discoverRepoProvider).sendFriendRequest(p.id);
                          messenger.showSnackBar(const SnackBar(content: Text('Richiesta inviata!')));
                        } catch (e) {
                          final msg = '$e'.contains('friendships_pair_uidx')
                              ? 'Esiste già una richiesta o un\'amicizia con questa persona.'
                              : friendlyError(e);
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Post di ${p.name}', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ...posts.when<List<Widget>>(
                    data: (list) => list.isEmpty
                        ? [const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessun post.', style: TextStyle(color: WgfColors.muted)),
                          )]
                        : [
                            for (final post in list)
                              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: PostCard(post: post)),
                          ],
                    loading: () => [const Center(child: CircularProgressIndicator())],
                    error: (_, __) => [],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
        onRetry: () => ref.invalidate(profileCardProvider(userId)),
      ),
    );
  }
}
