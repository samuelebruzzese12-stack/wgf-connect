import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../moderation/report_sheet.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId, this.initial});
  final String eventId;
  final EventItem? initial;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  EventItem? _find() {
    final list = ref.watch(eventsProvider(null)).valueOrNull;
    return list?.where((e) => e.id == widget.eventId).firstOrNull ?? widget.initial;
  }

  Future<void> _toggle(EventItem e) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(eventsRepoProvider);
      e.joined ? await repo.leave(e.id) : await repo.join(e.id);
      ref.invalidate(eventsProvider);
      ref.invalidate(eventParticipantsProvider(e.id));
    } catch (err) {
      final msg = '$err'.contains('event_full')
          ? 'Evento al completo.'
          : '$err'.contains('event_not_open')
              ? 'Le iscrizioni non sono aperte.'
              : friendlyError(err);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _find();
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.event_busy_rounded, title: 'Evento non disponibile'),
      );
    }
    final participants = ref.watch(eventParticipantsProvider(e.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            actions: [
              if (e.isMine)
                IconButton(
                  tooltip: 'Elimina evento',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    await ref.read(eventsRepoProvider).delete(e.id);
                    ref.invalidate(eventsProvider);
                    if (context.mounted) context.pop();
                  },
                )
              else
                IconButton(
                  tooltip: 'Segnala evento',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => showReportSheet(context, ref, targetType: 'event', targetId: e.id),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(e.title, maxLines: 2),
              background: AuroraBackground(
                child: Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(
                      e.category == 'gaming' ? Icons.sports_esports_rounded : Icons.celebration_rounded,
                      size: 120,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                if (e.status == 'pending_review')
                  const GlassCard(
                    child: Row(children: [
                      Icon(Icons.hourglass_top_rounded),
                      SizedBox(width: 10),
                      Expanded(child: Text('Il tuo evento è in revisione: sarà visibile dopo l\'approvazione dei moderatori.')),
                    ]),
                  ),
                const SizedBox(height: 8),
                _InfoRow(Icons.schedule_rounded, eventDate(e.startsAt)),
                _InfoRow(Icons.location_city_rounded, e.city),
                if (e.venue != null && e.venue!.isNotEmpty) _InfoRow(Icons.place_rounded, e.venue!),
                _InfoRow(Icons.category_rounded, kEventCategories[e.category] ?? e.category),
                if (e.organizer != null) _InfoRow(Icons.person_rounded, 'Organizza @${e.organizer}'),
                const SizedBox(height: 12),
                Text(e.description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                if (e.status == 'published')
                  GradientButton(
                    label: e.joined ? 'Annulla partecipazione' : (e.isFull ? 'Evento al completo' : 'Partecipa'),
                    icon: e.joined ? Icons.close_rounded : Icons.check_rounded,
                    busy: _busy,
                    onPressed: (e.isFull && !e.joined) ? null : () => _toggle(e),
                  ),
                const SizedBox(height: 20),
                const GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.shield_rounded, color: WgfColors.electricViolet),
                        SizedBox(width: 8),
                        Text('Sicurezza agli incontri', style: TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      SizedBox(height: 8),
                      Text('• Incontratevi solo in luoghi pubblici e frequentati.\n'
                          '• Dite a una persona di fiducia dove andate e con chi.\n'
                          '• Organizzate da soli il viaggio di andata e ritorno.\n'
                          '• Non condividete indirizzi di casa o dati bancari.\n'
                          '• Se qualcosa non va, andate via e segnalate. In emergenza: 112.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Partecipanti (${e.participants})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                participants.when(
                  data: (list) => list.isEmpty
                      ? const Text('Ancora nessuno: sii il primo!', style: TextStyle(color: WgfColors.muted))
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final p in list)
                              GestureDetector(
                                onTap: () => context.push('/user/${p['user_id']}'),
                                child: Column(children: [
                                  UserAvatar(
                                    name: ((p['profiles'] as Map?)?['username'] ?? '?') as String,
                                    path: (p['profiles'] as Map?)?['avatar_path'] as String?,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      ((p['profiles'] as Map?)?['username'] ?? '') as String,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ]),
                              ),
                          ],
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Impossibile caricare i partecipanti'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 20, color: WgfColors.electricViolet),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
