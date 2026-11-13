import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

/// Ritratto scelto dal fondatore: metti il file in assets/images/sentinel_portrait.png.
/// Se il file non c'è viene mostrato l'emblema originale disegnato in codice.
const kSentinelPortraitAsset = 'assets/images/sentinel_portrait.png';

const kSentinelManifesto = [
  'Mi chiamo Sentinel.',
  'Ho appena compiuto 18 anni e ho deciso che non voglio limitarmi a osservare il mondo mentre cambia.',
  'Voglio contribuire a cambiarlo.',
  'Ho tanti progetti, tante idee e ambizioni che vanno ben oltre la creazione di una semplice applicazione.',
  'WGF CONNECT è uno dei primi passi di un percorso molto più grande.',
  'Non sono qui per chiedervi di seguirmi ciecamente. Sono qui perché credo che le persone possano costruire qualcosa di straordinario quando decidono di collaborare.',
  'Ho bisogno del vostro aiuto, delle vostre idee, del vostro sostegno e della vostra partecipazione.',
  'Forse un giorno arriverà il momento in cui avrò bisogno che questa community mi appoggi anche in progetti molto più grandi.',
  'Spero che allora sarete ancora qui.',
  'Non cerco il potere per il potere.',
  'Non voglio comandare il mondo.',
  'Voglio avere la possibilità di contribuire a rivoluzionarlo.',
  'Voglio creare, innovare, costruire opportunità e dimostrare che anche una persona molto giovane, partendo da zero, può provare a realizzare qualcosa di importante.',
  'Sono determinato.',
  'Questo è soltanto l\'inizio.',
];

/// THE CREATOR – SENTINEL: pagina cinematografica del fondatore.
class SentinelScreen extends ConsumerStatefulWidget {
  const SentinelScreen({super.key});
  @override
  ConsumerState<SentinelScreen> createState() => _SentinelScreenState();
}

class _SentinelScreenState extends ConsumerState<SentinelScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _intro.dispose();
    _orbit.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(bool following) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(creatorRepoProvider);
    following ? await repo.unfollow() : await repo.follow();
    ref.invalidate(isFollowingSentinelProvider);
    ref.invalidate(sentinelFollowersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final following = ref.watch(isFollowingSentinelProvider).valueOrNull ?? false;
    final followers = ref.watch(sentinelFollowersProvider).valueOrNull;
    final updates = ref.watch(creatorUpdatesProvider);

    final title = CurvedAnimation(parent: _intro, curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic));
    final sub = CurvedAnimation(parent: _intro, curve: const Interval(0.55, 1, curve: Curves.easeOut));
    final portrait = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.5, curve: Curves.easeOutBack));

    return Scaffold(
      floatingActionButton: (me?.isCreator ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _showPublisher(context),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Pubblica'),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 560,
            backgroundColor: WgfColors.black,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: AuroraBackground(
                intensity: 1.2,
                child: SafeArea(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_intro, _orbit]),
                    builder: (context, _) => Column(
                      children: [
                        const SizedBox(height: 40),
                        Opacity(
                          opacity: sub.value,
                          child: const Text('THE CREATOR', style: TextStyle(letterSpacing: 8, color: WgfColors.muted)),
                        ),
                        const SizedBox(height: 18),
                        Transform.scale(
                          scale: 0.6 + 0.4 * portrait.value,
                          child: SizedBox.square(
                            dimension: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(size: const Size.square(190), painter: _OrbitPainter(_orbit.value)),
                                ClipOval(
                                  child: SizedBox.square(
                                    dimension: 140,
                                    child: Image.asset(
                                      kSentinelPortraitAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SentinelEmblem(size: 140),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Opacity(
                          opacity: title.value,
                          child: ShaderMask(
                            shaderCallback: (r) => LinearGradient(
                              colors: const [Colors.white, Color(0xFFC084FC), Colors.white],
                              stops: [0, (_orbit.value * 1.4).clamp(0.0, 1.0).toDouble(), 1],
                            ).createShader(r),
                            child: Text(
                              'SENTINEL',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontSize: 46,
                                    color: Colors.white,
                                    letterSpacing: 4 + 10 * title.value,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: sub.value,
                          child: const Text('FOUNDER & VISIONARY',
                              style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600, color: Color(0xFFC9A7FF))),
                        ),
                        const SizedBox(height: 22),
                        Opacity(
                          opacity: sub.value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    label: following ? 'Segui già' : 'SEGUI SENTINEL',
                                    icon: following ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                                    onPressed: () => _toggleFollow(following),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                                    onPressed: () => _showSupport(context),
                                    icon: const Icon(Icons.volunteer_activism_rounded),
                                    label: const Text('SOSTIENI'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (followers != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('$followers follower', style: const TextStyle(color: WgfColors.muted)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Manifesto'),
                Tab(text: 'Biografia e progetti'),
                Tab(text: 'Aggiornamenti'),
                Tab(text: 'Diario di sviluppo'),
                Tab(text: 'Community'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            const _ManifestoTab(),
            _UpdatesList(updates: updates, kinds: const ['bio', 'manifesto', 'future_project'],
                empty: 'Biografia e progetti futuri saranno pubblicati qui dal fondatore.'),
            _UpdatesList(updates: updates, kinds: const ['update'], empty: 'Nessun aggiornamento ancora.'),
            _UpdatesList(updates: updates, kinds: const ['devlog'], empty: 'Il diario di sviluppo partirà a breve.'),
            const _CommunityTab(),
          ],
        ),
      ),
    );
  }

  void _showSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Sostenere WGF CONNECT è gratuito: servono idee, partecipazione e persone.',
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_rounded, color: WgfColors.electricViolet),
              title: const Text('Proponi un\'idea'),
              onTap: () {
                Navigator.pop(ctx);
                _sendIdea(context, 'idea');
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_rounded, color: WgfColors.electricViolet),
              title: const Text('Diventa volontario'),
              subtitle: const Text('Moderazione, grafica, eventi, sviluppo'),
              onTap: () {
                Navigator.pop(ctx);
                _sendIdea(context, 'volunteer');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: WgfColors.electricViolet),
              title: const Text('Invita altri fan'),
              subtitle: const Text('Copia un messaggio da condividere'),
              onTap: () async {
                await Clipboard.setData(const ClipboardData(
                  text: 'Unisciti a WGF CONNECT, la community indipendente dei fan WGF: amicizie, eventi e tanto altro!',
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messaggio copiato!')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_rounded, color: WgfColors.electricViolet),
              title: const Text('Partecipa alla community'),
              onTap: () {
                Navigator.pop(ctx);
                context.go('/home');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendIdea(BuildContext context, String kind) async {
    final ctrl = TextEditingController();
    final labels = {
      'idea': ('Proponi un\'idea', 'Cosa vorresti vedere in WGF CONNECT?'),
      'volunteer': ('Diventa volontario', 'Come vorresti aiutare? (competenze, tempo disponibile)'),
      'message': ('Messaggio per Sentinel', 'Scrivi un messaggio al fondatore'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels[kind]!.$1),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          maxLength: 2000,
          decoration: InputDecoration(hintText: labels[kind]!.$2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invia')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(creatorRepoProvider).sendIdea(kind, ctrl.text.trim());
      ref.invalidate(communityMessagesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inviato a Sentinel. Grazie! 💜')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Pannello di pubblicazione riservato al fondatore (verificato dal database).
  Future<void> _showPublisher(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var kind = 'update';
    var publish = true;
    const kinds = {
      'update': 'Aggiornamento',
      'devlog': 'Diario di sviluppo',
      'bio': 'Biografia',
      'manifesto': 'Manifesto',
      'future_project': 'Progetto futuro',
    };
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pubblica come Sentinel', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 6, children: [
                  for (final k in kinds.entries)
                    ChoiceChip(label: Text(k.value), selected: kind == k.key, onSelected: (_) => set(() => kind = k.key)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: title, maxLength: 150, decoration: const InputDecoration(labelText: 'Titolo')),
                TextField(controller: body, maxLines: 8, maxLength: 20000, decoration: const InputDecoration(labelText: 'Testo')),
                SwitchListTile(
                  value: publish,
                  onChanged: (v) => set(() => publish = v),
                  title: const Text('Pubblica subito'),
                  subtitle: const Text('I follower riceveranno una notifica'),
                ),
                GradientButton(label: 'Salva', onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty || body.text.trim().isEmpty) return;
    try {
      await ref.read(creatorRepoProvider).publishUpdate(kind, title.text.trim(), body.text.trim(), publish);
      ref.invalidate(creatorUpdatesProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _ManifestoTab extends StatelessWidget {
  const _ManifestoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        for (var i = 0; i < kSentinelManifesto.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                kSentinelManifesto[i],
                style: TextStyle(
                  fontSize: kSentinelManifesto[i].length < 40 ? 22 : 17,
                  height: 1.5,
                  fontWeight: kSentinelManifesto[i].length < 40 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (r) => WgfColors.brandGradient.createShader(r),
          child: Text('— SENTINEL',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, letterSpacing: 3)),
        ),
        const SizedBox(height: 32),
        const Text(
          'WGF CONNECT è un progetto indipendente realizzato da un fan. '
          'Non è affiliato, approvato o sponsorizzato dai WGF.',
          textAlign: TextAlign.center,
          style: TextStyle(color: WgfColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _UpdatesList extends StatelessWidget {
  const _UpdatesList({required this.updates, required this.kinds, required this.empty});
  final AsyncValue<List<CreatorUpdate>> updates;
  final List<String> kinds;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return asyncView(updates, (all) {
      final list = all.where((u) => kinds.contains(u.kind)).toList();
      if (list.isEmpty) return EmptyState(icon: Icons.auto_awesome_rounded, title: empty);
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final u = list[i];
          return FadeSlideIn(
            index: i,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (!u.published) const TagChip('Bozza', icon: Icons.edit_note_rounded),
                    if (!u.published) const SizedBox(width: 6),
                    Text(timeAgo(u.createdAt), style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Text(u.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(u.body, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _CommunityTab extends ConsumerWidget {
  const _CommunityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final msgs = ref.watch(communityMessagesProvider);
    final isCreator = me?.isCreator ?? false;
    return asyncView(msgs, (list) {
      final visible = isCreator ? list : list.where((m) => m['is_public'] == true || m['author_id'] == me?.id).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          GlassCard(
            onTap: () => context.findAncestorStateOfType<_SentinelScreenState>()?._sendIdea(context, 'message'),
            child: const Row(children: [
              Icon(Icons.mail_rounded, color: WgfColors.electricViolet),
              SizedBox(width: 10),
              Expanded(child: Text('Scrivi un messaggio o proponi un\'idea a Sentinel')),
              Icon(Icons.chevron_right_rounded),
            ]),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const Text('I messaggi scelti dal fondatore appariranno qui.', style: TextStyle(color: WgfColors.muted)),
          for (final m in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      TagChip(switch (m['kind']) { 'idea' => 'Idea', 'volunteer' => 'Volontario', _ => 'Messaggio' }),
                      const Spacer(),
                      if (isCreator)
                        Switch(
                          value: m['is_public'] == true,
                          onChanged: (v) async {
                            await ref.read(creatorRepoProvider).setIdeaPublic(m['id'] as String, v);
                            ref.invalidate(communityMessagesProvider);
                          },
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(m['body'] as String),
                    if (isCreator)
                      Text(m['is_public'] == true ? 'Visibile a tutti' : 'Privato (solo tu)',
                          style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

// =====================================================================
// Emblema originale di SENTINEL e orbite animate
// =====================================================================
class SentinelEmblem extends StatelessWidget {
  const SentinelEmblem({super.key, this.size = 140});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _EmblemPainter());
}

class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    canvas.drawCircle(
      c,
      s.width / 2,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF2A0B52), WgfColors.black]).createShader(Offset.zero & s),
    );
    // occhio stilizzato "sentinella"
    final eye = Path()
      ..moveTo(c.dx - s.width * 0.34, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - s.height * 0.30, c.dx + s.width * 0.34, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + s.height * 0.30, c.dx - s.width * 0.34, c.dy)
      ..close();
    canvas.drawPath(
      eye,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.03
        ..shader = WgfColors.brandGradient.createShader(Offset.zero & s),
    );
    canvas.drawCircle(c, s.width * 0.11, Paint()..shader = WgfColors.brandGradient.createShader(Offset.zero & s));
    canvas.drawCircle(c, s.width * 0.045, Paint()..color = Colors.white);
    // lettera S
    final tp = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(fontSize: s.width * 0.16, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + s.height * 0.22));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        transform: GradientRotation(t * 2 * math.pi),
        colors: const [Colors.transparent, WgfColors.electricViolet, Colors.white, Colors.transparent],
        stops: const [0, 0.55, 0.62, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, ring);
    for (var i = 0; i < 3; i++) {
      final a = t * 2 * math.pi * (i.isEven ? 1 : -1) + i * 2.1;
      final rr = r - 10 - i * 6;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * rr, 3.0 - i * 0.6,
          Paint()..color = i == 1 ? Colors.white : const Color(0xFFC084FC));
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter o) => o.t != t;
}
