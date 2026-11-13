import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/repositories.dart';

const _reasons = {
  'harassment': 'Molestie o bullismo',
  'inappropriate': 'Contenuto inappropriato',
  'spam': 'Spam o truffa',
  'hate': 'Odio o discriminazione',
  'impersonation': 'Si spaccia per qualcun altro',
  'minor_safety': 'Sicurezza di un minore',
  'self_harm': 'Qualcuno potrebbe farsi del male',
  'scam': 'Richiesta di soldi o dati personali',
  'other': 'Altro',
};

/// Segnala un contenuto e, se indicato, offre anche il blocco dell'utente.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  String? userIdToBlock,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: WgfColors.surface,
    builder: (ctx) => _ReportSheet(targetType: targetType, targetId: targetId, userIdToBlock: userIdToBlock),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId, this.userIdToBlock});
  final String targetType;
  final String targetId;
  final String? userIdToBlock;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason;
  bool _block = false;
  bool _busy = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _busy = true);
    final repo = ref.read(moderationRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await repo.report(widget.targetType, widget.targetId, _reason!, _details.text.trim().isEmpty ? null : _details.text.trim());
      if (_block && widget.userIdToBlock != null) {
        await repo.block(widget.userIdToBlock!);
        ref.invalidate(conversationsProvider);
        ref.invalidate(feedProvider);
      }
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Segnalazione inviata. Grazie: la esamineremo al più presto.')));
    } catch (_) {
      setState(() => _busy = false);
      messenger.showSnackBar(const SnackBar(content: Text('Invio non riuscito, riprova.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Segnala', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Chi segnali non saprà che sei stato tu.', style: TextStyle(color: WgfColors.muted)),
            const SizedBox(height: 12),
            for (final e in _reasons.entries)
              RadioListTile<String>(
                value: e.key,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                title: Text(e.value),
                dense: true,
              ),
            if (_reason == 'self_harm')
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WgfColors.darkViolet.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Se qualcuno è in pericolo immediato chiama il 112. '
                  'Telefono Amico Italia: 02 2327 2327.',
                ),
              ),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Dettagli (facoltativo)'),
            ),
            if (widget.userIdToBlock != null)
              SwitchListTile(
                value: _block,
                onChanged: (v) => setState(() => _block = v),
                title: const Text('Blocca anche questo utente'),
                subtitle: const Text('Non potrà più vederti né contattarti.'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reason == null || _busy ? null : _send,
              style: FilledButton.styleFrom(backgroundColor: WgfColors.danger),
              child: const Text('Invia segnalazione'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Conferma e blocco diretto di un utente.
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, String userId, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloccare $name?'),
      content: const Text(
        'Non vedrete più i rispettivi profili e contenuti e la chat verrà chiusa. '
        'Puoi sbloccare in qualsiasi momento dalle Impostazioni.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: WgfColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Blocca'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(moderationRepoProvider).block(userId);
  ref.invalidate(conversationsProvider);
  return true;
}
