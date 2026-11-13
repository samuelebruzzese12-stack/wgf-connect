import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/wgf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// TESSERA FAN WGF – carta "olografica": riflesso animato e inclinazione
/// seguendo il dito.
class FanCard extends ConsumerStatefulWidget {
  const FanCard({super.key, required this.profile});
  final MyProfile profile;

  @override
  ConsumerState<FanCard> createState() => _FanCardState();
}

class _FanCardState extends ConsumerState<FanCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  Offset _tilt = Offset.zero;

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final number = ref.watch(memberNumberProvider).valueOrNull;
    final badge = quizBadge(p.wgfQuizScore);

    return GestureDetector(
      onPanUpdate: (d) => setState(() {
        _tilt = Offset(
          (_tilt.dx + d.delta.dx / 300).clamp(-0.25, 0.25).toDouble(),
          (_tilt.dy + d.delta.dy / 300).clamp(-0.25, 0.25).toDouble(),
        );
      }),
      onPanEnd: (_) => setState(() => _tilt = Offset.zero),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        Clipboard.setData(ClipboardData(
          text: 'Sono il fan WGF nº ${number ?? '?'} su WGF CONNECT: @${p.username} 🦁',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Testo della tessera copiato: condividilo!')),
        );
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _tilt),
        duration: const Duration(milliseconds: 220),
        builder: (context, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-t.dy)
            ..rotateY(t.dx),
          child: child,
        ),
        child: AspectRatio(
          aspectRatio: 1.586, // proporzioni di una carta di credito
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B0A33), WgfColors.darkViolet, Color(0xFF2B1300)],
                    ),
                  ),
                ),
                // trama esagonale leggera
                const CustomPaint(painter: _HexPattern()),
                // riflesso olografico che scorre
                AnimatedBuilder(
                  animation: _shine,
                  builder: (_, __) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.5 + 3 * _shine.value, -1),
                        end: Alignment(-0.5 + 3 * _shine.value, 1),
                        colors: [
                          Colors.transparent,
                          WgfColors.lionGold.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.22),
                          WgfColors.electricViolet.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: WgfColors.lionGold.withValues(alpha: 0.7), width: 1.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ShaderMask(
                          shaderCallback: (r) => WgfColors.lionGradient.createShader(r),
                          child: const Text('WGF',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)),
                        ),
                        const SizedBox(width: 8),
                        const Text('TESSERA FAN', style: TextStyle(letterSpacing: 3, fontSize: 12, color: WgfColors.muted)),
                        const Spacer(),
                        Text(number == null ? 'Nº ····' : 'Nº ${number.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: WgfColors.lionGold, fontFamily: 'monospace')),
                      ]),
                      const Spacer(),
                      Row(children: [
                        UserAvatar(name: p.name, path: p.avatarPath, size: 54, ring: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            Text('@${p.username}', style: const TextStyle(color: WgfColors.muted)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 14, runSpacing: 4, children: [
                        _Field('ISCRITTO', DateFormat('MM/yy').format(p.createdAt)),
                        if (p.wgfFanSince != null) _Field('FAN DAL', '${p.wgfFanSince}'),
                        if (p.favoriteWgfCharacters.isNotEmpty) _Field('PREFERITO', p.favoriteWgfCharacters.first),
                        if (badge.isNotEmpty) _Field('GRADO', badge),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1.5, color: WgfColors.muted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]);
}

class _HexPattern extends CustomPainter {
  const _HexPattern();

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.05);
    const r = 18.0;
    final w = math.sqrt(3) * r;
    for (var row = 0; row * r * 1.5 < s.height + r; row++) {
      for (var col = 0; col * w < s.width + w; col++) {
        final cx = col * w + (row.isOdd ? w / 2 : 0);
        final cy = row * r * 1.5;
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 6 + i * math.pi / 3;
          final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
