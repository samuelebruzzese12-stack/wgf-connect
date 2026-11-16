import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

const kDownloadUrl = 'https://github.com/samuelebruzzese12-stack/wgf-connect/releases/latest';

/// Invita i fan (codice personale + gradi Ambasciatore) e classifiche.
class AmbassadorScreen extends ConsumerWidget {
  const AmbassadorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invita & Classifica'),
          bottom: const TabBar(
            indicatorColor: WgfColors.lionGold,
            labelColor: WgfColors.lionGold,
            tabs: [
              Tab(text: 'Invita', icon: Icon(Icons.campaign_rounded)),
              Tab(text: 'Quiz', icon: Icon(Icons.emoji_events_rounded)),
              Tab(text: 'Ambasciatori', icon: Icon(Icons.leaderboard_rounded)),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _InviteTab(),
          _Leaderboard(kind: 'quiz', unit: '%', empty: 'Fai il quiz WGF per entrare in classifica!'),
          _Leaderboard(kind: 'invites', unit: ' fan', empty: 'Invita un amico per entrare in classifica!'),
        ]),
      ),
    );
  }
}

class _InviteTab extends ConsumerStatefulWidget {
  const _InviteTab();
  @override
  ConsumerState<_InviteTab> createState() => _InviteTabState();
}

class _InviteTabState extends ConsumerState<_InviteTab> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final who = await redeemInvite(ref, _code.text);
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(content: Text('Fatto! Sei entrato con l\'invito di @$who 🦁')));
    } catch (e) {
      final s = '$e';
      messenger.showSnackBar(SnackBar(
        content: Text(s.contains('invite_not_valid')
            ? 'Codice non valido.'
            : s.contains('invite_already_used')
                ? 'Hai già usato un codice invito.'
                : s.contains('invite_too_late')
                    ? 'Il codice si può usare solo nei primi 30 giorni.'
                    : friendlyError(e)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(inviteInfoProvider);
    return asyncView(info, (i) {
      const steps = [(1, 'Reclutatore'), (5, 'Ambasciatore'), (20, 'Ambasciatore d\'oro'), (50, 'Leggenda WGF')];
      final next = steps.where((s) => s.$1 > i.count).firstOrNull;
      final message = '🦁 Entra nella community dei fan WGF su WGF CONNECT!\n'
          'Usa il mio codice ${i.code} quando ti iscrivi.\n'
          'Scarica l\'app: $kDownloadUrl';
      return ListView(padding: const EdgeInsets.all(16), children: [
        FadeSlideIn(
          index: 0,
          child: GlassCard(
            child: Column(children: [
              const Text('IL TUO CODICE INVITO', style: TextStyle(letterSpacing: 3, color: WgfColors.muted, fontSize: 12)),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (r) => WgfColors.lionGradient.createShader(r),
                child: SelectableText(i.code,
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: 'Condividi l\'invito',
                icon: Icons.share_rounded,
                onPressed: () => SharePlus.instance.share(ShareParams(text: message, subject: 'Vieni su WGF CONNECT')),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invito copiato!')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copia il messaggio'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 1,
          child: GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.military_tech_rounded, color: WgfColors.lionGold),
                const SizedBox(width: 8),
                Text(i.level.isEmpty ? 'Nessun grado ancora' : i.level,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const Spacer(),
                Text('${i.count} fan', style: const TextStyle(color: WgfColors.lionGold, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              if (next != null) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: i.count / next.$1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: v, minHeight: 10, color: WgfColors.lionGold, backgroundColor: Colors.white12),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Ancora ${next.$1 - i.count} per diventare «${next.$2}»',
                    style: const TextStyle(color: WgfColors.muted)),
              ] else
                const Text('Hai raggiunto il grado massimo. Leggenda! 🦁'),
              const SizedBox(height: 8),
              const Text('Il grado compare sul tuo profilo. Contano solo gli amici che si iscrivono e usano il tuo codice.',
                  style: TextStyle(color: WgfColors.muted, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (i.invitedBy != null)
          FadeSlideIn(
            index: 2,
            child: GlassCard(
              child: Row(children: [
                const Icon(Icons.handshake_rounded, color: WgfColors.lionGold),
                const SizedBox(width: 10),
                Expanded(child: Text('Sei entrato con l\'invito di @${i.invitedBy}')),
              ]),
            ),
          )
        else if (i.canRedeem)
          FadeSlideIn(
            index: 2,
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ti ha invitato un amico?', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'WGF-XXXXXX', prefixIcon: Icon(Icons.vpn_key_rounded)),
                ),
                const SizedBox(height: 10),
                GradientButton(label: 'Usa il codice', busy: _busy, onPressed: _busy ? null : _redeem),
              ]),
            ),
          ),
      ]);
    }, onRetry: () => ref.invalidate(inviteInfoProvider));
  }
}

class _Leaderboard extends ConsumerWidget {
  const _Leaderboard({required this.kind, required this.unit, required this.empty});
  final String kind;
  final String unit;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leaderboardProvider(kind));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(leaderboardProvider(kind)),
      child: asyncView(data, (list) {
        final ranked = list.where((e) => e.score > 0).toList();
        if (ranked.isEmpty) {
          return ListView(children: [
            const SizedBox(height: 60),
            EmptyState(icon: Icons.emoji_events_outlined, title: 'Classifica vuota', message: empty),
          ]);
        }
        final mine = list.where((e) => e.isMe).firstOrNull;
        return ListView(padding: const EdgeInsets.all(12), children: [
          _Podium(top: ranked.take(3).toList(), unit: unit),
          const SizedBox(height: 12),
          for (final (i, e) in ranked.skip(3).indexed)
            FadeSlideIn(index: i, child: _Row(e: e, unit: unit)),
          if (mine != null && mine.rank > 3 && !ranked.skip(3).contains(mine)) ...[
            const Divider(height: 24),
            _Row(e: mine, unit: unit),
          ],
          const SizedBox(height: 8),
          const Text('La classifica mostra solo i fan della tua fascia d\'età.',
              textAlign: TextAlign.center, style: TextStyle(color: WgfColors.muted, fontSize: 12)),
        ]);
      }, onRetry: () => ref.invalidate(leaderboardProvider(kind))),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.unit});
  final List<LeaderboardEntry> top;
  final String unit;

  @override
  Widget build(BuildContext context) {
    const heights = [130.0, 100.0, 80.0];
    const medals = ['🥇', '🥈', '🥉'];
    // ordine visivo: 2º, 1º, 3º
    final order = [if (top.length > 1) 1, 0, if (top.length > 2) 2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final i in order)
          Expanded(
            child: GestureDetector(
              onTap: top[i].isMe ? null : () => context.push('/user/${top[i].userId}'),
              child: Column(children: [
                Text(medals[i], style: const TextStyle(fontSize: 28)),
                UserAvatar(name: top[i].name, path: top[i].avatarPath, size: i == 0 ? 64 : 50, ring: true),
                const SizedBox(height: 4),
                Text(top[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, color: top[i].isMe ? WgfColors.lionGold : null)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: heights[i]),
                  duration: Duration(milliseconds: 700 + 250 * i),
                  curve: Curves.easeOutBack,
                  builder: (_, h, __) => Container(
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      gradient: i == 0
                          ? WgfColors.lionGradient
                          : LinearGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.06)]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Text('${top[i].score}$unit',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.e, required this.unit});
  final LeaderboardEntry e;
  final String unit;

  @override
  Widget build(BuildContext context) => Card(
        color: e.isMe ? WgfColors.lionGold.withValues(alpha: 0.12) : null,
        child: ListTile(
          onTap: e.isMe ? null : () => context.push('/user/${e.userId}'),
          leading: SizedBox(
            width: 80,
            child: Row(children: [
              SizedBox(width: 30, child: Text('${e.rank}', style: const TextStyle(fontWeight: FontWeight.w900))),
              UserAvatar(name: e.name, path: e.avatarPath, size: 40),
            ]),
          ),
          title: Text(e.isMe ? '${e.name} (tu)' : e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: e.badge.isEmpty ? Text('@${e.username}') : Text('@${e.username} · ${e.badge}'),
          trailing: Text('${e.score}$unit',
              style: const TextStyle(color: WgfColors.lionGold, fontWeight: FontWeight.w900)),
        ),
      );
}
