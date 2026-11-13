# Stato di avanzamento

Aggiornato: 13/11/2026

| Fase | Contenuto | Stato |
|------|-----------|-------|
| 1 | Architettura, repository, configurazione | ✅ Completata |
| 2 | Database, autenticazione lato server, sicurezza | ✅ Completata e **verificata** |
| 3 | Design system, animazioni, navigazione | ✅ Scritta – da compilare (vedi sotto) |
| 4 | Profili e registrazione | ✅ Scritta – da compilare |
| 5 | FanFinder, Discover (swipe), Match, Dating con verifica | ✅ Backend verificato · app scritta |
| 6 | Chat in tempo reale, community, gruppi, sondaggi, fan art | ✅ Backend verificato · app scritta |
| 7 | Eventi, Non sei solo | ✅ Backend verificato · app scritta |
| 8 | Pagina THE CREATOR – SENTINEL | ✅ Backend verificato · app scritta |
| 9 | Pannello amministrativo web | ✅ Scritto, sintassi verificata, schermata di accesso controllata |
| 10 | Test, ottimizzazione, build APK | 🟡 Test DB eseguiti; build APK da fare sul tuo computer |

## Verificato davvero in questo ambiente

- **Database**: 5 migrazioni applicate su PostgreSQL 16.15, **167 test di sicurezza superati** eseguendo le richieste come farebbe l'app (ruoli `anon` e `authenticated`): età, separazione minori/adulti, dating solo tra verificati, chat, blocchi, sospensioni, antispam, limiti di frequenza, segnalazioni, anonimato, eventi, moderazione immagini, poteri e registro admin, Sentinel, export e cancellazione dati.
- I test hanno trovato e permesso di correggere 1 errore reale (il rifiuto di un'immagine in chat violava un vincolo del database).
- **Collegamento app ↔ database**: tutte le 24 chiamate RPC dell'app controllate contro le funzioni reali del database (nomi e parametri).
- **Codice Flutter**: controllo strutturale automatico su 42 file (parentesi, import, classi e provider referenziati) senza errori.
- **Pannello admin**: JavaScript validato con Node, pagina di accesso renderizzata in Chrome.
- **Logo e icona**: SVG originali convertiti in PNG 1024×1024.

## NON ancora verificato

- **Compilazione Flutter**: il Flutter SDK non è disponibile qui. Va eseguito sul tuo computer:
  `flutter pub get && flutter analyze && flutter test` (lo fa anche GitHub Actions a ogni push).
  È possibile che servano piccole correzioni (versioni dei pacchetti o API cambiate).
- **Migrazioni 0004–0005 su Supabase reale**: le parti di Storage e Realtime funzionano solo lì.
- **Notifiche push (FCM)**: le notifiche funzionano dentro l'app in tempo reale; le push a telefono chiuso richiedono un progetto Firebase e una Edge Function (prossimo passo).
- **APK**: da generare con `flutter build apk` (guida in `PUBBLICAZIONE_ANDROID.md`).

## Scelte da sapere

- **Animazioni**: realizzate con il motore di Flutter (CustomPainter e controller), non con Rive. Rive richiede file `.riv` disegnati nel suo editor; quelle di Flutter sono più leggere e non hanno bisogno di file esterni. Si possono aggiungere animazioni Rive in futuro.
- **WGF**: l'app ha sezioni, hashtag, gruppi e campi profilo dedicati ai WGF (personaggi preferiti, feed #WGF, gruppi WGF), ma **nessun logo, foto o contenuto ufficiale**: servirebbe l'autorizzazione dei titolari. Il ritratto di Sentinel si aggiunge mettendo il file `mobile/assets/images/sentinel_portrait.png`.
