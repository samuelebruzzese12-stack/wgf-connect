import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/wgf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

/// Quiz "Quanto conosci i WGF?": risposte animate, punteggio, badge sul profilo.
class WgfQuizScreen extends ConsumerStatefulWidget {
  const WgfQuizScreen({super.key});
  @override
  ConsumerState<WgfQuizScreen> createState() => _WgfQuizScreenState();
}

class _WgfQuizScreenState extends ConsumerState<WgfQuizScreen> {
  late final List<QuizQuestion> _questions = [...kWgfQuiz]..shuffle(math.Random());
  int _index = 0;
  int _correct = 0;
  int? _picked;
  bool _finished = false;
  int? _best;

  void _answer(int i) {
    if (_picked != null) return;
    final ok = i == _questions[_index].correct;
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _picked = i;
      if (ok) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    setState(() => _finished = true);
    try {
      final best = await submitWgfQuiz(ref.read(supabaseProvider), _correct, _questions.length);
      ref.invalidate(myProfileProvider);
      if (mounted) setState(() => _best = best);
    } catch (_) {/* il risultato resta visibile anche se il salvataggio non riesce */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quanto conosci i WGF?')),
      body: AuroraBackground(
        intensity: 0.7,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a), child: c),
          ),
          child: _finished ? _result() : _question(),
        ),
      ),
    );
  }

  Widget _question() {
    final q = _questions[_index];
    return ListView(
      key: ValueKey(_index),
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Text('Domanda ${_index + 1} di ${_questions.length}', style: const TextStyle(color: WgfColors.muted)),
          const Spacer(),
          const Icon(Icons.check_circle_rounded, size: 18, color: WgfColors.lionGold),
          const SizedBox(width: 4),
          Text('$_correct'),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_index + 1) / _questions.length),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: WgfColors.lionGold,
              backgroundColor: WgfColors.anthracite,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(q.question, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        for (var i = 0; i < q.answers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(index: i, child: _AnswerTile(
              text: q.answers[i],
              state: _picked == null
                  ? _AnswerState.idle
                  : i == q.correct
                      ? _AnswerState.correct
                      : i == _picked
                          ? _AnswerState.wrong
                          : _AnswerState.dimmed,
              onTap: () => _answer(i),
            )),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _picked == null
              ? const SizedBox(width: double.infinity)
              : Column(children: [
                  const SizedBox(height: 8),
                  GlassCard(child: Text(q.explanation)),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: _index < _questions.length - 1 ? 'Prossima domanda' : 'Vedi il risultato',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ]),
        ),
      ],
    );
  }

  Widget _result() {
    final score = (100 * _correct / _questions.length).round();
    final badge = quizBadge(score);
    return Center(
      key: const ValueKey('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              const ParticleBurst(size: 260, count: 40),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 140,
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: WgfColors.lionGradient,
                    boxShadow: [BoxShadow(color: WgfColors.lionGold.withValues(alpha: 0.5), blurRadius: 30)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events_rounded, size: 44, color: Colors.black),
                    Text('$score%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.black)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(badge.isEmpty ? 'Riprova!' : badge,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: WgfColors.lionGold, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('$_correct risposte giuste su ${_questions.length}', style: const TextStyle(color: WgfColors.muted)),
            if (_best != null) ...[
              const SizedBox(height: 6),
              Text('Il tuo record: $_best% – il badge compare sul tuo profilo'),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: 'Rigioca',
              icon: Icons.replay_rounded,
              onPressed: () => setState(() {
                _questions.shuffle(math.Random());
                _index = 0;
                _correct = 0;
                _picked = null;
                _finished = false;
                _best = null;
              }),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Torna alla WGF ZONE')),
          ],
        ),
      ),
    );
  }
}

enum _AnswerState { idle, correct, wrong, dimmed }

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.text, required this.state, required this.onTap});
  final String text;
  final _AnswerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, IconData? icon) = switch (state) {
      _AnswerState.correct => (const Color(0xFF0F3D2A), const Color(0xFF34D399), Icons.check_circle_rounded),
      _AnswerState.wrong => (const Color(0xFF3D0F1A), WgfColors.danger, Icons.cancel_rounded),
      _AnswerState.dimmed => (WgfColors.anthracite.withValues(alpha: 0.5), Colors.transparent, null),
      _AnswerState.idle => (WgfColors.anthracite, WgfColors.electricViolet.withValues(alpha: 0.4), null),
    };
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (icon != null) Icon(icon, color: border),
        ]),
      ),
    );
  }
}
