import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';

/// Splash animata: il logo si disegna, i nodi si collegano, il nome appare.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draw = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Curves.easeInOutCubic));
    final glow = CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.8, curve: Curves.easeOut));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic));
    final scale = Tween(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.elasticOut)));

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: scale.value,
                  child: Hero(tag: 'wgf-logo', child: WgfLogo(size: 128, progress: draw.value, glow: glow.value)),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: text.value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - text.value)),
                    child: Column(
                      children: [
                        Text(
                          'WGF CONNECT',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(letterSpacing: 4 + 4 * text.value),
                        ),
                        const SizedBox(height: 8),
                        const Text('La community dei fan WGF', style: TextStyle(color: WgfColors.muted)),
                      ],
                    ),
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
