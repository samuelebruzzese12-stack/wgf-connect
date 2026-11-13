import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../moderation/report_sheet.dart';

/// NON SEI SOLO – spazio di ascolto e incoraggiamento tra fan.
/// Non è un servizio psicologico o medico.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    var anonymous = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Condividi un pensiero', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 6,
                maxLength: 3000,
                decoration: const InputDecoration(hintText: 'Come stai davvero oggi?'),
              ),
              SwitchListTile(
                value: anonymous,
                onChanged: (v) => set(() => anonymous = v),
                title: const Text('Pubblica in forma anonima'),
                subtitle: const Text('Gli altri utenti non vedranno il tuo nome.'),
              ),
              const SizedBox(height: 8),
              GradientButton(label: 'Pubblica', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(supportRepoProvider).post(ctrl.text.trim(), anonymous);
      ref.invalidate(supportPostsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(supportPostsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Non sei solo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _write(context, ref),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Scrivi'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(supportPostsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const HelpBanner(),
            const SizedBox(height: 16),
            ...posts.when<List<Widget>>(
              data: (list) => list.isEmpty
                  ? [const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Uno spazio gentile',
                      message: 'Qui puoi condividere un pensiero o una difficoltà e ricevere incoraggiamento.',
                    )]
                  : [
                      for (var i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(index: i, child: _SupportCard(p: list[i])),
                        ),
                    ],
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, __) => [const Text('Impossibile caricare')],
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicazioni per chiedere aiuto a professionisti e servizi di emergenza.
class HelpBanner extends StatelessWidget {
  const HelpBanner({super.key});

  Future<void> _call(String number) => launchUrl(Uri.parse('tel:$number'));

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.volunteer_activism_rounded, color: WgfColors.electricViolet),
            SizedBox(width: 8),
            Expanded(child: Text('Hai bisogno di aiuto ora?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Questa sezione è uno spazio di ascolto tra fan: non è un servizio psicologico o medico. '
            'Se stai male o sei in pericolo, parla con un professionista o chiama subito:',
            style: TextStyle(color: WgfColors.muted),
          ),
          const SizedBox(height: 10),
          _HelpLine(name: 'Emergenze', number: '112', note: 'sempre attivo', onTap: () => _call('112')),
          _HelpLine(
            name: 'Telefono Amico Italia',
            number: '02 2327 2327',
            note: 'ascolto anonimo',
            onTap: () => _call('0223272327'),
          ),
          _HelpLine(
            name: 'Telefono Amico – WhatsApp',
            number: '324 011 7252',
            note: 'chat',
            onTap: () => launchUrl(Uri.parse('https://wa.me/393240117252'), mode: LaunchMode.externalApplication),
          ),
          _HelpLine(name: 'Samaritans Onlus', number: '06 77208977', note: 'ore 13–22', onTap: () => _call('0677208977')),
          _HelpLine(name: 'Antiviolenza e stalking', number: '1522', note: 'gratuito, 24h', onTap: () => _call('1522')),
          const SizedBox(height: 6),
          const Text(
            'Non condividere mai qui dati personali. Se qualcuno ti chiede soldi, foto o informazioni private, segnalalo.',
            style: TextStyle(color: WgfColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.name, required this.number, required this.note, required this.onTap});
  final String name;
  final String number;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.call_rounded, color: WgfColors.electricViolet),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$number · $note'),
        onTap: onTap,
      );
}

class _SupportCard extends ConsumerStatefulWidget {
  const _SupportCard({required this.p});
  final SupportPost p;

  @override
  ConsumerState<_SupportCard> createState() => _SupportCardState();
}

class _SupportCardState extends ConsumerState<_SupportCard> {
  bool _open = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    try {
      await ref.read(supportRepoProvider).reply(widget.p.id, t);
      _ctrl.clear();
      ref.invalidate(supportRepliesProvider(widget.p.id));
      ref.invalidate(supportPostsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final me = ref.watch(currentUserIdProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              p.anonymous && p.username == null
                  ? const CircleAvatar(radius: 18, backgroundColor: WgfColors.darkViolet, child: Icon(Icons.favorite_rounded, size: 18))
                  : UserAvatar(name: p.username ?? '?', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.username == null ? 'Un membro della community' : (p.anonymous ? '${p.username} (anonimo per gli altri)' : p.username!),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(timeAgo(p.createdAt), style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
              if (p.authorId != me)
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  onPressed: () => showReportSheet(context, ref, targetType: 'support_post', targetId: p.id),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(p.body, style: Theme.of(context).textTheme.bodyLarge),
          TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(p.replies == 0 ? 'Invia un incoraggiamento' : '${p.replies} incoraggiamenti'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: !_open
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      ...ref.watch(supportRepliesProvider(p.id)).when<List<Widget>>(
                            data: (list) => [
                              for (final r in list)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: UserAvatar(
                                    name: ((r['profiles'] as Map?)?['username'] ?? '?') as String,
                                    path: (r['profiles'] as Map?)?['avatar_path'] as String?,
                                    size: 30,
                                  ),
                                  title: Text(r['body'] as String),
                                  trailing: r['author_id'] == me
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.flag_outlined, size: 18),
                                          onPressed: () => showReportSheet(
                                            context,
                                            ref,
                                            targetType: 'support_reply',
                                            targetId: r['id'] as String,
                                            userIdToBlock: r['author_id'] as String,
                                          ),
                                        ),
                                ),
                            ],
                            loading: () => [const LinearProgressIndicator()],
                            error: (_, __) => [const SizedBox.shrink()],
                          ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              maxLength: 1000,
                              decoration: const InputDecoration(hintText: 'Scrivi parole gentili…', counterText: ''),
                            ),
                          ),
                          IconButton(onPressed: _reply, icon: const Icon(Icons.send_rounded, color: WgfColors.electricViolet)),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
