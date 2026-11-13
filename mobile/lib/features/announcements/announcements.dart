import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

// =====================================================================
// Stile per livello: info (viola), importante (oro), urgente (rosso)
// =====================================================================
({Color color, Gradient gradient, IconData icon, String label}) announcementStyle(String level) => switch (level) {
      'urgent' => (
          color: WgfColors.danger,
          gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFF9B1030)]),
          icon: Icons.warning_amber_rounded,
          label: 'URGENTE',
        ),
      'info' => (
          color: WgfColors.electricViolet,
          gradient: WgfColors.brandGradient,
          icon: Icons.info_rounded,
          label: 'INFORMAZIONE',
        ),
      _ => (
          color: WgfColors.lionGold,
          gradient: WgfColors.lionGradient,
          icon: Icons.campaign_rounded,
          label: 'COMUNICAZIONE IMPORTANTE',
        ),
    };

/// Avvolge la home: quando arriva un avviso nuovo lo mostra subito a tutto schermo.
class AnnouncementGate extends ConsumerStatefulWidget {
  const AnnouncementGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<AnnouncementGate> {
  bool _showing = false;
  final _shown = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_showing || !mounted) return;
    List<Map<String, dynamic>> list;
    try {
      list = await ref.read(announcementsRepoProvider).pending();
    } catch (_) {
      return;
    }
    // dal più vecchio al più recente
    for (final a in list.reversed) {
      final id = a['id'] as String;
      if (_shown.contains(id) || !mounted) continue;
      _shown.add(id);
      _showing = true;
      await showAnnouncementDialog(context, a);
      _showing = false;
      try {
        await ref.read(announcementsRepoProvider).dismiss(id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(announcementsStreamProvider, (_, __) => _check());
    return widget.child;
  }
}

/// Arrivo cinematografico dell'avviso: raggi rotanti, onde d'urto,
/// esplosione di particelle, scossa (urgente), carta che si ribalta in 3D
/// e titolo che si scrive lettera per lettera.
Future<void> showAnnouncementDialog(BuildContext context, Map<String, dynamic> a) {
  final level = (a['level'] ?? 'important') as String;
  level == 'urgent' ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'comunicazione',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => _AnnouncementView(a: a),
  );
}

class _AnnouncementView extends StatefulWidget {
  const _AnnouncementView({required this.a});
  final Map<String, dynamic> a;

  @override
  State<_AnnouncementView> createState() => _AnnouncementViewState();
}

class _AnnouncementViewState extends State<_AnnouncementView> with TickerProviderStateMixin {
  // 0 → 1 in 2,4 s: sequenza d'ingresso
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  // ciclo continuo: raggi, pulsazione, scintille
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  bool get _urgent => widget.a['level'] == 'urgent';

  @override
  void initState() {
    super.initState();
    if (_urgent) {
      Future.delayed(const Duration(milliseconds: 650), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 900), () => HapticFeedback.heavyImpact());
    } else {
      Future.delayed(const Duration(milliseconds: 650), () => HapticFeedback.lightImpact());
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  double _seg(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final st = announcementStyle((a['level'] ?? 'important') as String);
    final link = a['link_url'] as String?;
    final created = DateTime.tryParse((a['created_at'] ?? '') as String)?.toLocal();
    final title = (a['title'] ?? '') as String;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final dark = _seg(0, 0.15);
          final rays = _seg(0.05, 0.4);
          final iconIn = _seg(0.1, 0.45, Curves.elasticOut);
          final card = _seg(0.35, 0.75, Curves.easeOutBack);
          final typed = _seg(0.55, 0.95, Curves.linear);
          // scossa per gli avvisi urgenti
          final shake = _urgent && _intro.value > 0.25 && _intro.value < 0.5
              ? math.sin(_intro.value * 140) * 8 * (0.5 - _intro.value) * 4
              : 0.0;
          final size = MediaQuery.of(context).size;

          return Stack(
            children: [
              // 1. oscuramento + vignetta colorata
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [
                        st.color.withValues(alpha: 0.28 * dark),
                        Colors.black.withValues(alpha: 0.92 * dark),
                      ],
                    ),
                  ),
                ),
              ),
              // 2. raggi di luce rotanti
              Positioned.fill(
                child: Opacity(
                  opacity: 0.55 * rays,
                  child: CustomPaint(painter: _RaysPainter(_loop.value, st.color)),
                ),
              ),
              // 3. onde d'urto
              Positioned.fill(child: CustomPaint(painter: _ShockwavePainter(_intro.value, _loop.value, st.color))),
              // 4. lampo urgente
              if (_urgent)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: WgfColors.danger.withValues(
                        alpha: (_intro.value < 0.5 ? (math.sin(_intro.value * 60).abs() * 0.18) : 0) +
                            0.05 * (0.5 + 0.5 * math.sin(_loop.value * math.pi * 8)),
                      ),
                    ),
                  ),
                ),
              // 5. esplosione di particelle
              if (_intro.value > 0.12)
                Center(child: ParticleBurst(key: const ValueKey('burst'), size: size.shortestSide * 1.3, count: 70)),
              // 6. contenuto
              SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(shake, 0),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // megafono che entra roteando
                          Transform.rotate(
                            angle: (1 - iconIn) * -math.pi,
                            child: Transform.scale(
                              scale: iconIn * (1 + 0.06 * math.sin(_loop.value * math.pi * 12)),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: st.gradient,
                                  boxShadow: [
                                    BoxShadow(color: st.color.withValues(alpha: 0.7), blurRadius: 40, spreadRadius: 4),
                                  ],
                                ),
                                child: Icon(st.icon, size: 48, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // carta che si ribalta in 3D
                          Opacity(
                            opacity: card.clamp(0.0, 1.0).toDouble(),
                            child: Transform(
                              alignment: Alignment.topCenter,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..rotateX((1 - card) * 1.3),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  gradient: SweepGradient(
                                    transform: GradientRotation(_loop.value * 2 * math.pi),
                                    colors: [st.color, Colors.white, st.color, WgfColors.darkViolet, st.color],
                                  ),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [BoxShadow(color: st.color.withValues(alpha: 0.45), blurRadius: 36)],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                                  decoration: BoxDecoration(color: WgfColors.surface, borderRadius: BorderRadius.circular(24)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (r) => LinearGradient(
                                          colors: [st.color, Colors.white, st.color],
                                          stops: [0, (_loop.value * 3 % 1), 1],
                                        ).createShader(r),
                                        child: Text(st.label,
                                            style: const TextStyle(
                                                color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 12)),
                                      ),
                                      const SizedBox(height: 8),
                                      // titolo scritto lettera per lettera
                                      Text(
                                        title.substring(0, (title.length * typed).round()) + (typed < 1 ? '▌' : ''),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 12),
                                      Opacity(
                                        opacity: _seg(0.8, 1),
                                        child: Column(children: [
                                          Text((a['body'] ?? '') as String,
                                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5)),
                                          const SizedBox(height: 12),
                                          Text(
                                            'SENTINEL · WGF CONNECT${created != null ? ' · ${timeAgo(created)}' : ''}',
                                            style: const TextStyle(color: WgfColors.muted, fontSize: 12),
                                          ),
                                          const SizedBox(height: 18),
                                          if (link != null) ...[
                                            OutlinedButton.icon(
                                              onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                                              icon: const Icon(Icons.open_in_new_rounded),
                                              label: const Text('Apri il link'),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          GradientButton(
                                            label: 'Ho capito',
                                            icon: Icons.check_rounded,
                                            onPressed: _intro.value < 0.8 ? null : () => Navigator.of(context).pop(),
                                          ),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * 0.38);
    final r = s.longestSide;
    const rays = 14;
    final paint = Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r * 0.8));
    for (var i = 0; i < rays; i++) {
      final a = t * 2 * math.pi + i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.07), c.dy + r * math.sin(a - 0.07))
        ..lineTo(c.dx + r * math.cos(a + 0.07), c.dy + r * math.sin(a + 0.07))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter o) => o.t != t;
}

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter(this.intro, this.loop, this.color);
  final double intro;
  final double loop;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * 0.38);
    final maxR = s.longestSide * 0.9;
    // 3 onde d'urto iniziali
    for (var i = 0; i < 3; i++) {
      final p = ((intro - 0.1 - i * 0.08) / 0.5).clamp(0.0, 1.0).toDouble();
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        c,
        maxR * Curves.easeOutCubic.transform(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - p) + 1
          ..color = color.withValues(alpha: 0.8 * (1 - p)),
      );
    }
    // onde lente continue
    for (var i = 0; i < 2; i++) {
      final p = (loop * 3 + i * 0.5) % 1;
      canvas.drawCircle(
        c,
        60 + 220 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.35 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter o) => o.intro != intro || o.loop != loop;
}

/// Animazione di "lancio" per l'admin dopo l'invio: il megafono decolla
/// lasciando una scia, onde che si propagano e contatore dei fan raggiunti.
Future<void> showLaunchCelebration(BuildContext context, {required String level, int? recipients}) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'inviata',
    barrierColor: Colors.black.withValues(alpha: 0.9),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) => _LaunchView(level: level, recipients: recipients),
  );
}

class _LaunchView extends StatefulWidget {
  const _LaunchView({required this.level, this.recipients});
  final String level;
  final int? recipients;

  @override
  State<_LaunchView> createState() => _LaunchViewState();
}

class _LaunchViewState extends State<_LaunchView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward().whenComplete(() {
      if (mounted) Navigator.of(context).maybePop();
    });

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () => HapticFeedback.mediumImpact());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = announcementStyle(widget.level);
    final size = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          final charge = Curves.easeInOut.transform((v / 0.25).clamp(0.0, 1.0).toDouble());
          final fly = Curves.easeInCubic.transform(((v - 0.25) / 0.3).clamp(0.0, 1.0).toDouble());
          final waves = ((v - 0.45) / 0.5).clamp(0.0, 1.0).toDouble();
          final text = Curves.easeOutBack.transform(((v - 0.5) / 0.25).clamp(0.0, 1.0).toDouble());
          final count = ((widget.recipients ?? 0) * Curves.easeOut.transform(((v - 0.5) / 0.4).clamp(0.0, 1.0).toDouble())).round();
          final shakeX = v < 0.25 ? math.sin(v * 200) * 3 * charge : 0.0;
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _ShockwavePainter(waves * 0.6 + 0.1, v, st.color))),
            // scia del razzo
            if (fly > 0)
              Positioned(
                left: size.width / 2 - 3,
                top: size.height * 0.45 - size.height * 0.6 * fly,
                child: Container(
                  width: 6,
                  height: size.height * 0.6 * fly + 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [st.color, st.color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            if (waves > 0) Center(child: ParticleBurst(size: size.shortestSide * 1.4, count: 80)),
            // megafono che si carica e decolla
            Positioned(
              left: size.width / 2 - 44 + shakeX,
              top: size.height * 0.45 - 44 - size.height * 0.7 * fly,
              child: Transform.scale(
                scale: 1 + 0.25 * charge - 0.5 * fly,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: st.gradient,
                    boxShadow: [BoxShadow(color: st.color.withValues(alpha: 0.4 + 0.5 * charge), blurRadius: 20 + 30 * charge)],
                  ),
                  child: Icon(Icons.campaign_rounded, size: 46, color: Colors.white),
                ),
              ),
            ),
            // testo finale
            Center(
              child: Opacity(
                opacity: text.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * text,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ShaderMask(
                      shaderCallback: (r) => st.gradient.createShader(r),
                      child: const Text('INVIATA!',
                          style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.recipients == null ? 'A tutta la community WGF' : 'Raggiunti $count fan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// =====================================================================
// Schermata admin: invia una comunicazione ufficiale
// =====================================================================
class SendAnnouncementScreen extends ConsumerStatefulWidget {
  const SendAnnouncementScreen({super.key});
  @override
  ConsumerState<SendAnnouncementScreen> createState() => _SendAnnouncementScreenState();
}

class _SendAnnouncementScreenState extends ConsumerState<SendAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _level = 'important';
  int _hours = 72;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final link = _link.text.trim();
    if (title.length < 3 || body.isEmpty) {
      _snack('Scrivi un titolo (almeno 3 caratteri) e il messaggio.');
      return;
    }
    if (link.isNotEmpty && !link.startsWith('https://')) {
      _snack('Il link deve iniziare con https://');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inviare a tutti?'),
        content: const Text('Tutti gli utenti attivi riceveranno la comunicazione come finestra a comparsa e notifica.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invia')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(announcementsRepoProvider).send(
            title: title,
            body: body,
            level: _level,
            expiresHours: _hours,
            link: link.isEmpty ? null : link,
          );
      final level = _level;
      _title.clear();
      _body.clear();
      _link.clear();
      int? recipients;
      try {
        final stats = await ref.read(supabaseProvider).rpc('admin_stats');
        recipients = ((stats as Map)['users_active'] as num?)?.toInt();
      } catch (_) {}
      if (mounted) await showLaunchCelebration(context, level: level, recipients: recipients);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final sent = ref.watch(announcementsStreamProvider);
    final preview = {
      'title': _title.text.isEmpty ? 'Titolo della comunicazione' : _title.text,
      'body': _body.text.isEmpty ? 'Il testo apparirà qui.' : _body.text,
      'level': _level,
      'link_url': _link.text.trim().isEmpty ? null : _link.text.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicazioni ufficiali')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'info', label: Text('Info'), icon: Icon(Icons.info_rounded)),
              ButtonSegment(value: 'important', label: Text('Importante'), icon: Icon(Icons.campaign_rounded)),
              ButtonSegment(value: 'urgent', label: Text('Urgente'), icon: Icon(Icons.warning_amber_rounded)),
            ],
            selected: {_level},
            onSelectionChanged: (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          TextField(
            controller: _body,
            maxLength: 3000,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Messaggio'),
          ),
          TextField(
            controller: _link,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Link (facoltativo)', hintText: 'https://...'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _hours,
            decoration: const InputDecoration(labelText: 'Resta attiva per'),
            items: const [
              DropdownMenuItem(value: 6, child: Text('6 ore')),
              DropdownMenuItem(value: 24, child: Text('1 giorno')),
              DropdownMenuItem(value: 72, child: Text('3 giorni')),
              DropdownMenuItem(value: 168, child: Text('1 settimana')),
              DropdownMenuItem(value: 0, child: Text('Finché non la termino')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 72),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showAnnouncementDialog(context, preview),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Anteprima'),
          ),
          const SizedBox(height: 10),
          GradientButton(label: 'Invia a tutti', icon: Icons.send_rounded, busy: _busy, onPressed: _send),
          const SizedBox(height: 28),
          Text('Inviate', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...sent.when<List<Widget>>(
            data: (list) => list.isEmpty
                ? [const Text('Nessuna comunicazione ancora.', style: TextStyle(color: WgfColors.muted))]
                : [
                    for (final a in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(announcementStyle((a['level'] ?? '') as String).icon,
                                color: announcementStyle((a['level'] ?? '') as String).color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text((a['title'] ?? '') as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${timeAgo(DateTime.parse(a['created_at'] as String).toLocal())} · ${a['active'] == true ? 'attiva' : 'terminata'}',
                                  style: const TextStyle(color: WgfColors.muted, fontSize: 12),
                                ),
                              ]),
                            ),
                            if (a['active'] == true)
                              TextButton(
                                onPressed: () => ref.read(announcementsRepoProvider).end(a['id'] as String),
                                child: const Text('Termina'),
                              ),
                          ]),
                        ),
                      ),
                  ],
            loading: () => [const LinearProgressIndicator()],
            error: (_, __) => [const SizedBox.shrink()],
          ),
        ],
      ),
    );
  }
}
