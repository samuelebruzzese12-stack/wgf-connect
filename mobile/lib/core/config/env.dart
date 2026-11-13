/// Configurazione passata al build con --dart-define.
/// Nessuna chiave è scritta nel codice sorgente.
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<progetto>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon key dal pannello Supabase>
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Configurazione mancante: avvia con --dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_ANON_KEY=... (vedi documentation/INSTALLAZIONE.md)',
      );
    }
  }
}
