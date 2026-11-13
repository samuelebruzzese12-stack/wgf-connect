import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../community/compose_post_screen.dart';

/// Logo ufficiale WGF fornito dai titolari: mobile/assets/wgf/logo.png
const kWgfLogoAsset = 'assets/wgf/logo.png';

/// WGF ZONE: logo, galleria e notizie ufficiali (caricati dal pannello admin,
/// visibili solo quando l'autorizzazione dei titolari è attiva).
class WgfZoneScreen extends ConsumerWidget {
  const WgfZoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(wgfConfigProvider);
    final content = ref.watch(officialContentProvider);

    return Scaffold(
      body: AuroraBackground(
        intensity: 1.1,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(wgfConfigProvider);
            ref.invalidate(officialContentProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                backgroundColor: WgfColors.black,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('WGF ZONE'),
                  background: Center(
                    child: FadeSlideIn(
                      child: SizedBox(
                        height: 150,
                        child: cfg.valueOrNull?.authorized == true
                            ? Image.asset(
                                kWgfLogoAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const _TextMark(),
                              )
                            : const _TextMark(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList.list(
                  children: [
                    GlassCard(
                      onTap: () => context.push('/compose', extra: const ComposeOptions(hashtag: 'wgf')),
                      child: const Row(children: [
                        Icon(Icons.forum_rounded, color: WgfColors.electricViolet),
                        SizedBox(width: 10),
                        Expanded(child: Text('Scrivi nella discussione #WGF')),
                        Icon(Icons.chevron_right_rounded),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    ...asyncContent(context, ref, content, cfg.valueOrNull),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> asyncContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> content,
    ({bool authorized, String note})? cfg,
  ) {
    if (cfg != null && !cfg.authorized) {
      return [
        const EmptyState(
          icon: Icons.bolt_rounded,
          title: 'Contenuti ufficiali in arrivo',
          message: 'Qui compariranno foto, notizie e materiali ufficiali dei WGF. Intanto partecipa alla discussione #WGF!',
        ),
      ];
    }
    return content.when<List<Widget>>(
      loading: () => [const Center(child: CircularProgressIndicator())],
      error: (_, __) => [const EmptyState(icon: Icons.wifi_off_rounded, title: 'Impossibile caricare')],
      data: (items) {
        final gallery = items.where((i) => i['kind'] == 'gallery' && i['image_path'] != null).toList();
        final news = items.where((i) => i['kind'] != 'gallery' && i['kind'] != 'logo').toList();
        return [
          if (gallery.isNotEmpty) ...[
            Text('Galleria', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => FadeSlideIn(
                  index: i,
                  child: GestureDetector(
                    onTap: () => _openImage(context, gallery[i]),
                    child: SizedBox(
                      width: 180,
                      child: PrivateImage(bucket: 'official', path: gallery[i]['image_path'] as String, height: 220),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (news.isNotEmpty) Text('Novità', style: Theme.of(context).textTheme.titleLarge),
          for (var i = 0; i < news.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FadeSlideIn(index: i, child: _NewsCard(item: news[i])),
            ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.bolt_rounded, title: 'Nessun contenuto ufficiale per ora'),
          const SizedBox(height: 24),
          if (cfg != null && cfg.note.isNotEmpty)
            Text(cfg.note, textAlign: TextAlign.center, style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
        ];
      },
    );
  }

  void _openImage(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              child: PrivateImage(bucket: 'official', path: item['image_path'] as String, height: 420),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (item['credits'] != null)
                  Text(item['credits'] as String, style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextMark extends StatelessWidget {
  const _TextMark();
  @override
  Widget build(BuildContext context) => Center(
        child: ShaderMask(
          shaderCallback: (r) => WgfColors.brandGradient.createShader(r),
          child: const Text('WGF',
              style: TextStyle(fontSize: 84, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 10)),
        ),
      );
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final link = item['link_url'] as String?;
    return GlassCard(
      onTap: link == null ? null : () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            TagChip(switch (item['kind']) { 'video' => 'Video', 'info' => 'Info', _ => 'Notizia' }, icon: Icons.bolt_rounded),
            const Spacer(),
            Text(timeAgo(DateTime.parse(item['created_at'] as String).toLocal()),
                style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(item['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (item['image_path'] != null) ...[
            const SizedBox(height: 10),
            PrivateImage(bucket: 'official', path: item['image_path'] as String, height: 200),
          ],
          if (item['body'] != null) ...[
            const SizedBox(height: 8),
            Text(item['body'] as String, style: const TextStyle(height: 1.5)),
          ],
          if (link != null) ...[
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFFC084FC)),
              SizedBox(width: 6),
              Text('Apri', style: TextStyle(color: Color(0xFFC084FC))),
            ]),
          ],
          if (item['credits'] != null) ...[
            const SizedBox(height: 6),
            Text(item['credits'] as String, style: const TextStyle(color: WgfColors.muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
