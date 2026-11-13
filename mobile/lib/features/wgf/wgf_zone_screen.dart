import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/wgf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../community/compose_post_screen.dart';
import 'fan_card.dart';

/// Logo ufficiale WGF fornito dai titolari: mobile/assets/wgf/logo.png
const kWgfLogoAsset = 'assets/wgf/logo.png';

/// Pagina WGF ZONE aperta da un link (con la sua barra in alto).
class WgfZoneScreen extends StatelessWidget {
  const WgfZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WGF ZONE')),
      body: const WgfZoneBody(),
    );
  }
}

/// Il cuore WGF dell'app: squadra, storie, leggende, canali, quiz,
/// discussioni, raduni e contenuti ufficiali autorizzati.
class WgfZoneBody extends ConsumerWidget {
  const WgfZoneBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(wgfConfigProvider).valueOrNull;
    final content = ref.watch(officialContentProvider);
    final me = ref.watch(myProfileProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(wgfConfigProvider);
        ref.invalidate(officialContentProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          FadeSlideIn(child: _Hero(authorized: cfg?.authorized == true)),
          const SizedBox(height: 16),
          if (me != null) ...[
            _Title('La tua tessera', Icons.badge_rounded),
            FadeSlideIn(index: 1, child: FanCard(profile: me)),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Inclinala col dito · tieni premuto per condividerla',
                  textAlign: TextAlign.center, style: TextStyle(color: WgfColors.muted, fontSize: 12)),
            ),
            const SizedBox(height: 18),
          ],
          _Title('Ultimi video', Icons.smart_display_rounded),
          const _LatestVideos(),
          const SizedBox(height: 22),

          // Quiz + badge
          FadeSlideIn(
            index: 1,
            child: _GoldCard(
              onTap: () => context.push('/wgf/quiz'),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 40, color: WgfColors.lionGold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Quanto conosci i WGF?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(
                      (me?.wgfQuizScore ?? 0) > 0
                          ? 'Il tuo record: ${me!.wgfQuizScore}% · ${quizBadge(me.wgfQuizScore)}'
                          : 'Fai il quiz e conquista il tuo badge da leone',
                      style: const TextStyle(color: WgfColors.muted),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
          const SizedBox(height: 22),

          _Title('La squadra WGF', Icons.groups_rounded),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kWgfTeam.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final m = kWgfTeam[i];
                return FadeSlideIn(
                  index: i,
                  child: SizedBox(
                    width: 150,
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => _showMember(context, m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.lionGradient),
                            child: Text(m.name[0],
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
                          ),
                          const Spacer(),
                          Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(m.role, maxLines: 2, style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          _Title('Serie, libri e fumetti', Icons.menu_book_rounded),
          for (var i = 0; i < kWgfStories.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                index: i,
                child: GlassCard(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(gradient: WgfColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        kWgfStories[i].kind.contains('umetto') ? Icons.auto_stories_rounded : Icons.menu_book_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kWgfStories[i].title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(kWgfStories[i].kind, style: const TextStyle(color: WgfColors.lionGold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(kWgfStories[i].description, style: const TextStyle(color: WgfColors.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 12),

          _Title('Le leggende', Icons.visibility_rounded),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in kWgfLegends)
                ActionChip(
                  avatar: const Icon(Icons.local_fire_department_rounded, size: 18, color: WgfColors.lionOrange),
                  label: Text(l.$1),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.$1),
                      content: Text(l.$2),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/compose', extra: ComposeOptions(hashtag: 'wgf'));
                          },
                          child: const Text('Scrivi una teoria'),
                        ),
                        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),

          _Title('Vivi la community', Icons.bolt_rounded),
          Row(children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.forum_rounded,
                label: 'Discussioni #WGF',
                onTap: () => context.push('/compose', extra: const ComposeOptions(hashtag: 'wgf')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(icon: Icons.groups_rounded, label: 'Gruppi WGF', onTap: () => context.push('/groups')),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ActionTile(icon: Icons.event_rounded, label: 'Raduni WGF', onTap: () => context.push('/events')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.brush_rounded,
                label: 'Pubblica fan art',
                onTap: () => context.push('/compose', extra: const ComposeOptions(hashtag: 'fanart')),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          _Title('Canali ufficiali', Icons.play_circle_rounded),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final l in kWgfLinks)
                ListTile(
                  leading: Icon(
                    l.label == 'YouTube'
                        ? Icons.smart_display_rounded
                        : l.label == 'Twitch'
                            ? Icons.live_tv_rounded
                            : Icons.photo_camera_rounded,
                    color: WgfColors.lionGold,
                  ),
                  title: Text(l.label),
                  subtitle: Text(l.handle),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                ),
            ]),
          ),
          const SizedBox(height: 22),

          // Contenuti ufficiali (visibili solo con autorizzazione attiva)
          if (cfg?.authorized == true)
            ...content.when<List<Widget>>(
              data: (items) => items.isEmpty
                  ? []
                  : [
                      _Title('Dal mondo WGF', Icons.newspaper_rounded),
                      for (final it in items.where((x) => x['kind'] != 'logo'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            onTap: it['link_url'] == null
                                ? null
                                : () => launchUrl(Uri.parse(it['link_url'] as String),
                                    mode: LaunchMode.externalApplication),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text(timeAgo(DateTime.parse(it['created_at'] as String).toLocal()),
                                  style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                              if (it['image_path'] != null) ...[
                                const SizedBox(height: 8),
                                PrivateImage(bucket: 'official', path: it['image_path'] as String, height: 200),
                              ],
                              if (it['body'] != null) ...[
                                const SizedBox(height: 6),
                                Text(it['body'] as String),
                              ],
                              if (it['credits'] != null)
                                Text(it['credits'] as String, style: const TextStyle(color: WgfColors.muted, fontSize: 11)),
                            ]),
                          ),
                        ),
                    ],
              loading: () => [],
              error: (_, __) => [],
            ),

          const SizedBox(height: 8),
          Text(
            cfg?.authorized == true && cfg!.note.isNotEmpty
                ? cfg.note
                : 'WGF CONNECT è una community creata dai fan per i fan, non è un canale ufficiale dei WGF.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: WgfColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showMember(BuildContext context, WgfMember m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.lionGradient),
            child: Text(m.name[0], style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
          const SizedBox(height: 12),
          Text(m.name, style: Theme.of(ctx).textTheme.headlineSmall),
          Text(m.role, style: const TextStyle(color: WgfColors.lionGold)),
          const SizedBox(height: 12),
          Text(m.description, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/groups');
            },
            icon: const Icon(Icons.groups_rounded),
            label: const Text('Trova il gruppo dei fan'),
          ),
        ]),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.authorized});
  final bool authorized;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment(-1 + _c.value, -1),
            end: Alignment(1, 1 - _c.value),
            colors: const [Color(0xFF2B1300), WgfColors.darkViolet, Color(0xFF120A1F)],
          ),
          border: Border.all(color: WgfColors.lionGold.withValues(alpha: 0.5 + 0.3 * _c.value), width: 1.4),
          boxShadow: [
            BoxShadow(color: WgfColors.lionOrange.withValues(alpha: 0.18 + 0.15 * _c.value), blurRadius: 26),
          ],
        ),
        child: child,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 90,
            child: widget.authorized
                ? Image.asset(kWgfLogoAsset, errorBuilder: (_, __, ___) => const _WgfWordmark())
                : const _WgfWordmark(),
          ),
          const SizedBox(height: 6),
          const Text(kWgfChannelName, style: TextStyle(fontWeight: FontWeight.w700, color: WgfColors.lionGold)),
          const SizedBox(height: 10),
          const Text(
            '"$kWgfCatchphrase"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text('Il punto d\'incontro dei leoni della community', style: TextStyle(color: WgfColors.muted)),
        ],
      ),
    );
  }
}

class _WgfWordmark extends StatelessWidget {
  const _WgfWordmark();
  @override
  Widget build(BuildContext context) => Center(
        child: ShaderMask(
          shaderCallback: (r) => WgfColors.lionGradient.createShader(r),
          child: const Text('WGF',
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 10)),
        ),
      );
}

class _GoldCard extends StatelessWidget {
  const _GoldCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(gradient: WgfColors.lionGradient, borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: WgfColors.surface, borderRadius: BorderRadius.circular(19)),
        child: child,
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap!, child: box);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: WgfColors.lionGold, size: 28),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, color: WgfColors.lionGold, size: 20),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Ultimi video del canale (titolo, data, visualizzazioni): si guardano su YouTube.
class _LatestVideos extends ConsumerWidget {
  const _LatestVideos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(wgfVideosProvider);
    Widget openChannel() => OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(kWgfLinks.first.url), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.smart_display_rounded),
          label: const Text('Apri il canale su YouTube'),
        );
    return videos.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => openChannel(),
      data: (list) {
        if (list.isEmpty) return openChannel();
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final v = list[i];
              final published = DateTime.tryParse((v['published'] ?? '') as String)?.toLocal();
              final views = ((v['views'] ?? 0) as num).toInt();
              return FadeSlideIn(
                index: i,
                child: SizedBox(
                  width: 230,
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => launchUrl(Uri.parse(v['url'] as String), mode: LaunchMode.externalApplication),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.lionGradient),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                          ),
                          const SizedBox(width: 8),
                          if (i == 0) const TagChip('NUOVO', icon: Icons.fiber_new_rounded),
                          const Spacer(),
                          if (published != null)
                            Text(timeAgo(published), style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                        ]),
                        const SizedBox(height: 10),
                        Text((v['title'] ?? '') as String,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (views > 0)
                          Text('${NumberFormat.compact(locale: 'it').format(views)} visualizzazioni',
                              style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
