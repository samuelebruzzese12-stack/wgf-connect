# Provare WGF CONNECT usando solo il telefono

Tutto gratis, tutto dal browser del telefono (Chrome). Tempo: circa 20 minuti.

## 1. Database (Supabase)
1. Vai su **supabase.com** → *Start your project* → accedi con GitHub.
2. *New project* → nome `wgf-connect`, scegli una password per il database, regione **Central EU (Frankfurt)** → *Create*.
3. Menu **SQL Editor** → *New query* → incolla **tutto** il contenuto di `backend/supabase/SETUP_COMPLETO.sql` → **Run**.
   Deve comparire "Success". (Non eseguire il seed di test.)
4. Menu **Authentication → Sign In / Providers → Email**: lascia attivo "Confirm email".
5. Menu **Project Settings → API** (o *Data API*): copia **Project URL** e la chiave **anon public**.

## 2. Costruire l'APK (GitHub Actions)
1. Nel repository GitHub del progetto: **Settings → Secrets and variables → Actions → New repository secret**:
   - `SUPABASE_URL` = il Project URL
   - `SUPABASE_ANON_KEY` = la chiave anon public
2. Scheda **Actions → Build APK → Run workflow** (oppure parte da sola dopo ogni modifica).
3. Aspetta il segno verde ✓ (circa 8–12 minuti). Se diventa rosso ✗, apri il passaggio fallito e manda lo screenshot.
4. Apri l'esecuzione → in fondo, sezione **Artifacts** → scarica **WGF-CONNECT-APK** (è uno zip).

## 3. Installare
1. Apri lo zip con l'app *File* del telefono ed estrai `WGF-CONNECT.apk`
   (se il telefono è molto vecchio usa `WGF-CONNECT-telefoni-vecchi.apk`).
2. Tocca l'APK → consenti "Installa app sconosciute" per il browser o l'app File → *Installa*.
3. Apri WGF CONNECT, registrati, conferma l'email e completa il profilo.

## 4. Diventare il fondatore SENTINEL
Dopo la registrazione, in Supabase → SQL Editor:
```sql
update public.profiles set role = 'admin' where username = 'IL_TUO_USERNAME';
```
(`admin` include i poteri da fondatore: pubblicare come Sentinel e usare il pannello.)

## Per provare con altre persone
Il dating è spento finché non lo attivi; amicizie, chat, community ed eventi funzionano subito.
Fai registrare un amico maggiorenne, mettetevi like a vicenda in Discover → match → chat.
