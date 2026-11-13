# Stato di avanzamento

Aggiornato: 13/11/2026

| Fase | Contenuto | Stato |
|------|-----------|-------|
| 1 | Architettura, repository, configurazione | ✅ Completata |
| 2 | Database, autenticazione lato server, sicurezza | ✅ Completata e **verificata** (130 test superati) |
| 3 | Design system e navigazione | 🟡 Iniziata: tema, colori, router, barra di navigazione |
| 4 | Profili e registrazione | 🟡 Iniziata: login, registrazione, recupero password, onboarding |
| 5–10 | FanFinder/Discover/Match UI, chat e community UI, eventi, Non sei solo, Sentinel, admin, build APK | ⏳ Da fare (il backend di tutte queste sezioni è già pronto) |

## Cosa è stato verificato davvero

- Le 4 migrazioni SQL si applicano senza errori su **PostgreSQL 16.15**.
- `scripts/test_db.sh` esegue **130 test di sicurezza, tutti superati**, come richieste API reali (ruoli `anon` e `authenticated`):
  utente non autenticato, registrazione e controllo età (under 13, 13–17, 18+), privacy del profilo,
  separazione per fasce d'età, match e dating, chat, blocco, utente sospeso, community, antispam,
  rate limit, segnalazioni, anonimato in "Non sei solo", eventi, poteri amministrativi e registro accessi,
  pagina Sentinel, export dati e cancellazione account.

## Cosa NON è stato ancora verificato

- **Codice Flutter**: scritto ma **non compilato** in questo ambiente (Flutter SDK non disponibile).
  Va verificato con `flutter analyze` e `flutter test` (lo fa anche la CI su GitHub).
  Le versioni dei pacchetti in `pubspec.yaml` potrebbero richiedere `flutter pub upgrade`.
- **Migrazione 0004 (Storage e Realtime)**: sul PostgreSQL locale viene saltata perché gli schemi di Supabase non esistono; va verificata sul progetto Supabase reale.
- Lo shim di Supabase Auth usato nei test è minimo: replica `auth.uid()`, i ruoli e i permessi predefiniti, non tutto Supabase.

## File completati

```
backend/supabase/migrations/20261113000001_schema.sql            31 tabelle, vincoli, indici
backend/supabase/migrations/20261113000002_functions.sql         helper, trigger, 26 RPC (utente + admin)
backend/supabase/migrations/20261113000003_rls.sql               RLS forzata su tutte le tabelle, policy
backend/supabase/migrations/20261113000004_storage_realtime.sql  bucket privati, policy storage, realtime
backend/supabase/seed/seed_test_data.sql                         utenti fittizi test_*
backend/supabase/tests/00_supabase_shim.sql                      shim per test locali
backend/supabase/tests/10_security_tests.sql                     130 test
mobile/lib/…                                                     config, tema, router, auth, onboarding, home
mobile/test/friendly_error_test.dart
scripts/test_db.sh, .github/workflows/ci.yml
documentation/ARCHITECTURE.md, INSTALLAZIONE.md, LIMITI.md, STATO.md
```

## Prossimo passo

Fase 3 completa (splash animata, componenti riutilizzabili, logo e icona originali) e Fase 4 (schermata profilo e modifica, foto profilo, impostazioni privacy).
