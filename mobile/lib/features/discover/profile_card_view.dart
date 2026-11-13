import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../moderation/report_sheet.dart';

/// Card profilo a tutta altezza per il Discover.
class ProfileCardView extends ConsumerWidget {
  const ProfileCardView({super.key, required this.profile});
  final ProfileCard profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final url = p.avatarPath == null
        ? null
        : ref.watch(signedUrlProvider((bucket: 'avatars', path: p.avatarPath!))).valueOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: WgfColors.electricViolet.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.network(url, fit: BoxFit.cover, cacheWidth: 1080)
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [WgfColors.darkViolet, WgfColors.black, WgfColors.electricViolet],
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.9,
                    child: Text(
                      p.name.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 160, fontWeight: FontWeight.w900, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            // sfumatura per la leggibilità
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Colors.transparent, Color(0xF2050409)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.age != null ? '${p.name}, ${p.age}' : p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (p.verifiedAdult) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified_rounded, color: Color(0xFFC084FC)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: WgfColors.muted),
                      const SizedBox(width: 4),
                      Text(p.city, style: const TextStyle(color: WgfColors.muted)),
                      const SizedBox(width: 10),
                      Text('@${p.username}', style: const TextStyle(color: WgfColors.muted)),
                    ],
                  ),
                  if (p.bio != null && p.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(p.bio!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in p.favoriteWgfCharacters.take(3)) TagChip(c, icon: Icons.bolt_rounded),
                      for (final g in p.favoriteGames.take(2)) TagChip(g, icon: Icons.sports_esports_rounded),
                      for (final i in p.interests.take(4)) TagChip(i),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dettagli profilo in un pannello a scorrimento.
Future<void> showProfileSheet(BuildContext context, ProfileCard p) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: WgfColors.surface,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ProfileDetails(profile: p, controller: scroll),
    ),
  );
}

class ProfileDetails extends ConsumerWidget {
  const ProfileDetails({super.key, required this.profile, this.controller, this.showActions = true});
  final ProfileCard profile;
  final ScrollController? controller;
  final bool showActions;

  Widget _section(String title, List<String> items, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: WgfColors.electricViolet),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final i in items) TagChip(i)]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return ListView(
      controller: controller,
      shrinkWrap: controller == null,
      physics: controller == null ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Center(child: UserAvatar(name: p.name, path: p.avatarPath, size: 110, ring: true)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            p.age != null ? '${p.name}, ${p.age}' : p.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Center(child: Text('@${p.username} · ${p.city}', style: const TextStyle(color: WgfColors.muted))),
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(p.bio!, textAlign: TextAlign.center),
        ],
        _section('Personaggi WGF preferiti', p.favoriteWgfCharacters, Icons.bolt_rounded),
        _section('Videogiochi preferiti', p.favoriteGames, Icons.sports_esports_rounded),
        _section('Interessi', p.interests, Icons.interests_rounded),
        _section('Cerca', p.friendshipPreferences, Icons.handshake_rounded),
        if (showActions) ...[
          const SizedBox(height: 24),
          if (controller != null)
            OutlinedButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/user/${p.id}');
            },
            icon: const Icon(Icons.person_rounded),
            label: const Text('Apri profilo completo'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => showReportSheet(context, ref, targetType: 'profile', targetId: p.id, userIdToBlock: p.id),
                  icon: const Icon(Icons.flag_outlined, color: WgfColors.danger),
                  label: const Text('Segnala'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    if (await confirmBlock(context, ref, p.id, p.name)) nav.pop();
                  },
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Blocca'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
