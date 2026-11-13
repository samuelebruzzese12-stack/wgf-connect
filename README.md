# WGF CONNECT

Piattaforma social per la community dei fan WGF: amicizie, FanFinder, Discover, chat, community, eventi, sezione "Non sei solo" e la pagina del fondatore **SENTINEL**.

> **Progetto indipendente realizzato da un fan.** Non è affiliato, approvato o sponsorizzato dai WGF. Il repository non contiene loghi, immagini o contenuti protetti di terzi.

## Stato

Fasi 1–2 completate e verificate: architettura, repository, database, autenticazione lato server e sicurezza (130 test superati su PostgreSQL 16).
Dettagli su cosa è fatto, verificato e ancora da fare: [`documentation/STATO.md`](documentation/STATO.md).

## Struttura

```
mobile/            App Flutter (Android)
backend/supabase/  migrations/ · seed/ · tests/ · functions/
admin/             Pannello amministrativo web (Fase 9)
documentation/     Architettura, installazione, limiti, stato
scripts/           test_db.sh – esegue migrazioni + test di sicurezza
.github/workflows/ CI: test database + flutter analyze/test
```

## Avvio rapido

1. **Database** – crea un progetto gratuito su Supabase e applica le migrazioni in `backend/supabase/migrations/` (in ordine). Guida: [`documentation/INSTALLAZIONE.md`](documentation/INSTALLAZIONE.md).
2. **Test locali del database** – con PostgreSQL 16:
   ```bash
   PGHOST=localhost PGUSER=postgres ./scripts/test_db.sh
   ```
3. **App** – in `mobile/`:
   ```bash
   flutter create --platforms=android --org it.wgfconnect .   # genera la cartella android/ la prima volta
   flutter pub get
   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```

## Principi di sicurezza

- Prima versione pubblica **solo 18+**; la fascia 13–17 è già separata nel database ma disattivata.
- Fascia d'età calcolata dal server, non modificabile dal client.
- Dating disattivato finché non c'è una procedura di verifica dell'età adulta; nessun documento d'identità salvato.
- Row Level Security su tutte le tabelle; azioni sensibili solo tramite funzioni del database.
- Gli amministratori non leggono le chat: accedono solo a contenuti segnalati, con motivazione registrata.

Documentazione completa: [`documentation/ARCHITECTURE.md`](documentation/ARCHITECTURE.md).
