import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

/// Verifica manuale e gratuita della maggiore età per il dating.
/// Nessun documento o foto viene caricato nell'app.
class AgeVerificationScreen extends ConsumerStatefulWidget {
  const AgeVerificationScreen({super.key});
  @override
  ConsumerState<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends ConsumerState<AgeVerificationScreen> {
  bool _accept = false;
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref.read(discoverRepoProvider).requestAgeVerification();
      ref.invalidate(datingStatusProvider);
    } catch (e) {
      final msg = '$e'.contains('already_requested') ? 'Hai già una richiesta in corso.' : friendlyError(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(datingStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica maggiore età')),
      body: asyncView(status, (s) {
        final v = s['verification'] as String?;
        if (v == 'verified') {
          return const EmptyState(
            icon: Icons.verified_rounded,
            title: 'Sei verificato',
            message: 'Puoi usare il dating (quando è attivo) con altri adulti verificati.',
          );
        }
        if (v == 'pending') {
          return const EmptyState(
            icon: Icons.hourglass_top_rounded,
            title: 'Richiesta ricevuta',
            message: 'Un amministratore ti contatterà tramite la chat o l\'email dell\'account per una verifica breve. '
                'Non ti chiederemo mai di caricare documenti nell\'app.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const FadeSlideIn(child: Center(child: Icon(Icons.verified_user_rounded, size: 72, color: WgfColors.electricViolet))),
            const SizedBox(height: 16),
            Text('Dating sicuro, solo tra adulti', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const GlassCard(
              child: Text(
                'Come funziona:\n\n'
                '1. Invii la richiesta da qui.\n'
                '2. Un amministratore ti contatta e verifica che tu sia maggiorenne con una breve videochiamata, '
                'senza registrazioni e senza salvare copie di documenti.\n'
                '3. Nell\'app viene salvato solo l\'esito ("verificato" o "non verificato") e la data.\n\n'
                'Puoi chiedere la cancellazione dell\'esito in qualsiasi momento eliminando l\'account '
                'o scrivendo al titolare indicato nell\'informativa privacy.',
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _accept,
              onChanged: (x) => setState(() => _accept = x ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Dichiaro di essere maggiorenne e accetto le regole di sicurezza del dating.'),
            ),
            TextButton(onPressed: () => context.push('/legal/sicurezza'), child: const Text('Leggi le regole di sicurezza')),
            const SizedBox(height: 8),
            GradientButton(label: 'Richiedi la verifica', busy: _busy, onPressed: _accept ? _request : null),
            if (v == 'rejected') ...[
              const SizedBox(height: 12),
              const Text('La verifica precedente non è andata a buon fine. Puoi inviare una nuova richiesta.',
                  textAlign: TextAlign.center, style: TextStyle(color: WgfColors.muted)),
            ],
          ],
        );
      }),
    );
  }
}
