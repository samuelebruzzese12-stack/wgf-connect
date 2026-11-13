# Installazione e configurazione

Tutto con strumenti gratuiti.

## 1. Strumenti sul computer

- Git, Visual Studio Code
- Flutter SDK (canale stable) – include Dart. Verifica con `flutter doctor`.
- Android Studio solo per Android SDK ed emulatore (oppure un telefono Android con debug USB).
- Supabase CLI (opzionale ma consigliato): https://supabase.com/docs/guides/cli
- PostgreSQL 16 (opzionale, solo per eseguire i test del database in locale).

## 2. Progetto Supabase (piano Free)

1. Crea un progetto su https://supabase.com, regione **EU (Frankfurt)** per i dati europei.
2. **Authentication → Providers → Email**: attiva "Confirm email" (verifica email obbligatoria).
3. **Authentication → URL Configuration**: imposta il redirect per il recupero password dell'app.
4. Applica le migrazioni, in ordine:
   - con la CLI: copia `backend/supabase/migrations/` nella cartella `supabase/migrations` di un progetto collegato con `supabase link`, poi `supabase db push`;
   - oppure incolla i file uno alla volta nello **SQL Editor**.
5. **Non** applicare `backend/supabase/tests/00_supabase_shim.sql` su Supabase: serve solo ai test locali.
6. **Non** eseguire il seed in produzione (contiene solo utenti fittizi `test_*`).
7. Verifica che in **API Settings → Exposed schemas** ci siano solo `public` e `graphql_public`. Lo schema `app_private` **non deve essere esposto**.

### Nominare il fondatore

Dopo esserti registrato nell'app, nello SQL Editor:

```sql
update public.profiles set role = 'creator' where username = '<il tuo username>';
-- per avere anche i permessi di amministratore usa 'admin'
```

(Lo SQL Editor gira come proprietario del database, quindi il trigger di protezione lo consente.)

## 3. App Flutter

```bash
cd mobile
flutter create --platforms=android --org it.wgfconnect .   # solo la prima volta
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=SUPABASE_URL=https://<progetto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

La **anon key** è pubblica per design (la protezione la garantiscono le policy RLS). La **service_role key non va mai** messa nell'app né nel repository.

## 4. Test del database in locale

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=... ./scripts/test_db.sh
```

Lo script crea un database `wgf_test` pulito, applica shim + migrazioni + seed ed esegue tutti i test. Gli stessi test girano automaticamente su GitHub Actions a ogni push.
