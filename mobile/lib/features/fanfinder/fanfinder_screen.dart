import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/options.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';
import '../discover/profile_card_view.dart';

/// FANFINDER: ricerca di fan per città, interessi, età e modalità.
/// Nessuna posizione GPS: la città è sempre quella scelta dall'utente.
class FanFinderScreen extends ConsumerStatefulWidget {
  const FanFinderScreen({super.key});
  @override
  ConsumerState<FanFinderScreen> createState() => _FanFinderScreenState();
}

class _FanFinderScreenState extends ConsumerState<FanFinderScreen> {
  final _city = TextEditingController();
  String? _interest;
  RangeValues _age = const RangeValues(18, 60);
  String _mode = 'friendship';
  final List<ProfileCard> _results = [];
  bool _loading = false;
  bool _hasMore = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(myProfileProvider.future).then((me) {
      if (me != null && mounted) {
        _city.text = me.city;
        _search();
      }
    });
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!more) _results.clear();
    });
    try {
      final list = await ref.read(discoverRepoProvider).discover(
            DiscoverFilter(
              mode: _mode,
              city: _city.text,
              interest: _interest,
              minAge: _age.start.round(),
              maxAge: _age.end.round() >= 60 ? null : _age.end.round(),
            ),
            limit: 24,
            offset: more ? _results.length : 0,
          );
      setState(() {
        _results.addAll(list);
        _hasMore = list.length == 24;
        _searched = true;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FanFinder')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _city,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_city_rounded),
                        labelText: 'Città',
                        helperText: 'Lascia vuoto per cercare ovunque',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _interest,
                      decoration: const InputDecoration(labelText: 'Interesse', prefixIcon: Icon(Icons.interests_rounded)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tutti')),
                        for (final i in kInterestOptions) DropdownMenuItem(value: i, child: Text(i)),
                      ],
                      onChanged: (v) => setState(() => _interest = v),
                    ),
                    const SizedBox(height: 12),
                    Text('Fascia d\'età: ${_age.start.round()} – ${_age.end.round() >= 60 ? '60+' : _age.end.round()}'),
                    RangeSlider(
                      values: _age,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      onChanged: (v) => setState(() => _age = v),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'friendship', label: Text('Amicizia'), icon: Icon(Icons.handshake_rounded)),
                        ButtonSegment(value: 'dating', label: Text('Dating'), icon: Icon(Icons.favorite_rounded)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() => _mode = s.first),
                    ),
                    if (_mode == 'dating')
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Il filtro dating mostra solo adulti verificati ed è disponibile solo se anche tu sei verificato.',
                          style: TextStyle(color: WgfColors.muted, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 14),
                    GradientButton(label: 'Cerca fan', icon: Icons.search_rounded, busy: _loading && _results.isEmpty, onPressed: _search),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: WgfColors.danger)),
              ),
            ),
          if (_searched && _results.isEmpty && !_loading && _error == null)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.person_search_rounded,
                title: 'Nessun fan trovato',
                message: 'Prova un\'altra città o togli qualche filtro.',
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => FadeSlideIn(index: i % 10, child: _MiniCard(p: _results[i])),
                childCount: _results.length,
              ),
            ),
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _search(more: true),
                  child: const Text('Carica altri'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.p});
  final ProfileCard p;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => showProfileSheet(context, p),
      child: Column(
        children: [
          UserAvatar(name: p.name, path: p.avatarPath, size: 74, ring: true),
          const SizedBox(height: 10),
          Text(
            p.age != null ? '${p.name}, ${p.age}' : p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(p.city, style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
          const Spacer(),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [for (final i in p.interests.take(2)) TagChip(i)],
          ),
        ],
      ),
    );
  }
}
