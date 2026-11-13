import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../community/compose_post_screen.dart';
import '../community/post_card.dart';
import '../moderation/report_sheet.dart';

IconData _iconFor(String category) => switch (category) {
      'wgf' => Icons.bolt_rounded,
      'gaming' => Icons.sports_esports_rounded,
      'fanart' => Icons.brush_rounded,
      'city' => Icons.location_city_rounded,
      _ => Icons.groups_rounded,
    };

/// Gruppi tematici: WGF, gaming, fan art, città.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final desc = TextEditingController();
    var cat = 'wgf';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Nuovo gruppo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'Nome')),
                TextField(
                  controller: desc,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in kGroupCategories.entries)
                      ChoiceChip(label: Text(c.value), selected: cat == c.key, onSelected: (_) => set(() => cat = c.key)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crea')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().length < 3) return;
    try {
      await ref.read(communityRepoProvider).createGroup(name.text.trim(), desc.text.trim(), cat);
      ref.invalidate(groupsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gruppi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crea gruppo'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(groupsProvider.future),
        child: asyncView(
          groups,
          (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 60),
                  EmptyState(icon: Icons.groups_rounded, title: 'Nessun gruppo', message: 'Crea il primo gruppo della community!'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final g = list[i];
                    return FadeSlideIn(
                      index: i,
                      child: GlassCard(
                        onTap: () => context.push('/groups/${g.id}', extra: g),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(gradient: WgfColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                              child: Icon(_iconFor(g.category)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  Text('${g.members} membri · ${kGroupCategories[g.category] ?? g.category}',
                                      style: const TextStyle(color: WgfColors.muted)),
                                ],
                              ),
                            ),
                            if (g.joined) const Icon(Icons.check_circle_rounded, color: WgfColors.electricViolet),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          onRetry: () => ref.invalidate(groupsProvider),
        ),
      ),
    );
  }
}

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId, this.initial});
  final String groupId;
  final GroupItem? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(groupsProvider).valueOrNull?.where((x) => x.id == groupId).firstOrNull ?? initial;
    final feed = ref.watch(feedProvider(FeedQuery(groupId: groupId)));
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.groups_rounded, title: 'Gruppo non disponibile'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Segnala gruppo',
            onPressed: () => showReportSheet(context, ref, targetType: 'group', targetId: g.id),
          ),
        ],
      ),
      floatingActionButton: g.joined
          ? FloatingActionButton(
              onPressed: () => context.push('/compose', extra: ComposeOptions(groupId: g.id)),
              child: const Icon(Icons.edit_rounded),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_iconFor(g.category), color: WgfColors.electricViolet),
                  const SizedBox(width: 8),
                  Text('${g.members} membri', style: const TextStyle(color: WgfColors.muted)),
                ]),
                if (g.description != null && g.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(g.description!),
                ],
                const SizedBox(height: 12),
                g.joined
                    ? OutlinedButton(
                        onPressed: () async {
                          await ref.read(communityRepoProvider).leaveGroup(g.id);
                          ref.invalidate(groupsProvider);
                        },
                        child: const Text('Esci dal gruppo'),
                      )
                    : GradientButton(
                        label: 'Unisciti',
                        icon: Icons.group_add_rounded,
                        onPressed: () async {
                          await ref.read(communityRepoProvider).joinGroup(g.id);
                          ref.invalidate(groupsProvider);
                        },
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...feed.when<List<Widget>>(
            data: (posts) => posts.isEmpty
                ? [const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nessun post nel gruppo.', textAlign: TextAlign.center, style: TextStyle(color: WgfColors.muted)),
                  )]
                : [
                    for (final p in posts)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: PostCard(post: p)),
                  ],
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (_, __) => [const Text('Impossibile caricare i post')],
          ),
        ],
      ),
    );
  }
}
