import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});
  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _venue = TextEditingController();
  final _max = TextEditingController();
  String _category = 'meetup';
  String _country = 'IT';
  DateTime? _start;
  bool _publicPlace = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _desc, _city, _venue, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 16, minute: 0));
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_start == null) {
      setState(() => _error = 'Scegli data e ora.');
      return;
    }
    if (_category != 'online' && !_publicPlace) {
      setState(() => _error = 'Conferma che il luogo è pubblico.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(eventsRepoProvider).create({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'country': _country,
        'city': _city.text.trim(),
        'venue_public': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'starts_at': _start!.toUtc().toIso8601String(),
        'max_participants': int.tryParse(_max.text.trim()),
      });
      ref.invalidate(eventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento inviato! Sarà pubblicato dopo la revisione dei moderatori.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proponi un evento')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Titolo'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Almeno 3 caratteri' : null,
            ),
            TextFormField(
              controller: _desc,
              maxLines: 5,
              maxLength: 3000,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Descrivi l\'evento' : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in kEventCategories.entries)
                  ChoiceChip(
                    label: Text(c.value),
                    selected: _category == c.key,
                    onSelected: (_) => setState(() => _category = c.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _country,
              decoration: const InputDecoration(labelText: 'Paese'),
              items: [for (final c in kCountries.entries) DropdownMenuItem(value: c.key, child: Text(c.value))],
              onChanged: (v) => setState(() => _country = v ?? 'IT'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Inserisci la città' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Luogo pubblico (facoltativo)',
                helperText: 'Es. "Piazza principale", "Fiera", "Bar del centro". MAI indirizzi privati.',
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(_start == null ? 'Data e ora' : eventDate(_start!)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _max,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Numero massimo di partecipanti (facoltativo)'),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = int.tryParse(v!.trim());
                return (n == null || n < 2 || n > 10000) ? 'Tra 2 e 10000' : null;
              },
            ),
            if (_category != 'online')
              CheckboxListTile(
                value: _publicPlace,
                onChanged: (v) => setState(() => _publicPlace = v ?? false),
                title: const Text('Confermo che l\'incontro si svolge in un luogo pubblico'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: WgfColors.danger))),
            const SizedBox(height: 12),
            GradientButton(label: 'Invia per revisione', icon: Icons.send_rounded, busy: _busy, onPressed: _submit),
            const SizedBox(height: 8),
            const Text(
              'Tutti gli eventi vengono controllati dai moderatori prima della pubblicazione.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WgfColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
