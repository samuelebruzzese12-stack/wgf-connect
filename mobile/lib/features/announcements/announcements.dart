import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

// =====================================================================
// Stile per livello: info (viola), importante (oro), urgente (rosso)
// =====================================================================
({Color color, Gradient gradient, IconData icon, String label}) announcementStyle(String level) => switch (level) {
      'urgent' => (
          color: WgfColors.danger,
          gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFF9B1030)]),
          icon: Icons.warning_amber_rounded,
          label: 'URGENTE',
        ),
      'info' => (
          color: WgfColors.electricViolet,
          gradient: WgfColors.brandGradient,
          icon: Icons.info_rounded,
          label: 'INFORMAZIONE',
        ),
      _ => (
          color: WgfColors.lionGold,
          gradient: WgfColors.lionGradient,
          icon: Icons.campaign_rounded,
          label: 'COMUNICAZIONE IMPORTANTE',
        ),
    };

/// Avvolge la home: quando arriva un avviso nuovo lo mostra subito a tutto schermo.
class AnnouncementGate extends ConsumerStatefulWidget {
  const AnnouncementGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<AnnouncementGate> {
  bool _showing = false;
  final _shown = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_showing || !mounted) return;
    List<Map<String, dynamic>> list;
    try {
      list = await ref.read(announcementsRepoProvider).pending();
    } catch (_) {
      return;
    }
    // dal più vecchio al più recente
    for (final a in list.reversed) {
      final id = a['id'] as String;
      if (_shown.contains(id) || !mounted) continue;
      _shown.add(id);
      _showing = true;
      await showAnnouncementDialog(context, a);
      _showing = false;
      try {
        await ref.read(announcementsRepoProvider).dismiss(id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(announcementsStreamProvider, (_, __) => _check());
    return widget.child;
  }
}

/// Finestra a comparsa animata con l'avviso.
Future<void> showAnnouncementDialog(BuildContext context, Map<String, dynamic> a) {
  final level = (a['level'] ?? 'important') as String;
  level == 'urgent' ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'comunicazione',
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(c), child: child),
      );
    },
    pageBuilder: (ctx, _, __) => _AnnouncementView(a: a),
  );
}

class _AnnouncementView extends StatefulWidget {
  const _AnnouncementView({required this.a});
  final Map<String, dynamic> a;

  @override
  State<_AnnouncementView> createState() => _AnnouncementViewState();
}

class _AnnouncementViewState extends State<_AnnouncementView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final st = announcementStyle((a['level'] ?? 'important') as String);
    final link = a['link_url'] as String?;
    final created = DateTime.tryParse((a['created_at'] ?? '') as String)?.toLocal();
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: st.gradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: st.color.withValues(alpha: 0.25 + 0.3 * _pulse.value), blurRadius: 34)],
                ),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                decoration: BoxDecoration(color: WgfColors.surface, borderRadius: BorderRadius.circular(24)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 0.92, end: 1.08).animate(_pulse),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: st.gradient),
                          child: Icon(st.icon, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(st.label, style: TextStyle(color: st.color, letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        (a['title'] ?? '') as String,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Text((a['body'] ?? '') as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5)),
                      const SizedBox(height: 12),
                      Text(
                        'SENTINEL · WGF CONNECT${created != null ? ' · ${timeAgo(created)}' : ''}',
                        style: const TextStyle(color: WgfColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      if (link != null) ...[
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Apri il link'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      GradientButton(label: 'Ho capito', icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Schermata admin: invia una comunicazione ufficiale
// =====================================================================
class SendAnnouncementScreen extends ConsumerStatefulWidget {
  const SendAnnouncementScreen({super.key});
  @override
  ConsumerState<SendAnnouncementScreen> createState() => _SendAnnouncementScreenState();
}

class _SendAnnouncementScreenState extends ConsumerState<SendAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _level = 'important';
  int _hours = 72;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final link = _link.text.trim();
    if (title.length < 3 || body.isEmpty) {
      _snack('Scrivi un titolo (almeno 3 caratteri) e il messaggio.');
      return;
    }
    if (link.isNotEmpty && !link.startsWith('https://')) {
      _snack('Il link deve iniziare con https://');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inviare a tutti?'),
        content: const Text('Tutti gli utenti attivi riceveranno la comunicazione come finestra a comparsa e notifica.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invia')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(announcementsRepoProvider).send(
            title: title,
            body: body,
            level: _level,
            expiresHours: _hours,
            link: link.isEmpty ? null : link,
          );
      _title.clear();
      _body.clear();
      _link.clear();
      _snack('Comunicazione inviata a tutta la community 📢');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final sent = ref.watch(announcementsStreamProvider);
    final preview = {
      'title': _title.text.isEmpty ? 'Titolo della comunicazione' : _title.text,
      'body': _body.text.isEmpty ? 'Il testo apparirà qui.' : _body.text,
      'level': _level,
      'link_url': _link.text.trim().isEmpty ? null : _link.text.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicazioni ufficiali')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'info', label: Text('Info'), icon: Icon(Icons.info_rounded)),
              ButtonSegment(value: 'important', label: Text('Importante'), icon: Icon(Icons.campaign_rounded)),
              ButtonSegment(value: 'urgent', label: Text('Urgente'), icon: Icon(Icons.warning_amber_rounded)),
            ],
            selected: {_level},
            onSelectionChanged: (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          TextField(
            controller: _body,
            maxLength: 3000,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Messaggio'),
          ),
          TextField(
            controller: _link,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Link (facoltativo)', hintText: 'https://...'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _hours,
            decoration: const InputDecoration(labelText: 'Resta attiva per'),
            items: const [
              DropdownMenuItem(value: 6, child: Text('6 ore')),
              DropdownMenuItem(value: 24, child: Text('1 giorno')),
              DropdownMenuItem(value: 72, child: Text('3 giorni')),
              DropdownMenuItem(value: 168, child: Text('1 settimana')),
              DropdownMenuItem(value: 0, child: Text('Finché non la termino')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 72),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showAnnouncementDialog(context, preview),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('Anteprima'),
          ),
          const SizedBox(height: 10),
          GradientButton(label: 'Invia a tutti', icon: Icons.send_rounded, busy: _busy, onPressed: _send),
          const SizedBox(height: 28),
          Text('Inviate', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...sent.when<List<Widget>>(
            data: (list) => list.isEmpty
                ? [const Text('Nessuna comunicazione ancora.', style: TextStyle(color: WgfColors.muted))]
                : [
                    for (final a in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(announcementStyle((a['level'] ?? '') as String).icon,
                                color: announcementStyle((a['level'] ?? '') as String).color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text((a['title'] ?? '') as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${timeAgo(DateTime.parse(a['created_at'] as String).toLocal())} · ${a['active'] == true ? 'attiva' : 'terminata'}',
                                  style: const TextStyle(color: WgfColors.muted, fontSize: 12),
                                ),
                              ]),
                            ),
                            if (a['active'] == true)
                              TextButton(
                                onPressed: () => ref.read(announcementsRepoProvider).end(a['id'] as String),
                                child: const Text('Termina'),
                              ),
                          ]),
                        ),
                      ),
                  ],
            loading: () => [const LinearProgressIndicator()],
            error: (_, __) => [const SizedBox.shrink()],
          ),
        ],
      ),
    );
  }
}
