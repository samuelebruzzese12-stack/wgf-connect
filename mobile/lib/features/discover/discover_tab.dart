import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../matches/match_overlay.dart';
import 'profile_card_view.dart';

/// DISCOVER: scoperta di profili con swipe (modalità Amicizia o Dating).
class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});
  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  String _mode = 'friendship';
  final List<ProfileCard> _deck = [];
  bool _loading = false;
  bool _exhausted = false;
  String? _error;
  final _deckKey = GlobalKey<_SwipeDeckState>();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _deck.clear();
        _exhausted = false;
      }
    });
    try {
      final list = await ref.read(discoverRepoProvider).discover(DiscoverFilter(mode: _mode));
      final ids = _deck.map((e) => e.id).toSet();
      setState(() {
        _deck.addAll(list.where((p) => !ids.contains(p.id)));
        _exhausted = list.isEmpty;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSwiped(ProfileCard p, String action) async {
    setState(() => _deck.removeWhere((x) => x.id == p.id));
    if (_deck.length < 3 && !_exhausted) _load();
    HapticFeedback.lightImpact();
    try {
      final res = await ref.read(discoverRepoProvider).swipe(p.id, _mode, action);
      if (res['matched'] == true && mounted) {
        HapticFeedback.heavyImpact();
        final me = await ref.read(myProfileProvider.future);
        if (!mounted) return;
        ref.invalidate(conversationsProvider);
        await showMatchOverlay(
          context,
          other: p,
          myName: me?.name ?? 'Tu',
          myAvatar: me?.avatarPath,
          conversationId: res['conversation_id'] as String,
          dating: _mode == 'dating',
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _setMode(String m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      _exhausted = false;
      _error = null;
    });
    if (m == 'friendship') {
      _load(reset: true);
    } else {
      final s = ref.read(datingStatusProvider).valueOrNull;
      if (s != null && s['dating_enabled'] == true && s['verification'] == 'verified') _load(reset: true);
      setState(() => _deck.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dating = ref.watch(datingStatusProvider);
    Widget body;

    if (_mode == 'dating') {
      body = asyncView(dating, (s) {
        if (s['dating_enabled'] != true) {
          return const EmptyState(
            icon: Icons.favorite_rounded,
            title: 'Il dating arriva presto',
            message: 'Lo attiveremo appena la procedura di verifica dell\'età sarà pronta. '
                'Nel frattempo prepara il profilo e verifica di essere maggiorenne.',
          );
        }
        if (s['verification'] != 'verified') {
          return _DatingGate(status: s['verification'] as String?);
        }
        if (_deck.isEmpty && !_loading && _error == null && !_exhausted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
        }
        return _deckView();
      });
    } else {
      body = _deckView();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'friendship', icon: Icon(Icons.handshake_rounded), label: Text('Amicizia')),
              ButtonSegment(value: 'dating', icon: Icon(Icons.favorite_rounded), label: Text('Dating 18+')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
        ),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey(_mode), child: body))),
      ],
    );
  }

  Widget _deckView() {
    if (_error != null && _deck.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Qualcosa non va',
        message: _error,
        action: OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Riprova')),
      );
    }
    if (_deck.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_deck.isEmpty) {
      return EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Hai visto tutti per ora',
        message: 'Torna più tardi o cerca per città e interessi con FanFinder.',
        action: Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Aggiorna')),
            FilledButton(onPressed: () => context.push('/fanfinder'), child: const Text('Apri FanFinder')),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SwipeDeck(
              key: _deckKey,
              cards: _deck,
              dating: _mode == 'dating',
              onSwiped: _onSwiped,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundAction(icon: Icons.close_rounded, color: WgfColors.muted, size: 60,
                  tooltip: 'Passa', onTap: () => _deckKey.currentState?.fling('pass')),
              _RoundAction(icon: Icons.star_rounded, color: const Color(0xFF60A5FA), size: 50,
                  tooltip: 'Super Like', onTap: () => _deckKey.currentState?.fling('super_like')),
              _RoundAction(
                icon: _mode == 'dating' ? Icons.favorite_rounded : Icons.handshake_rounded,
                color: WgfColors.electricViolet,
                size: 68,
                gradient: true,
                tooltip: 'Mi piace',
                onTap: () => _deckKey.currentState?.fling('like'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DatingGate extends ConsumerWidget {
  const _DatingGate({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = status == 'pending';
    return EmptyState(
      icon: pending ? Icons.hourglass_top_rounded : Icons.verified_user_rounded,
      title: pending ? 'Verifica in corso' : 'Il dating è riservato agli adulti verificati',
      message: pending
          ? 'Ti contatteremo per completare la verifica. Nel frattempo puoi usare la modalità Amicizia.'
          : 'Per la sicurezza di tutti chiediamo una breve verifica della maggiore età. '
              'Non conserviamo documenti né foto: salviamo solo l\'esito.',
      action: pending ? null : FilledButton(onPressed: () => context.push('/verify'), child: const Text('Verifica la tua età')),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    required this.tooltip,
    this.gradient = false,
  });
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String tooltip;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient ? WgfColors.brandGradient : null,
            color: gradient ? null : WgfColors.anthracite,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18)],
          ),
          child: Icon(icon, color: gradient ? Colors.white : color, size: size * 0.48),
        ),
      ),
    );
  }
}

// =====================================================================
// MAZZO CON SWIPE FISICO
// =====================================================================
class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({super.key, required this.cards, required this.dating, required this.onSwiped});
  final List<ProfileCard> cards;
  final bool dating;
  final Future<void> Function(ProfileCard, String action) onSwiped;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck> with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  Animation<Offset>? _flight;
  String? _pendingAction;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() => _drag = _flight!.value));
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed && _pendingAction != null && widget.cards.isNotEmpty) {
        final card = widget.cards.first;
        final action = _pendingAction!;
        _pendingAction = null;
        _drag = Offset.zero;
        widget.onSwiped(card, action);
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {String? action}) {
    _pendingAction = action;
    _flight = Tween(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _anim, curve: action == null ? Curves.elasticOut : Curves.easeIn),
    );
    _anim.duration = Duration(milliseconds: action == null ? 600 : 300);
    _anim.forward(from: 0);
  }

  /// Avvia uno swipe dai pulsanti.
  void fling(String action) {
    if (widget.cards.isEmpty || _anim.isAnimating) return;
    final w = MediaQuery.of(context).size.width;
    final target = switch (action) {
      'pass' => Offset(-w * 1.5, 40),
      'super_like' => Offset(0, -MediaQuery.of(context).size.height),
      _ => Offset(w * 1.5, 40),
    };
    _animateTo(target, action: action);
  }

  void _onEnd(DragEndDetails d) {
    final w = MediaQuery.of(context).size.width;
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx > w * 0.28 || v.dx > 900) {
      _animateTo(Offset(w * 1.5, _drag.dy + v.dy * 0.1), action: 'like');
    } else if (_drag.dx < -w * 0.28 || v.dx < -900) {
      _animateTo(Offset(-w * 1.5, _drag.dy + v.dy * 0.1), action: 'pass');
    } else if (_drag.dy < -160 || v.dy < -1100) {
      _animateTo(Offset(_drag.dx, -MediaQuery.of(context).size.height), action: 'super_like');
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards.take(3).toList();
    final w = MediaQuery.of(context).size.width;
    final progress = (_drag.dx.abs() / (w * 0.28)).clamp(0.0, 1.0).toDouble();

    return Stack(
      children: [
        for (var i = cards.length - 1; i >= 0; i--)
          if (i == 0)
            Positioned.fill(
              key: ValueKey(cards[i].id),
              child: GestureDetector(
                onPanUpdate: (d) {
                  if (_anim.isAnimating) return;
                  setState(() => _drag += d.delta);
                },
                onPanEnd: _onEnd,
                onTap: () => showProfileSheet(context, cards[i]),
                child: Transform.translate(
                  offset: _drag,
                  child: Transform.rotate(
                    angle: (_drag.dx / w) * 0.35,
                    child: Stack(
                      children: [
                        ProfileCardView(profile: cards[i]),
                        _Stamp(
                          text: widget.dating ? 'MI PIACE' : 'AMICI!',
                          color: WgfColors.electricViolet,
                          opacity: _drag.dx > 0 ? progress : 0,
                          left: true,
                        ),
                        _Stamp(
                          text: 'PASSA',
                          color: WgfColors.muted,
                          opacity: _drag.dx < 0 ? progress : 0,
                          left: false,
                        ),
                        if (_drag.dy < -40)
                          Center(
                            child: Opacity(
                              opacity: ((-_drag.dy - 40) / 120).clamp(0.0, 1.0).toDouble(),
                              child: const Icon(Icons.star_rounded, size: 120, color: Color(0xFF60A5FA)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              key: ValueKey(cards[i].id),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: 1 - 0.05 * i + 0.05 * progress * (i == 1 ? 1 : 0),
                child: Transform.translate(
                  offset: Offset(0, 14.0 * i - 14 * progress * (i == 1 ? 1 : 0)),
                  child: Opacity(opacity: i == 1 ? 0.85 + 0.15 * progress : 0.5, child: ProfileCardView(profile: cards[i])),
                ),
              ),
            ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color, required this.opacity, required this.left});
  final String text;
  final Color color;
  final double opacity;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 36,
      left: left ? 24 : null,
      right: left ? null : 24,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: (left ? -1 : 1) * math.pi / 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
        ),
      ),
    );
  }
}
