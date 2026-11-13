# Limiti dichiarati

Cose che il codice non può risolvere da solo, o che richiedono un servizio non gratuito. Nessuna di queste è simulata.

## Verifica dell'età adulta (dating)
I fornitori affidabili di verifica dell'età sono quasi sempre a pagamento. Il sistema è già pronto:
tabella `age_verifications`, stati, permessi (solo admin/service role scrivono l'esito), nessun documento salvato.
Opzioni gratuite possibili, da valutare con un legale: revisione manuale da parte di un admin con verifica a voce/video senza conservare copie; oppure un fornitore con piano gratuito limitato.
**Finché non si sceglie, il dating resta spento** (`app_config.dating_enabled = false`).

## Fascia 13–17
Modellata e testata nel database, ma **disattivata**. Prima di attivarla servono: moderazione umana attiva, valutazione d'impatto (DPIA), consenso dei genitori dove richiesto (in Italia sotto i 14 anni), revisione legale.

## Moderazione automatica delle immagini
I servizi automatici affidabili sono a pagamento. In v1 le immagini in chat restano `pending` e il destinatario non può vederle finché un moderatore non le approva (`admin_review_image`). Funziona, ma richiede persone.

## Notifiche push
Le notifiche vengono già create nel database (tabella `notifications`, rispettando le preferenze). L'invio push tramite Firebase Cloud Messaging richiede un progetto Firebase (gratuito) e una Edge Function: arriva in una fase successiva.

## Conformità legale (GDPR, DSA, tutela dei minori)
Il progetto include strumenti tecnici (export dati, cancellazione account, consensi separati, minimizzazione), ma **non è dichiarato conforme**. Prima del lancio servono: informativa privacy e termini scritti o rivisti da un professionista, registro dei trattamenti, DPIA, nomina dei responsabili del trattamento (Supabase, Google/Firebase).

## Limiti del piano Free di Supabase
Database 500 MB, storage 1 GB, progetti in pausa dopo 7 giorni di inattività. Adatti a test e primi utenti, non a una crescita internazionale.
