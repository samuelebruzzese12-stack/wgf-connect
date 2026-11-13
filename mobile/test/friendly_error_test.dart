import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wgf_connect/features/authentication/data/auth_repository.dart';

void main() {
  group('friendlyError', () {
    test('età non consentita → messaggio neutro solo maggiorenni', () {
      final e = PostgrestException(message: 'age_not_allowed');
      expect(friendlyError(e), contains('solo per utenti maggiorenni'));
    });

    test('username duplicato', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint "profiles_username_key"',
      );
      expect(friendlyError(e), 'Username già in uso.');
    });

    test('credenziali errate', () {
      expect(friendlyError(AuthException('Invalid login credentials')),
          'Email o password non corrette.');
    });

    test('errore sconosciuto non espone dettagli tecnici', () {
      expect(friendlyError(Exception('stack trace interno')), 'Si è verificato un errore. Riprova.');
    });
  });
}
