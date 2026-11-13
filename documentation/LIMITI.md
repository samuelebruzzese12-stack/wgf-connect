# Limiti dichiarati

Cose che il codice non può risolvere da solo, o che richiedono un servizio non gratuito. Nessuna di queste è simulata.

## Verifica dell'età adulta (dating)
Implementata una procedura **manuale e gratuita** (vedi `DATING_E_VERIFICA.md`): richiesta in app, verifica da parte di un admin senza conservare documenti, salvataggio del solo esito. È adatta a pochi utenti; con numeri grandi servirà un fornitore specializzato. Il dating resta spento finché un admin non lo attiva dal pannello.

## Fascia 13–17
Modellata e testata nel database, ma **bloccata**: il database rifiuta di attivarla anche da parte di un admin. Prima di aprirla servono moderazione umana attiva, valutazione d'impatto (DPIA), consenso dei genitori dove richiesto (in Italia sotto i 14 anni) e revisione legale; poi va tolto il blocco in `admin_set_config`.

## Moderazione delle immagini in chat
I servizi automatici affidabili sono a pagamento. Le immagini in chat restano "in revisione" e il destinatario le vede solo dopo l'approvazione di un moderatore (Pannello → Immagini chat). Le immagini dei post sono visibili subito e moderate tramite segnalazioni.

## Notifiche push
Le notifiche arrivano in tempo reale con l'app aperta (badge e lista). Le push a telefono chiuso richiedono un progetto Firebase (gratuito) e una Edge Function: prossimo passo.

## File delle immagini rifiutate
Quando un'immagine viene rifiutata, il collegamento viene rimosso dal messaggio ma il file resta nello storage privato (non accessibile a nessun utente) fino alla cancellazione dell'account. Una pulizia automatica si può aggiungere con una Edge Function.

## Conformità legale (GDPR, DSA, Google Play)
Il progetto include strumenti tecnici (export dati, cancellazione account, consensi separati, minimizzazione, registro accessi) e **bozze** di informativa privacy, termini, linee guida e regole di sicurezza. **Non è dichiarato conforme**: prima del lancio serve la revisione di un professionista.

## Limiti del piano Free di Supabase
Database 500 MB, storage 1 GB, progetti in pausa dopo una settimana di inattività. Adatti a test e primi utenti.

## Pubblicazione su Google Play
Richiede un account sviluppatore con una quota una tantum. In alternativa l'APK si può distribuire direttamente.
