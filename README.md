# WGF CONNECT

Piattaforma social per la community dei fan WGF: amicizie, FanFinder, Discover, chat, community, eventi, sezione "Non sei solo" e la pagina del fondatore **SENTINEL**.

> **Progetto indipendente realizzato da un fan.** Non è affiliato, approvato o sponsorizzato dai WGF. Il repository non contiene loghi, immagini o contenuti protetti di terzi.

## Stato

Tutte le sezioni sono implementate: backend verificato con **167 test di sicurezza superati** su PostgreSQL 16, app Flutter completa (da compilare con `flutter analyze`), pannello amministrativo web.
Dettagli su cosa è verificato e cosa no: [`documentation/STATO.md`](documentation/STATO.md).

**Nell'app**: splash animata · Discover con swipe fisico e animazione del match · FanFinder · Dating 18+ con verifica dell'età senza documenti · chat in tempo reale con stato di lettura · community con post, fan art, sondaggi, hashtag, condivisioni e feed #WGF · gruppi · WGF EVENTS moderati · Non sei solo con numeri di aiuto · pagina cinematografica THE CREATOR – SENTINEL · notifiche in tempo reale · profilo, impostazioni privacy, export e cancellazione dati.

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
- Dating solo tra adulti verificati con procedura manuale gratuita; nessun documento d'identità salvato ([`DATING_E_VERIFICA.md`](documentation/DATING_E_VERIFICA.md)).
- Row Level Security su tutte le tabelle; azioni sensibili solo tramite funzioni del database.
- Gli amministratori non leggono le chat: accedono solo a contenuti segnalati, con motivazione registrata.

Documentazione: [architettura](documentation/ARCHITECTURE.md) · [installazione](documentation/INSTALLAZIONE.md) · [build e Play Store](documentation/PUBBLICAZIONE_ANDROID.md) · [limiti](documentation/LIMITI.md) · [bozze legali](documentation/legal/).
