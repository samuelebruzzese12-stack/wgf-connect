import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/visuals.dart';
import '../data/repositories/repositories.dart';
import '../features/chat/conversations_tab.dart';
import '../features/community/community_tab.dart';
import '../features/community/compose_post_screen.dart';
import '../features/discover/discover_tab.dart';
import '../features/events/events_tab.dart';
import '../features/profile/my_profile_tab.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _titles = ['Community', 'Discover', 'Chat', 'Eventi', 'Profilo'];

  void _openExplore() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) {
        Widget tile(IconData icon, String title, String sub, String route) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: WgfColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub),
              onTap: () {
                Navigator.pop(ctx);
                context.push(route);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(Icons.travel_explore_rounded, 'FanFinder', 'Cerca fan per città e interessi', '/fanfinder'),
              tile(Icons.groups_rounded, 'Gruppi', 'WGF, gaming, fan art e città', '/groups'),
              tile(Icons.favorite_rounded, 'Non sei solo', 'Ascolto e incoraggiamento', '/support'),
              tile(Icons.auto_awesome_rounded, 'The Creator – SENTINEL', 'Il fondatore e il progetto', '/sentinel'),
              tile(Icons.settings_rounded, 'Impostazioni', 'Privacy, notifiche, account', '/settings'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget? _fab() {
    switch (_index) {
      case 0:
        return FloatingActionButton(
          onPressed: () => context.push('/compose', extra: const ComposeOptions()),
          child: const Icon(Icons.add_rounded),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => context.push('/events/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Proponi evento'),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotif = ref.watch(unreadNotificationsProvider);
    final unreadMsg = ref.watch(unreadMessagesProvider);

    final tabs = <Widget>[
      const CommunityTab(),
      const DiscoverTab(),
      const ConversationsTab(),
      const EventsTab(),
      const MyProfileTab(),
    ];

    return AuroraBackground(
      intensity: 0.55,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            children: [
              const Hero(tag: 'wgf-logo', child: WgfLogo(size: 30, glow: 0.5)),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(_titles[_index], key: ValueKey(_index)),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notifiche',
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unreadNotif > 0,
                label: Text(unreadNotif > 99 ? '99+' : '$unreadNotif'),
                child: const Icon(Icons.notifications_rounded),
              ),
            ),
            IconButton(tooltip: 'Esplora', onPressed: _openExplore, icon: const Icon(Icons.apps_rounded)),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < tabs.length; i++) _visited.contains(i) ? tabs[i] : const SizedBox.shrink(),
          ],
        ),
        floatingActionButton: _fab(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.dynamic_feed_rounded), label: 'Community'),
            const NavigationDestination(icon: Icon(Icons.style_rounded), label: 'Discover'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadMsg > 0,
                label: Text('$unreadMsg'),
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Chat',
            ),
            const NavigationDestination(icon: Icon(Icons.event_rounded), label: 'Eventi'),
            const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profilo'),
          ],
        ),
      ),
    );
  }
}
