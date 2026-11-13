import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

/// true se l'utente ha completato l'onboarding (esiste la riga in profiles).
final hasProfileProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;
  if (user == null) return false;
  final row = await client.from('profiles').select('id').eq('id', user.id).maybeSingle();
  return row != null;
});

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Future<void> signUp(String email, String password) =>
      _client.auth.signUp(email: email.trim(), password: password);

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _client.auth.signOut();

  /// Chiama la RPC lato server: l'età e la fascia sono calcolate dal database.
  Future<Map<String, dynamic>> completeOnboarding({
    required String username,
    required DateTime birthDate,
    required String country,
    required String city,
    required List<String> interests,
    required List<String> friendshipPreferences,
    required bool acceptTerms,
    required bool acceptPrivacy,
  }) async {
    final res = await _client.rpc('complete_onboarding', params: {
      'p_username': username,
      'p_birth_date': birthDate.toIso8601String().substring(0, 10),
      'p_country': country,
      'p_city': city,
      'p_interests': interests,
      'p_friendship_preferences': friendshipPreferences,
      'p_accept_terms': acceptTerms,
      'p_accept_privacy': acceptPrivacy,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}

/// Traduce gli errori del server in messaggi comprensibili.
String friendlyError(Object e) {
  final msg = e is PostgrestException ? e.message : e is AuthException ? e.message : '$e';
  if (msg.contains('age_not_allowed')) {
    return 'Al momento WGF CONNECT è disponibile solo per utenti maggiorenni.';
  }
  if (msg.contains('profiles_username_key')) return 'Username già in uso.';
  if (msg.contains('profiles_username_check')) {
    return 'Username: 3–20 caratteri, solo lettere minuscole, numeri e _.';
  }
  if (msg.contains('consent_required')) return 'Devi accettare termini e informativa privacy.';
  if (msg.contains('rate_limited')) return 'Troppe richieste, riprova tra poco.';
  if (msg.contains('Invalid login credentials')) return 'Email o password non corrette.';
  if (msg.contains('Email not confirmed')) return 'Conferma prima la tua email.';
  return 'Si è verificato un errore. Riprova.';
}
