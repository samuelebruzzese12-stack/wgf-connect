import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import 'compose_post_screen.dart';
import 'post_card.dart';

/// Home della community: feed personalizzabile per sezione.
class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});
  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  static const _sections = <(String, String?, IconData)>[
    ('Per te', null, Icons.auto_awesome_rounded),
    ('WGF', 'wgf', Icons.bolt_rounded),
    ('Gaming', 'gaming', Icons.sports_esports_rounded),
    ('Fan art', 'fanart', Icons.brush_rounded),
    ('Discussioni', 'discussione', Icons.forum_rounded),
  ];
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final q = FeedQuery(hashtag: _sections[_section].$2);
    final feed = ref.watch(feedProvider(q));
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _sections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = i == _section;
              return GestureDetector(
                onTap: () => setState(() => _section = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: selected ? WgfColors.brandGradient : null,
                    color: selected ? null : WgfColors.anthracite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(_sections[i].$3, size: 16),
                      const SizedBox(width: 6),
                      Text(_sections[i].$1, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(feedProvider(q).future),
            child: asyncView(
              feed,
              (posts) => posts.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        if (_section == 0) const _FeaturedBanners(),
                        const SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.dynamic_feed_rounded,
                          title: 'Ancora nessun post qui',
                          message: 'Rompi il ghiaccio: scrivi il primo!',
                          action: FilledButton(
                            onPressed: () => context.push(
                              '/compose',
                              extra: ComposeOptions(hashtag: _sections[_section].$2),
                            ),
                            child: const Text('Scrivi un post'),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      itemCount: posts.length + (_section <= 1 ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        if (_section == 0 && i == 0) return const _FeaturedBanners();
                        if (_section == 1 && i == 0) {
                          return GlassCard(
                            onTap: () => context.push('/wgf'),
                            child: const Row(children: [
                              Icon(Icons.bolt_rounded, color: WgfColors.electricViolet),
                              SizedBox(width: 10),
                              Expanded(child: Text('Apri la WGF ZONE: foto, notizie e contenuti ufficiali')),
                              Icon(Icons.chevron_right_rounded),
                            ]),
                          );
                        }
                        final idx = _section <= 1 ? i - 1 : i;
                        return FadeSlideIn(index: idx, child: PostCard(post: posts[idx]));
                      },
                    ),
              onRetry: () => ref.invalidate(feedProvider(q)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Riquadri fissi in cima al feed: WGF ZONE e pagina del fondatore SENTINEL.
class _FeaturedBanners extends StatelessWidget {
  const _FeaturedBanners();

  @override
  Widget build(BuildContext context) {
    Widget card(String title, String sub, IconData icon, Gradient g, Color fg, String route) => Expanded(
          child: Pressable(
            onTap: () => context.push(route),
            child: Container(
              height: 96,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: fg),
                  const Spacer(),
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        card('WGF ZONE', 'Squadra, storie, quiz', Icons.bolt_rounded, WgfColors.lionGradient, Colors.black, '/wgf'),
        const SizedBox(width: 10),
        card('SENTINEL', 'Il fondatore', Icons.auto_awesome_rounded, WgfColors.brandGradient, Colors.white, '/sentinel'),
      ]),
    );
  }
}
