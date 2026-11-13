import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/wgf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../community/post_card.dart';

class MyProfileTab extends ConsumerWidget {
  const MyProfileTab({super.key});

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    try {
      await ref.read(profileRepoProvider).uploadAvatar(bytes);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider);
    return asyncView(me, (MyProfile? p) {
      if (p == null) return const SizedBox.shrink();
      final posts = ref.watch(feedProvider(FeedQuery(authorId: p.id)));
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(feedProvider(FeedQuery(authorId: p.id)));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            FadeSlideIn(
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _changeAvatar(context, ref),
                        child: UserAvatar(name: p.name, path: p.avatarPath, size: 116, ring: true),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.brandGradient),
                          child: const Icon(Icons.camera_alt_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                  Text('@${p.username} · ${p.city}', style: const TextStyle(color: WgfColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                    if (p.isCreator) const TagChip('Fondatore', icon: Icons.auto_awesome_rounded)
                    else if (p.isStaff) const TagChip('Staff', icon: Icons.shield_rounded),
                    if (p.wgfQuizScore > 0) TagChip(quizBadge(p.wgfQuizScore), icon: Icons.emoji_events_rounded),
                  ]),
                  if (p.bio != null && p.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(p.bio!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final c in p.favoriteWgfCharacters) TagChip(c, icon: Icons.bolt_rounded),
                      for (final g in p.favoriteGames) TagChip(g, icon: Icons.sports_esports_rounded),
                      for (final i in p.interests) TagChip(i),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/profile/edit'),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Modifica profilo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Impostazioni'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('I tuoi post', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...posts.when<List<Widget>>(
              data: (list) => list.isEmpty
                  ? [const Text('Non hai ancora pubblicato nulla.', style: TextStyle(color: WgfColors.muted))]
                  : [for (final post in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: PostCard(post: post))],
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, __) => [const Text('Impossibile caricare i post')],
            ),
          ],
        ),
      );
    });
  }
}
