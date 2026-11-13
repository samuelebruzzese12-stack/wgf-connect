import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/register_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../app/home_shell.dart';

/// Notifica go_router quando cambiano sessione o stato del profilo.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(hasProfileProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final client = ref.read(supabaseProvider);
      final loggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (!loggedIn) return onAuthPage ? null : '/login';

      final hasProfile = ref.read(hasProfileProvider);
      if (hasProfile.isLoading) return null;
      if (hasProfile.valueOrNull == false) return loc == '/onboarding' ? null : '/onboarding';
      if (onAuthPage || loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});
