import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// Pagina completa WGF EVENTS (aperta dalla WGF ZONE o dal menu).
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('WGF EVENTS')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/events/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Proponi raduno'),
        ),
        body: const EventsTab(),
      );
}

/// WGF EVENTS: calendario di incontri, raduni ed eventi gaming.
class EventsTab extends ConsumerStatefulWidget {
  const EventsTab({super.key});
  @override
  ConsumerState<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<EventsTab> {
  String? _city;

  Future<void> _pickCity() async {
    final ctrl = TextEditingController(text: _city ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtra per città'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Es. Milano')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Tutte')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Applica')),
        ],
      ),
    );
    if (v != null) setState(() => _city = v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider(_city));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.location_on_rounded, size: 18),
                label: Text(_city ?? 'Tutte le città'),
                onPressed: _pickCity,
              ),
              const Spacer(),
              const Icon(Icons.shield_rounded, size: 16, color: WgfColors.muted),
              const SizedBox(width: 4),
              const Text('Eventi moderati', style: TextStyle(color: WgfColors.muted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(eventsProvider(_city).future),
            child: asyncView(
              events,
              (list) => list.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'Nessun evento in programma',
                        message: 'Proponi tu il primo raduno della community!',
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => FadeSlideIn(index: i, child: EventCard(e: list[i])),
                    ),
              onRetry: () => ref.invalidate(eventsProvider(_city)),
            ),
          ),
        ),
      ],
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.e});
  final EventItem e;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/events/${e.id}', extra: e),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(gradient: WgfColors.brandGradient, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text(dayNumber(e.startsAt), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                Text(monthShort(e.startsAt), style: const TextStyle(fontSize: 12, letterSpacing: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(kEventCategories[e.category] ?? e.category),
                    if (e.status == 'pending_review') ...[
                      const SizedBox(width: 6),
                      const TagChip('In revisione', icon: Icons.hourglass_top_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(e.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${e.city} · ${clock(e.startsAt)}', style: const TextStyle(color: WgfColors.muted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 16, color: WgfColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      e.maxParticipants == null ? '${e.participants} partecipanti' : '${e.participants}/${e.maxParticipants}',
                      style: const TextStyle(color: WgfColors.muted, fontSize: 13),
                    ),
                    const Spacer(),
                    if (e.joined) const TagChip('Partecipi', icon: Icons.check_rounded),
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
