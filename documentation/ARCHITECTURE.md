# WGF CONNECT – Architettura (v1.0)

> Progetto indipendente realizzato da un fan. **Non** affiliato, approvato o sponsorizzato dai WGF.
> Nessun logo, immagine o contenuto protetto di terzi è incluso nel repository.

## 1. Decisioni chiave

| # | Decisione | Motivo |
|---|-----------|--------|
| D1 | **La prima versione pubblica è riservata ai maggiorenni (18+).** La fascia 13–17 è già modellata nel database ma disattivata dal flag `app_config.minors_registration_enabled = false`. | Il prompt lo richiede finché non sono garantite tutte le protezioni per i minori (moderazione umana attiva, verifica dell'età, valutazione legale). |
| D2 | La data di nascita sta in una tabella separata (`profiles_private`) leggibile solo dal proprietario. Il profilo pubblico espone solo l'età calcolata (se l'utente lo consente) e la fascia (`teen`/`adult`). | Minimizzazione dei dati, mai la data completa in pubblico. |
| D3 | La fascia d'età (`age_band`) è calcolata **dal server** nell'onboarding e non è modificabile dal client (trigger di protezione colonne). | Il client non può dichiararsi adulto modificando le richieste API. |
| D4 | Il dating richiede `age_verifications.status = 'verified'` per **entrambi** gli utenti e il flag `dating_enabled`. Lo stato di verifica può essere scritto solo da service role o admin. Nessun documento d'identità viene salvato: solo esito, metodo e riferimento opaco del fornitore. | Il prompt vieta di basarsi solo sull'età dichiarata e di conservare documenti. |
| D5 | Ogni interazione tra due utenti (like, amicizia, messaggio, iscrizione a gruppi della stessa fascia) passa per `can_interact(a, b)`: stessa fascia d'età, nessun blocco reciproco, entrambi attivi. | Separazione a livello di database, non solo di interfaccia. |
| D6 | Logica sensibile (like→match, onboarding, cancellazione account, export dati) è in **funzioni PostgreSQL** `SECURITY DEFINER` con `search_path` fissato, chiamate via RPC. Le tabelle collegate non hanno policy di INSERT diretto. | Un solo punto di controllo, impossibile aggirarlo dal client. |
| D7 | Gli admin **non** leggono i messaggi privati via RLS. Per accedere a un contenuto segnalato si usa `admin_read_reported_message(report_id, motivo)`, che registra l'accesso in `admin_access_log`. | Il prompt vieta l'accesso indiscriminato ai dati privati. |
| D8 | Solo servizi gratuiti: Supabase (piano Free), FCM, GitHub Actions, Cloudflare Pages. | Vincolo del progetto. |

## 2. Componenti

```
┌──────────────────────┐      ┌───────────────────────────────┐
│ App Flutter (Android)│─────▶│ Supabase                      │
│ Material 3, go_router│ HTTPS│  • Auth (email+password)      │
│ Riverpod, Rive       │◀────▶│  • PostgREST + RLS            │
└──────────────────────┘ WSS  │  • Realtime (messages, notif.)│
                              │  • Storage (avatar, immagini) │
┌──────────────────────┐      │  • Edge Functions (push FCM,  │
│ Admin web (static)   │─────▶│    moderazione immagini)      │
│ Cloudflare Pages     │      └───────────────────────────────┘
└──────────────────────┘                    │
                                            ▼
                                 Firebase Cloud Messaging
```

### App mobile (`mobile/`)
- **Architettura a feature**: ogni cartella in `lib/features/<feature>/` contiene `presentation/` (schermate, widget), `application/` (provider/controller) e usa i repository di `lib/data/`.
- **Stato**: Riverpod. **Routing**: go_router con redirect basato sullo stato di autenticazione/onboarding.
- **Configurazione**: URL e anon key di Supabase passati con `--dart-define` (mai nel codice). La anon key è pubblica per design; la sicurezza è garantita da RLS.

### Backend (`backend/supabase/`)
- `migrations/` – schema, funzioni, RLS, storage, realtime (in ordine numerico).
- `seed/` – dati dimostrativi **fittizi**, chiaramente marcati come test.
- `tests/` – test di sicurezza eseguibili su un PostgreSQL 16 locale con uno shim di Supabase Auth (`tests/00_supabase_shim.sql`).
- `functions/` – Edge Functions (Deno) – fasi successive.

### Admin (`admin/`)
Dashboard web statica che usa Supabase Auth; l'accesso è consentito solo se `profiles.role in ('admin','moderator','creator')`, verificato **lato database** da ogni RPC amministrativa.

## 3. Modello dei dati (sintesi)

- **Identità**: `profiles` (pubblico), `profiles_private` (data di nascita), `user_preferences`, `user_consents`, `age_verifications`.
- **Relazioni**: `friendships`, `likes`, `matches`, `blocked_users`.
- **Messaggistica**: `conversations`, `conversation_participants`, `messages`.
- **Community**: `posts`, `comments`, `reactions`, `groups`, `group_members`, `support_posts`, `support_replies`.
- **Eventi**: `events`, `event_participants`.
- **Fondatore**: `creator_updates`, `creator_ideas`, `creator_followers`.
- **Sicurezza**: `reports`, `moderation_actions`, `admin_access_log`, `rate_limit_events`, `app_config`.

Ogni contenuto generato dagli utenti ha una colonna `audience_band` uguale alla fascia dell'autore: un utente vede solo contenuti della propria fascia.

## 4. Flussi principali

**Registrazione**: `auth.signUp` → verifica email → `complete_onboarding()` RPC. La funzione calcola l'età: < 13 → errore e nessun dato salvato; 13–17 → errore se i minori sono disattivati; ≥ 18 → crea profilo `adult`, dati privati e consensi.

**Like/Match**: `like_user(target, mode, super)` → controlli (`can_interact`, dating verificato) → se il like è reciproco crea `matches` + `conversations` + partecipanti + notifiche, tutto in una transazione.

**Chat**: insert diretto su `messages` consentito da RLS solo se il mittente partecipa alla conversazione, la conversazione è attiva, i due utenti possono ancora interagire e il rate limit non è superato.

## 5. Limiti dichiarati

- **Verifica dell'età adulta**: procedura manuale gratuita (richiesta in app + verifica admin senza copie di documenti). Il dating si attiva dal pannello. Vedi `documentation/DATING_E_VERIFICA.md`.
- **Moderazione automatica delle immagini**: i servizi affidabili sono a pagamento. In v1 le immagini in chat partono come `pending` e diventano visibili dopo l'approvazione di un moderatore.
- **Conformità legale**: la documentazione privacy è una bozza tecnica. Serve la revisione di un professionista prima del lancio.
