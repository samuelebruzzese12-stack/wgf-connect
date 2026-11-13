import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

final _consentsProvider = FutureProvider<Map<String, bool>>((ref) => ref.watch(profileRepoProvider).consents());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _pref(WidgetRef ref, String key, bool v) async {
    await ref.read(profileRepoProvider).updatePreferences({key: v});
    ref.invalidate(myPreferencesProvider);
  }

  Future<void> _profileFlag(WidgetRef ref, String key, bool v) async {
    await ref.read(profileRepoProvider).update({key: v});
    ref.invalidate(myProfileProvider);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final data = await ref.read(profileRepoProvider).exportData();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('I tuoi dati'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(child: SelectableText(json, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copia tutto'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, MyProfile me) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare l\'account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verranno cancellati definitivamente profilo, foto, post, commenti, messaggi inviati, match e iscrizioni. '
              'L\'operazione non si può annullare.',
            ),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Scrivi "${me.username}" per confermare')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WgfColors.danger),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim() == me.username),
            child: const Text('Elimina per sempre'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileRepoProvider).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final prefs = ref.watch(myPreferencesProvider).valueOrNull;
    final consents = ref.watch(_consentsProvider).valueOrNull ?? const {};
    final dating = ref.watch(datingStatusProvider).valueOrNull;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
          child: Text(t.toUpperCase(), style: const TextStyle(color: WgfColors.electricViolet, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        );
    Widget prefSwitch(String key, String title) => SwitchListTile(
          value: (prefs?[key] ?? true) as bool,
          onChanged: prefs == null ? null : (v) => _pref(ref, key, v),
          title: Text(title),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          header('Privacy'),
          SwitchListTile(
            value: me?.showAge ?? true,
            onChanged: me == null ? null : (v) => _profileFlag(ref, 'show_age', v),
            title: const Text('Mostra la mia età'),
            subtitle: const Text('La data di nascita completa non è mai visibile.'),
          ),
          SwitchListTile(
            value: me?.discoverable ?? true,
            onChanged: me == null ? null : (v) => _profileFlag(ref, 'discoverable', v),
            title: const Text('Visibile in Discover e FanFinder'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Utenti bloccati'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/blocked'),
          ),
          header('Dating'),
          ListTile(
            leading: const Icon(Icons.verified_user_rounded),
            title: const Text('Verifica della maggiore età'),
            subtitle: Text(switch (dating?['verification']) {
              'verified' => 'Verificato ✓',
              'pending' => 'In attesa di verifica',
              'rejected' => 'Non riuscita: puoi riprovare',
              _ => 'Necessaria per il dating',
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/verify'),
          ),
          header('Notifiche'),
          prefSwitch('notify_matches', 'Nuovi match'),
          prefSwitch('notify_messages', 'Nuovi messaggi'),
          prefSwitch('notify_likes', 'Like e Super Like'),
          prefSwitch('notify_comments', 'Commenti e risposte'),
          prefSwitch('notify_events', 'Eventi'),
          prefSwitch('notify_community', 'Aggiornamenti della community'),
          prefSwitch('notify_creator', 'Aggiornamenti di Sentinel'),
          header('Consensi facoltativi'),
          SwitchListTile(
            value: consents['marketing'] ?? false,
            onChanged: (v) async {
              await ref.read(profileRepoProvider).setConsent('marketing', v);
              ref.invalidate(_consentsProvider);
            },
            title: const Text('Comunicazioni sul progetto via email'),
          ),
          SwitchListTile(
            value: consents['analytics'] ?? false,
            onChanged: (v) async {
              await ref.read(profileRepoProvider).setConsent('analytics', v);
              ref.invalidate(_consentsProvider);
            },
            title: const Text('Statistiche anonime di utilizzo'),
          ),
          header('Documenti'),
          for (final d in const [
            ('privacy', 'Informativa privacy'),
            ('termini', 'Termini di servizio'),
            ('linee-guida', 'Linee guida della community'),
            ('sicurezza', 'Sicurezza negli incontri e nel dating'),
          ])
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(d.$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/legal/${d.$1}'),
            ),
          header('I tuoi dati'),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Esporta i miei dati'),
            subtitle: const Text('Copia di tutti i dati personali (GDPR)'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Esci'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          if (me != null)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: WgfColors.danger),
              title: const Text('Elimina account', style: TextStyle(color: WgfColors.danger)),
              onTap: () => _delete(context, ref, me),
            ),
          const SizedBox(height: 24),
          const Center(child: WgfLogo(size: 36, glow: 0.3)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'WGF CONNECT 0.1 · progetto indipendente, non affiliato ai WGF',
              style: TextStyle(color: WgfColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

final _blockedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.watch(profileRepoProvider).blockedUsers());

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(_blockedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Utenti bloccati')),
      body: asyncView(
        blocked,
        (list) => list.isEmpty
            ? const EmptyState(icon: Icons.block_rounded, title: 'Nessun utente bloccato')
            : ListView(
                children: [
                  for (final b in list)
                    ListTile(
                      leading: const Icon(Icons.person_off_rounded),
                      title: Text('@${b['username']}'),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref.read(profileRepoProvider).unblock(b['user_id'] as String);
                          ref.invalidate(_blockedProvider);
                        },
                        child: const Text('Sblocca'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
