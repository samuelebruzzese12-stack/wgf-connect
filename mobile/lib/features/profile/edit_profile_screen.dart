import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/options.dart';
import '../../core/constants/wgf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final _games = TextEditingController();
  final _interests = <String>{};
  final _friendship = <String>{};
  final _wgf = <String>{};
  bool _loaded = false;
  bool _busy = false;

  void _fill(MyProfile p) {
    if (_loaded) return;
    _loaded = true;
    _name.text = p.displayName ?? '';
    _bio.text = p.bio ?? '';
    _city.text = p.city;
    _games.text = p.favoriteGames.join(', ');
    _wgf.addAll(p.favoriteWgfCharacters);
    _interests.addAll(p.interests);
    _friendship.addAll(p.friendshipPreferences);
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _city, _games]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepoProvider).update({
        'display_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'city': _city.text.trim(),
        'favorite_games': splitTags(_games.text),
        'favorite_wgf_characters': _wgf.toList(),
        'interests': _interests.toList(),
        'friendship_preferences': _friendship.toList(),
      });
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(String title, List<String> options, Set<String> selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options)
              FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
              ),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifica profilo')),
      body: asyncView(me, (MyProfile? p) {
        if (p == null) return const SizedBox.shrink();
        _fill(p);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'Nome visualizzato')),
            TextField(controller: _bio, maxLength: 500, maxLines: 4, decoration: const InputDecoration(labelText: 'Descrizione')),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città', helperText: 'Scelta da te: non usiamo il GPS'),
            ),
            const SizedBox(height: 12),
            _chips('Personaggi WGF preferiti', kWgfCharacters, _wgf),
            const SizedBox(height: 16),
            TextField(
              controller: _games,
              decoration: const InputDecoration(
                labelText: 'Videogiochi preferiti',
                helperText: 'Separati da virgola',
                prefixIcon: Icon(Icons.sports_esports_rounded),
              ),
            ),
            const SizedBox(height: 20),
            _chips('Interessi', kInterestOptions, _interests),
            const SizedBox(height: 16),
            _chips('Cosa cerchi', kFriendshipOptions, _friendship),
            const SizedBox(height: 24),
            GradientButton(label: 'Salva', icon: Icons.check_rounded, busy: _busy, onPressed: _save),
            const SizedBox(height: 8),
            const Text(
              'Username, data di nascita e fascia d\'età non sono modificabili da qui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: WgfColors.muted, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }
}
