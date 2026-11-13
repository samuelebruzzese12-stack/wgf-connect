import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/options.dart';
import '../../../core/widgets/brand_header.dart';
import '../../../core/widgets/visuals.dart';
import '../../authentication/data/auth_repository.dart';

const _interestOptions = kInterestOptions;
const _friendshipOptions = kFriendshipOptions;

/// Completa il profilo. L'età viene verificata dal SERVER (complete_onboarding):
/// questa schermata non decide nulla sulla fascia d'età.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _city = TextEditingController();
  String _country = 'IT';
  DateTime? _birthDate;
  final _interests = <String>{};
  final _friendship = <String>{};
  bool _terms = false;
  bool _privacy = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data di nascita (non sarà mai pubblicata)',
    );
    if (d != null) setState(() => _birthDate = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _error = 'Inserisci la data di nascita.');
      return;
    }
    if (!_terms || !_privacy) {
      setState(() => _error = 'Devi accettare termini e informativa privacy.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).completeOnboarding(
            username: _username.text.trim().toLowerCase(),
            birthDate: _birthDate!,
            country: _country,
            city: _city.text.trim(),
            interests: _interests.toList(),
            friendshipPreferences: _friendship.toList(),
            acceptTerms: _terms,
            acceptPrivacy: _privacy,
          );
      ref.invalidate(hasProfileProvider);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return AuroraBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Completa il profilo'),
        actions: [
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const BrandHeader(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username', helperText: '3–20 caratteri: a-z, 0-9, _'),
                validator: (v) => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch((v ?? '').trim().toLowerCase())
                    ? null
                    : 'Username non valido',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.cake_outlined),
                label: Text(_birthDate == null ? 'Data di nascita' : fmt.format(_birthDate!)),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Mostriamo solo la tua età, mai la data completa.', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _country,
                decoration: const InputDecoration(labelText: 'Paese'),
                items: [
                  for (final c in kCountries.entries) DropdownMenuItem(value: c.key, child: Text(c.value)),
                ],
                onChanged: (v) => setState(() => _country = v ?? 'IT'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Città',
                  helperText: 'Scelta da te: non usiamo il GPS.',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Inserisci la città' : null,
              ),
              const SizedBox(height: 20),
              _chips('Interessi', _interestOptions, _interests),
              const SizedBox(height: 16),
              _chips('Cosa cerchi', _friendshipOptions, _friendship),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v ?? false),
                title: const Text('Accetto i Termini di servizio e le Linee guida'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: () => context.push('/legal/termini'), child: const Text('Termini')),
                  TextButton(onPressed: () => context.push('/legal/linee-guida'), child: const Text('Linee guida')),
                  TextButton(onPressed: () => context.push('/legal/privacy'), child: const Text('Privacy')),
                ],
              ),
              CheckboxListTile(
                value: _privacy,
                onChanged: (v) => setState(() => _privacy = v ?? false),
                title: const Text('Ho letto l\'Informativa privacy'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _busy ? null : _submit, child: const Text('Entra in WGF CONNECT')),
              const SizedBox(height: 12),
              const Text(
                'WGF CONNECT è riservata ai maggiorenni. Progetto indipendente, non affiliato ai WGF.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
