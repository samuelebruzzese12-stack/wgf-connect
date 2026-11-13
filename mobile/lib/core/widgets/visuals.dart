import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

// =====================================================================
// LOGO ORIGINALE WGF CONNECT
// Esagono con tre nodi collegati: "fan che si connettono".
// Disegnato in codice (nessuna immagine di terzi).
// =====================================================================
class WgfLogo extends StatelessWidget {
  const WgfLogo({super.key, this.size = 72, this.progress = 1, this.glow = 1});
  final double size;

  /// 0→1: disegno progressivo (usato dalla splash animata).
  final double progress;
  final double glow;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(progress.clamp(0.0, 1.0).toDouble(), glow.clamp(0.0, 1.0).toDouble()),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.p, this.glow);
  final double p;
  final double glow;

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width * 0.44;
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? hex.moveTo(pt.dx, pt.dy) : hex.lineTo(pt.dx, pt.dy);
    }
    hex.close();

    final rect = Offset.zero & s;
    final grad = WgfColors.brandGradient.createShader(rect);

    // alone
    if (glow > 0) {
      canvas.drawPath(
        hex,
        Paint()
          ..color = WgfColors.electricViolet.withValues(alpha: 0.55 * glow * p)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.12),
      );
    }

    // riempimento e bordo esagono
    canvas.drawPath(hex, Paint()..shader = grad..color = Colors.white.withValues(alpha: p));
    final metrics = hex.computeMetrics().first;
    canvas.drawPath(
      metrics.extractPath(0, metrics.length * p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.035
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // tre nodi connessi
    final nodes = [
      c + Offset(0, -r * 0.42),
      c + Offset(-r * 0.40, r * 0.28),
      c + Offset(r * 0.40, r * 0.28),
    ];
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * p)
      ..strokeWidth = s.width * 0.04
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = nodes[i];
      final b = nodes[(i + 1) % 3];
      canvas.drawLine(a, Offset.lerp(a, b, p)!, line);
    }
    for (final n in nodes) {
      canvas.drawCircle(n, s.width * 0.085 * p, Paint()..color = Colors.white);
      canvas.drawCircle(n, s.width * 0.045 * p, Paint()..color = WgfColors.electricViolet);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter o) => o.p != p || o.glow != glow;
}

// =====================================================================
// SFONDO ANIMATO "AURORA" – leggero: un solo CustomPainter, 3 sfere
// =====================================================================
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.intensity = 1});
  final Widget child;
  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _AuroraPainter(_c.value, widget.intensity)),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.intensity);
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = WgfColors.black);
    void orb(double phase, double rx, double ry, double radius, Color color) {
      final a = 2 * math.pi * (t + phase);
      final center = Offset(
        s.width * (0.5 + rx * math.cos(a)),
        s.height * (0.45 + ry * math.sin(a * 1.3)),
      );
      final r = s.shortestSide * radius;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.38 * intensity), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    orb(0.0, 0.35, 0.30, 0.95, WgfColors.electricViolet);
    orb(0.33, 0.40, 0.35, 0.85, WgfColors.darkViolet);
    orb(0.66, 0.30, 0.25, 0.70, const Color(0xFF5B21B6));
  }

  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t;
}

// =====================================================================
// COMPONENTI RIUTILIZZABILI
// =====================================================================

/// Card "vetro" con bordo sfumato viola.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            WgfColors.electricViolet.withValues(alpha: 0.55),
            WgfColors.darkViolet.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: WgfColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(19),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap!, child: card);
  }
}

/// Leggero effetto "pressione" (scala) al tocco.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Pulsante con gradiente del brand.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Pressable(
        onTap: enabled ? onPressed! : () {},
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: WgfColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: WgfColors.electricViolet.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 8)],
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Entrata animata (dissolvenza + scorrimento) con ritardo per creare effetti a cascata.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 24});
  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 10).toInt()), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - curve.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Stato vuoto o di errore, con icona animata.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WgfColors.darkViolet.withValues(alpha: 0.35),
                ),
                child: Icon(icon, size: 40, color: WgfColors.electricViolet),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: WgfColors.muted)),
              ],
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gestione uniforme di AsyncValue: caricamento, errore con riprova, dati.
Widget asyncView<T>(AsyncValue<T> value, Widget Function(T data) data, {VoidCallback? onRetry}) {
  return value.when(
    skipLoadingOnRefresh: true,
    skipLoadingOnReload: true,
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Impossibile caricare',
      message: 'Controlla la connessione e riprova.',
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
    ),
  );
}

/// Chip compatta per interessi e hashtag.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WgfColors.darkViolet.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WgfColors.electricViolet.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: WgfColors.white), const SizedBox(width: 4)],
          Text(label, style: const TextStyle(fontSize: 12, color: WgfColors.white)),
        ],
      ),
    );
  }
}

/// Esplosione di particelle (usata per match e "mi piace").
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({super.key, this.size = 300, this.count = 36, this.duration = const Duration(milliseconds: 1400)});
  final double size;
  final int count;
  final Duration duration;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<(double, double, double, Color)> _parts = List.generate(widget.count, (i) {
    final rnd = math.Random(i * 7919);
    return (
      rnd.nextDouble() * 2 * math.pi,
      0.45 + rnd.nextDouble() * 0.55,
      2.0 + rnd.nextDouble() * 4,
      [WgfColors.electricViolet, Colors.white, const Color(0xFFC084FC), WgfColors.darkViolet][i % 4],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _BurstPainter(Curves.easeOutCubic.transform(_c.value), _parts),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.parts);
  final double t;
  final List<(double, double, double, Color)> parts;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    for (final p in parts) {
      final dist = s.width / 2 * p.$2 * t;
      final pos = c + Offset(math.cos(p.$1), math.sin(p.$1)) * dist;
      canvas.drawCircle(pos, p.$3 * (1 - t * 0.6), Paint()..color = p.$4.withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}
