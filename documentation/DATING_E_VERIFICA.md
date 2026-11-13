# Dating legale: come funziona in WGF CONNECT

Obiettivo: dating **solo tra adulti verificati**, senza conservare documenti e con strumenti gratuiti.

## Regole tecniche (già attive e testate nel database)
1. Il dating è spento finché un admin non lo accende (`dating_enabled`, Pannello → Configurazione). Ogni cambio viene registrato.
2. Un utente può vedere, mettere like o fare match in modalità dating **solo se entrambi** sono adulti (`age_band = adult`) **e** hanno `age_verifications.status = 'verified'`.
3. La fascia d'età è calcolata dal server dalla data di nascita; il client non può modificarla.
4. Minori e adulti non possono mai vedersi né scriversi, nemmeno in modalità amicizia.
5. L'esito della verifica lo può scrivere solo un admin, e solo su profili adulti.

## Procedura di verifica manuale (gratuita)
1. L'utente tocca **Verifica la tua età** e accetta le regole: nasce una richiesta "in attesa".
2. L'admin la vede in **Pannello → Verifiche età** e contatta l'utente (chat o email dell'account).
3. Breve videochiamata: l'utente mostra un documento **senza che venga registrato, fotografato o copiato**. L'admin controlla solo la data di nascita e che la persona corrisponda.
4. L'admin salva l'esito con una nota sulla procedura (es. "Videochiamata 13/11, nessuna copia"). Nel database restano solo: esito, metodo, data, nota nel registro.

## Cosa fare prima del lancio (da verificare con un legale)
- Valutare se la procedura manuale è proporzionata per il numero di utenti previsto.
- Inserire la procedura nell'informativa privacy (già prevista nella bozza).
- Formare chi fa le verifiche e definire chi può farle (solo ruolo admin).
- Valutare in futuro un fornitore di verifica dell'età con piano gratuito o a basso costo: il database supporta già `method = 'provider'` e `provider_reference`.
