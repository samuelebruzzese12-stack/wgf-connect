import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/home_shell.dart';
import '../../data/models/models.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/register_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/community/compose_post_screen.dart';
import '../../features/community/post_detail_screen.dart';
import '../../features/creator/sentinel_screen.dart';
import '../../features/dating/age_verification_screen.dart';
import '../../features/events/create_event_screen.dart';
import '../../features/events/event_detail_screen.dart';
import '../../features/fanfinder/fanfinder_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/wgf/wgf_quiz_screen.dart';
import '../../features/wgf/wgf_zone_screen.dart';
import '../../features/events/events_tab.dart';

/// Notifica go_router quando cambiano sessione o stato del profilo.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(hasProfileProvider, (_, __) => notifyListeners());
  }
}

/// Transizione "cinematografica": dissolvenza + leggero scorrimento e zoom.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: child),
          ),
        );
      },
    );

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash' || loc.startsWith('/legal')) return null;

      final loggedIn = ref.read(supabaseProvider).auth.currentSession != null;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (!loggedIn) return onAuthPage ? null : '/login';

      final hasProfile = ref.read(hasProfileProvider);
      if (hasProfile.isLoading && !hasProfile.hasValue) return null;
      if (hasProfile.valueOrNull == false) return loc == '/onboarding' ? null : '/onboarding';
      if (onAuthPage || loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (c, s) => _page(s, const SplashScreen())),
      GoRoute(path: '/login', pageBuilder: (c, s) => _page(s, const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (c, s) => _page(s, const RegisterScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
      GoRoute(path: '/home', pageBuilder: (c, s) => _page(s, const HomeShell())),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (c, s) => _page(s, ChatScreen(conversationId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/post/:id',
        pageBuilder: (c, s) => _page(s, PostDetailScreen(postId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/compose',
        pageBuilder: (c, s) => _page(s, ComposePostScreen(options: (s.extra as ComposeOptions?) ?? const ComposeOptions())),
      ),
      GoRoute(
        path: '/user/:id',
        pageBuilder: (c, s) => _page(s, UserProfileScreen(userId: s.pathParameters['id']!)),
      ),
      GoRoute(path: '/profile/edit', pageBuilder: (c, s) => _page(s, const EditProfileScreen())),
      GoRoute(path: '/settings', pageBuilder: (c, s) => _page(s, const SettingsScreen())),
      GoRoute(path: '/settings/blocked', pageBuilder: (c, s) => _page(s, const BlockedUsersScreen())),
      GoRoute(path: '/notifications', pageBuilder: (c, s) => _page(s, const NotificationsScreen())),
      GoRoute(path: '/fanfinder', pageBuilder: (c, s) => _page(s, const FanFinderScreen())),
      GoRoute(path: '/support', pageBuilder: (c, s) => _page(s, const SupportScreen())),
      GoRoute(path: '/wgf', pageBuilder: (c, s) => _page(s, const WgfZoneScreen())),
      GoRoute(path: '/wgf/quiz', pageBuilder: (c, s) => _page(s, const WgfQuizScreen())),
      GoRoute(path: '/events', pageBuilder: (c, s) => _page(s, const EventsScreen())),
      GoRoute(path: '/sentinel', pageBuilder: (c, s) => _page(s, const SentinelScreen())),
      GoRoute(path: '/verify', pageBuilder: (c, s) => _page(s, const AgeVerificationScreen())),
      GoRoute(path: '/events/new', pageBuilder: (c, s) => _page(s, const CreateEventScreen())),
      GoRoute(
        path: '/events/:id',
        pageBuilder: (c, s) => _page(s, EventDetailScreen(eventId: s.pathParameters['id']!, initial: s.extra as EventItem?)),
      ),
      GoRoute(path: '/groups', pageBuilder: (c, s) => _page(s, const GroupsScreen())),
      GoRoute(
        path: '/groups/:id',
        pageBuilder: (c, s) => _page(s, GroupDetailScreen(groupId: s.pathParameters['id']!, initial: s.extra as GroupItem?)),
      ),
      GoRoute(
        path: '/legal/:doc',
        pageBuilder: (c, s) => _page(s, LegalScreen(doc: s.pathParameters['doc']!)),
      ),
    ],
  );
});
