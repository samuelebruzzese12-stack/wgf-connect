import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';

/// Animazione del match: i due avatar si avvicinano, esplosione di particelle,
/// titolo con effetto "pulse".
Future<void> showMatchOverlay(
  BuildContext context, {
  required ProfileCard other,
  required String myName,
  String? myAvatar,
  required String conversationId,
  required bool dating,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'match',
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) => _MatchView(
      other: other,
      myName: myName,
      myAvatar: myAvatar,
      conversationId: conversationId,
      dating: dating,
    ),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(a), child: child),
    ),
  );
}

class _MatchView extends StatefulWidget {
  const _MatchView({
    required this.other,
    required this.myName,
    required this.myAvatar,
    required this.conversationId,
    required this.dating,
  });
  final ProfileCard other;
  final String myName;
  final String? myAvatar;
  final String conversationId;
  final bool dating;

  @override
  State<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<_MatchView> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    colors: const [Colors.white, Color(0xFFC084FC), WgfColors.electricViolet],
                    stops: [0, 0.5 + 0.3 * _pulse.value, 1],
                  ).createShader(r),
                  child: Text(
                    widget.dating ? 'È un match!' : 'Nuova amicizia!',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 40 + 3 * _pulse.value,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu e ${widget.other.name} vi siete piaciuti a vicenda',
                style: const TextStyle(color: WgfColors.muted),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 200,
                width: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const ParticleBurst(size: 320, count: 48),
                    AnimatedBuilder(
                      animation: slide,
                      builder: (_, __) {
                        final dx = 120 * (1 - slide.value);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(-56 - dx, 0),
                              child: Transform.rotate(
                                angle: -0.12 * slide.value,
                                child: UserAvatar(name: widget.myName, path: widget.myAvatar, size: 120, ring: true),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(56 + dx, 0),
                              child: Transform.rotate(
                                angle: 0.12 * slide.value,
                                child: UserAvatar(
                                  name: widget.other.name,
                                  path: widget.other.avatarPath,
                                  size: 120,
                                  ring: true,
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: slide.value.clamp(0.0, 1.2).toDouble(),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: WgfColors.brandGradient,
                                ),
                                child: Transform.rotate(
                                  angle: math.sin(_pulse.value * math.pi) * 0.1,
                                  child: Icon(
                                    widget.dating ? Icons.favorite_rounded : Icons.handshake_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GradientButton(
                  label: 'Scrivi un messaggio',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/chat/${widget.conversationId}');
                  },
                ),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continua a scoprire')),
            ],
          ),
        ),
      ),
    );
  }
}
