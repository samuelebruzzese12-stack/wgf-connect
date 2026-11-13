import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/authentication/data/auth_repository.dart';

/// Navigazione principale. Le sezioni delle fasi successive mostrano
/// esplicitamente che sono in sviluppo: nessun pulsante finto.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _sections = [
    (Icons.dynamic_feed_rounded, 'Community', 'Fase 6'),
    (Icons.style_rounded, 'Discover', 'Fase 5'),
    (Icons.chat_bubble_rounded, 'Chat', 'Fase 6'),
    (Icons.event_rounded, 'Eventi', 'Fase 7'),
    (Icons.person_rounded, 'Profilo', 'Fase 4'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = _sections[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.$2),
        actions: [
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.$1, size: 56, color: WgfColors.electricViolet),
              const SizedBox(height: 16),
              Text('${s.$2} – in sviluppo (${s.$3})', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Il backend di questa sezione è già pronto e testato; l\'interfaccia arriva nella fase indicata.',
                textAlign: TextAlign.center,
                style: TextStyle(color: WgfColors.muted),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final x in _sections) NavigationDestination(icon: Icon(x.$1), label: x.$2),
        ],
      ),
    );
  }
}
