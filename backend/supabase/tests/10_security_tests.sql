-- =====================================================================
-- WGF CONNECT – Test di sicurezza del database
-- Simula: utente adulto, minorenne, bloccato, segnalato/sospeso,
-- amministratore, fondatore e utente non autenticato.
-- Ogni gruppo gira in una transazione con ROLLBACK.
-- Le richieste sono eseguite con il ruolo "authenticated"/"anon",
-- esattamente come farebbe PostgREST con richieste API manipolate.
-- =====================================================================
\set QUIET on
set client_min_messages = notice;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

create or replace function tests.login(p_uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
         json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
$$;

create or replace function tests.ok(p_label text, p_sql text) returns void language plpgsql as $$
begin
  execute p_sql;
  raise notice 'PASS  %', p_label;
exception when others then
  raise exception 'FAIL  % → errore inatteso: % (%)', p_label, sqlerrm, sqlstate;
end $$;

create or replace function tests.denied(p_label text, p_sql text) returns void language plpgsql as $$
declare v_failed boolean := false;
begin
  begin
    execute p_sql;
  exception when others then
    v_failed := true;
    raise notice 'PASS  % (bloccato: %)', p_label, left(sqlerrm, 70);
  end;
  if not v_failed then raise exception 'FAIL  % → l''operazione doveva essere bloccata', p_label; end if;
end $$;

create or replace function tests.eq(p_label text, p_sql text, p_expected text) returns void language plpgsql as $$
declare v text;
begin
  execute p_sql into v;
  if v is distinct from p_expected then
    raise exception 'FAIL  % → atteso "%", ottenuto "%"', p_label, p_expected, v;
  end if;
  raise notice 'PASS  %', p_label;
end $$;

grant execute on all functions in schema tests to anon, authenticated;

-- =====================================================================
\echo '--- 1. Utente non autenticato (anon) ---'
begin;
set local role anon;
select tests.eq('anon non vede profili', 'select count(*) from public.profiles', '0');
select tests.eq('anon non vede post', 'select count(*) from public.posts', '0');
select tests.denied('anon non può chiamare RPC like_user',
  $$select public.like_user('22222222-2222-2222-2222-222222222222')$$);
select tests.denied('anon non può completare onboarding',
  $$select public.complete_onboarding('test_x', date '2000-01-01', 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.denied('anon non può inserire post',
  $$insert into public.posts (author_id, body, audience_band) values ('11111111-1111-1111-1111-111111111111', 'x', 'adult')$$);
rollback;

-- =====================================================================
\echo '--- 2. Registrazione e controllo età ---'
begin;
select tests.login('88888888-8888-8888-8888-888888888888');
set local role authenticated;
select tests.denied('under 13 rifiutato',
  $$select public.complete_onboarding('test_bimbo', (current_date - interval '10 years')::date, 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.denied('13-17 rifiutato in v1 (solo 18+)',
  $$select public.complete_onboarding('test_teen', (current_date - interval '15 years')::date, 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.denied('senza consensi rifiutato',
  $$select public.complete_onboarding('test_nuovo', date '2000-01-01', 'IT', 'Roma', '{}', '{}', false, true)$$);
select tests.denied('username non valido rifiutato',
  $$select public.complete_onboarding('Bad Name!', date '2000-01-01', 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.denied('username duplicato rifiutato',
  $$select public.complete_onboarding('test_adulto_a', date '2000-01-01', 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.eq('nessun dato salvato dopo i rifiuti',
  $$select count(*) from public.profiles where id = '88888888-8888-8888-8888-888888888888'$$, '0');
select tests.eq('adulto registrato come adult',
  $$select public.complete_onboarding('test_nuovo', date '2000-01-01', 'it', 'Roma', '{gaming}', '{}', true, true) ->> 'age_band'$$, 'adult');
select tests.eq('consensi registrati', $$select count(*) from public.user_consents$$, '2');
select tests.denied('onboarding non ripetibile',
  $$select public.complete_onboarding('test_nuovo2', date '2000-01-01', 'IT', 'Roma', '{}', '{}', true, true)$$);
select tests.denied('il client non può auto-promuoversi admin',
  $$update public.profiles set role = 'admin' where id = auth.uid()$$);
select tests.denied('il client non può cambiare fascia d''età',
  $$update public.profiles set age_band = 'teen' where id = auth.uid()$$);
select tests.denied('il client non può cambiare il proprio status (es. annullare una sospensione)',
  $$update public.profiles set status = 'banned' where id = auth.uid()$$);
select tests.ok('il client può modificare la bio',
  $$update public.profiles set bio = 'ciao' where id = auth.uid()$$);
select tests.denied('nessun insert diretto in profiles',
  $$insert into public.profiles (id, username, country, city, age_band) values (gen_random_uuid(), 'test_hack', 'IT', 'Roma', 'adult')$$);
select tests.denied('nessuna auto-verifica età',
  $$insert into public.age_verifications (user_id, method, status) values (auth.uid(), 'other', 'verified')$$);
rollback;

-- =====================================================================
\echo '--- 3. Privacy del profilo ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.eq('data di nascita propria visibile', 'select count(*) from public.profiles_private', '1');
select tests.eq('data di nascita altrui MAI visibile',
  $$select count(*) from public.profiles_private where user_id <> auth.uid()$$, '0');
select tests.eq('get_profile mostra età ma non data di nascita',
  $$select (public.get_profile('22222222-2222-2222-2222-222222222222') ? 'birth_date')::text$$, 'false');
select tests.eq('get_profile include l''età',
  $$select (public.get_profile('22222222-2222-2222-2222-222222222222') ->> 'age') is not null$$, 'true');
select tests.eq('adulto non vede profili minorenni',
  $$select count(*) from public.profiles where age_band = 'teen'$$, '0');
select tests.eq('get_profile di un minore restituisce null',
  $$select public.get_profile('44444444-4444-4444-4444-444444444444') is null$$, 'true');
select tests.eq('utente sospeso non visibile',
  $$select count(*) from public.profiles where id = '77777777-7777-7777-7777-777777777777'$$, '0');
select tests.eq('preferenze altrui invisibili',
  $$select count(*) from public.user_preferences where user_id <> auth.uid()$$, '0');
rollback;

-- =====================================================================
\echo '--- 4. Separazione per fasce d''età ---'
begin;
select tests.login('44444444-4444-4444-4444-444444444444');
set local role authenticated;
select tests.eq('minore non vede profili adulti',
  $$select count(*) from public.profiles where age_band = 'adult'$$, '0');
select tests.eq('minore vede solo post teen',
  $$select string_agg(distinct audience_band, ',') from public.posts$$, 'teen');
select tests.denied('minore non può mettere like a un adulto',
  $$select public.like_user('11111111-1111-1111-1111-111111111111', 'friendship')$$);
select tests.denied('minore non può chiedere amicizia a un adulto',
  $$select public.send_friend_request('11111111-1111-1111-1111-111111111111')$$);
select tests.denied('minore non accede al dating',
  $$select public.discover_profiles('dating')$$);
select tests.denied('minore non può fare dating con un altro minore',
  $$select public.like_user('99999999-9999-9999-9999-999999999999', 'dating')$$);
select tests.eq('discover del minore restituisce solo minori',
  $$select count(*) from public.discover_profiles('friendship') d where d ->> 'id' <> '99999999-9999-9999-9999-999999999999'$$, '0');
select tests.denied('minore non può iscriversi a un gruppo adulti',
  $$insert into public.group_members (group_id, user_id) values ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid())$$);
select tests.denied('minore non può commentare post adulti',
  $$insert into public.comments (post_id, author_id, body) values ('bbbbbbbb-0000-0000-0000-000000000001', auth.uid(), 'ciao')$$);
select tests.denied('minore non può iscriversi a eventi adulti',
  $$insert into public.event_participants (event_id, user_id) values ('cccccccc-0000-0000-0000-000000000001', auth.uid())$$);
select tests.ok('post di un minore forzato a fascia teen anche se il client dichiara adult',
  $$insert into public.posts (id, author_id, body, audience_band) values ('bbbbbbbb-0000-0000-0000-0000000000ff', auth.uid(), 'ciao', 'adult')$$);
reset role;
select tests.eq('verifica: il post è finito nella fascia teen',
  $$select audience_band from public.posts where id = 'bbbbbbbb-0000-0000-0000-0000000000ff'$$, 'teen');
rollback;

begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.eq('adulto vede solo post adult',
  $$select string_agg(distinct audience_band, ',') from public.posts$$, 'adult');
select tests.denied('adulto non può mettere like a un minore (richiesta API manipolata)',
  $$select public.like_user('44444444-4444-4444-4444-444444444444', 'friendship')$$);
select tests.denied('adulto non può inserire un like diretto in tabella',
  $$insert into public.likes (liker_id, likee_id, mode) values (auth.uid(), '44444444-4444-4444-4444-444444444444', 'friendship')$$);
select tests.denied('adulto non può creare un match diretto',
  $$insert into public.matches (user_a, user_b, mode) values ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 'friendship')$$);
select tests.denied('adulto non può creare conversazioni dirette',
  $$insert into public.conversations (kind, match_id) values ('match', gen_random_uuid())$$);
select tests.eq('discover dell''adulto non contiene minori',
  $$select count(*) from public.discover_profiles('friendship') d where d ->> 'id' in ('44444444-4444-4444-4444-444444444444','99999999-9999-9999-9999-999999999999')$$, '0');
rollback;

-- =====================================================================
\echo '--- 5. Match, dating e chat ---'
begin;
-- dating disattivato di default
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.denied('dating spento finché non configurato',
  $$select public.like_user('22222222-2222-2222-2222-222222222222', 'dating')$$);
reset role;
update public.app_config set value = 'true' where key = 'dating_enabled';
set local role authenticated;
select tests.denied('dating vietato verso adulto NON verificato',
  $$select public.like_user('33333333-3333-3333-3333-333333333333', 'dating')$$);
select tests.eq('like dating tra verificati, nessun match ancora',
  $$select public.like_user('22222222-2222-2222-2222-222222222222', 'dating') ->> 'matched'$$, 'false');
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('like reciproco crea il match',
  $$select public.like_user('11111111-1111-1111-1111-111111111111', 'dating') ->> 'matched'$$, 'true');
select tests.eq('B vede il match', 'select count(*) from public.matches', '1');
select tests.eq('conversazione creata con 2 partecipanti',
  'select count(*) from public.conversation_participants', '2');
select tests.ok('B scrive ad A',
  $$insert into public.messages (conversation_id, sender_id, body) select id, auth.uid(), 'Ciao!' from public.conversations limit 1$$);
select tests.denied('B non può fingersi A come mittente',
  $$insert into public.messages (conversation_id, sender_id, body) select id, '11111111-1111-1111-1111-111111111111', 'falso' from public.conversations limit 1$$);
select tests.eq('nessuna modifica diretta dei messaggi (0 righe toccate)',
  $$with u as (update public.messages set body = 'modificato' returning 1) select count(*) from u$$, '0');
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.eq('A ha ricevuto la notifica di nuovo messaggio',
  $$select count(*) from public.notifications where kind = 'message'$$, '1');
select tests.eq('A ha la notifica di match', $$select count(*) from public.notifications where kind = 'match'$$, '1');
select tests.ok('A segna come letto', $$select public.mark_conversation_read((select id from public.conversations limit 1))$$);
select tests.eq('stato di lettura aggiornato', $$select count(*) from public.messages where read_at is not null$$, '1');
select tests.login('33333333-3333-3333-3333-333333333333');
select tests.eq('un estraneo non vede la conversazione', 'select count(*) from public.conversations', '0');
select tests.eq('un estraneo non vede i messaggi', 'select count(*) from public.messages', '0');
select tests.denied('un estraneo non può scrivere nella conversazione',
  $$insert into public.messages (conversation_id, sender_id, body) values ((select id from public.conversations limit 1), auth.uid(), 'intruso')$$);
reset role;
select tests.login('33333333-3333-3333-3333-333333333333');
select set_config('tests.conv', (select id::text from public.conversations limit 1), true);
set local role authenticated;
select tests.denied('un estraneo non può scrivere anche conoscendo l''id della conversazione',
  $$insert into public.messages (conversation_id, sender_id, body) values (current_setting('tests.conv')::uuid, auth.uid(), 'intruso')$$);
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.ok('A annulla il match', $$select public.unmatch((select id from public.matches limit 1))$$);
select tests.denied('dopo l''unmatch la chat è chiusa',
  $$insert into public.messages (conversation_id, sender_id, body) select id, auth.uid(), 'ancora?' from public.conversations limit 1$$);
rollback;

-- =====================================================================
\echo '--- 6. Blocco utenti ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.like_user('22222222-2222-2222-2222-222222222222', 'friendship');
select tests.login('22222222-2222-2222-2222-222222222222');
select public.like_user('11111111-1111-1111-1111-111111111111', 'friendship');
select tests.ok('B blocca A', $$select public.block_user('11111111-1111-1111-1111-111111111111')$$);
select tests.eq('B non vede più il profilo di A',
  $$select count(*) from public.profiles where id = '11111111-1111-1111-1111-111111111111'$$, '0');
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.eq('A non vede più il profilo di B',
  $$select count(*) from public.profiles where id = '22222222-2222-2222-2222-222222222222'$$, '0');
select tests.eq('A non vede più i post di B', 'select count(*) from public.posts', '0');
select tests.denied('A bloccato non può più scrivere a B',
  $$insert into public.messages (conversation_id, sender_id, body) select id, auth.uid(), 'ciao?' from public.conversations limit 1$$);
select tests.denied('A bloccato non può rimettere like a B',
  $$select public.like_user('22222222-2222-2222-2222-222222222222', 'friendship')$$);
select tests.denied('A bloccato non può chiedere amicizia a B',
  $$select public.send_friend_request('22222222-2222-2222-2222-222222222222')$$);
select tests.eq('A non sa di essere stato bloccato (non vede la tabella blocchi di B)',
  'select count(*) from public.blocked_users', '0');
rollback;

-- =====================================================================
\echo '--- 7. Utente segnalato / sospeso ---'
begin;
select tests.login('77777777-7777-7777-7777-777777777777');
set local role authenticated;
select tests.denied('utente sospeso non può pubblicare',
  $$insert into public.posts (author_id, body, audience_band) values (auth.uid(), 'spam', 'adult')$$);
select tests.denied('utente sospeso non può mettere like',
  $$select public.like_user('11111111-1111-1111-1111-111111111111')$$);
select tests.eq('utente sospeso non vede il feed', 'select count(*) from public.posts', '0');
rollback;

-- =====================================================================
\echo '--- 8. Community, antispam, rate limit, segnalazioni ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.ok('A pubblica un post', $$insert into public.posts (author_id, body, audience_band) values (auth.uid(), '[TEST] post', 'adult')$$);
select tests.denied('post con troppi link bloccato dall''antispam',
  $$insert into public.posts (author_id, body, audience_band) values (auth.uid(), 'http://a http://b http://c http://d', 'adult')$$);
select tests.denied('A non può pubblicare a nome di B',
  $$insert into public.posts (author_id, body, audience_band) values ('22222222-2222-2222-2222-222222222222', 'falso', 'adult')$$);
select tests.eq('A non può modificare il post di B (0 righe toccate)',
  $$with u as (update public.posts set body = 'hack' where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning 1) select count(*) from u$$, '0');
select tests.denied('A non può auto-nascondere/sbloccare la moderazione del proprio post',
  $$update public.posts set is_hidden = true where author_id = auth.uid()$$);
select tests.ok('A commenta il post di B',
  $$insert into public.comments (post_id, author_id, body) values ('bbbbbbbb-0000-0000-0000-000000000001', auth.uid(), 'Bel post')$$);
select tests.ok('A mette mi piace al post di B',
  $$insert into public.reactions (user_id, post_id) values (auth.uid(), 'bbbbbbbb-0000-0000-0000-000000000001')$$);
select tests.denied('doppio mi piace bloccato',
  $$insert into public.reactions (user_id, post_id) values (auth.uid(), 'bbbbbbbb-0000-0000-0000-000000000001')$$);
select tests.ok('A segnala il post di B',
  $$insert into public.reports (target_type, target_id, reason) values ('post', 'bbbbbbbb-0000-0000-0000-000000000001', 'spam')$$);
select tests.eq('il reporter è forzato all''utente corrente',
  $$select reporter_id::text from public.reports limit 1$$, '11111111-1111-1111-1111-111111111111');
select tests.eq('registro moderazione invisibile ad A', 'select count(*) from public.moderation_actions', '0');
select tests.denied('rate limit: oltre 10 post al minuto bloccati',
  $q$do $d$ begin for i in 1..12 loop insert into public.posts (author_id, body, audience_band) values (auth.uid(), 'post ' || i, 'adult'); end loop; end $d$$q$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('B riceve notifiche di commento e like',
  $$select string_agg(kind, ',' order by kind) from public.notifications$$, 'comment,like');
rollback;

-- =====================================================================
\echo '--- 9. NON SEI SOLO: anonimato ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.ok('A pubblica un pensiero anonimo',
  $$insert into public.support_posts (author_id, body, is_anonymous, audience_band) values (auth.uid(), '[TEST] giornata difficile', true, 'adult')$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('B vede il pensiero ma NON l''autore',
  $$select coalesce(author_id::text, 'nascosto') from public.list_support_posts()$$, 'nascosto');
select tests.eq('B non può leggere la tabella per scoprire l''autore',
  'select count(*) from public.support_posts', '0');
select tests.ok('B risponde con incoraggiamento',
  $$insert into public.support_replies (support_post_id, author_id, body) select id, auth.uid(), 'Forza!' from public.list_support_posts()$$);
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('il minore non vede i pensieri degli adulti', 'select count(*) from public.list_support_posts()', '0');
rollback;

-- =====================================================================
\echo '--- 10. Eventi ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.ok('A propone un evento (resta in revisione)',
  $$insert into public.events (organizer_id, title, description, category, country, city, starts_at, audience_band, status)
    values (auth.uid(), '[TEST] Torneo', 'desc', 'gaming', 'IT', 'Milano', now() + interval '10 days', 'adult', 'published')$$);
select tests.eq('lo stato è forzato a pending_review',
  $$select status from public.events where organizer_id = auth.uid()$$, 'pending_review');
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('B non vede eventi non approvati',
  $$select count(*) from public.events where status = 'pending_review'$$, '0');
select tests.ok('B si iscrive all''evento pubblicato',
  $$insert into public.event_participants (event_id, user_id) values ('cccccccc-0000-0000-0000-000000000001', auth.uid())$$);
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.ok('A si iscrive (posti: 2/2)',
  $$insert into public.event_participants (event_id, user_id) values ('cccccccc-0000-0000-0000-000000000001', auth.uid())$$);
select tests.login('33333333-3333-3333-3333-333333333333');
select tests.denied('evento pieno: C rifiutato',
  $$insert into public.event_participants (event_id, user_id) values ('cccccccc-0000-0000-0000-000000000001', auth.uid())$$);
rollback;

-- =====================================================================
\echo '--- 11. Amministrazione e accesso ai dati privati ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.denied('utente normale non può sospendere altri',
  $$select public.admin_set_user_status('22222222-2222-2222-2222-222222222222', 'banned', 'test')$$);
select tests.denied('utente normale non vede statistiche',  $$select public.admin_stats()$$);
select tests.denied('utente normale non può verificare l''età',
  $$select public.admin_set_age_verification(auth.uid(), 'verified', 'manual_review', 'auto')$$);
-- prepara un messaggio segnalato
reset role;
update public.app_config set value = 'true' where key = 'dating_enabled';
set local role authenticated;
select public.like_user('22222222-2222-2222-2222-222222222222', 'friendship');
select tests.login('22222222-2222-2222-2222-222222222222');
select public.like_user('11111111-1111-1111-1111-111111111111', 'friendship');
insert into public.messages (conversation_id, sender_id, body) select id, auth.uid(), 'messaggio offensivo di prova' from public.conversations limit 1;
select tests.login('11111111-1111-1111-1111-111111111111');
insert into public.reports (target_type, target_id, reason) select 'message', id, 'harassment' from public.messages limit 1;
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.ok('B cancella il messaggio entro 24h', $$select public.delete_message((select id from public.messages limit 1))$$);
select tests.eq('il testo è stato rimosso dalla chat', $$select coalesce(body, 'rimosso') from public.messages limit 1$$, 'rimosso');

select tests.login('55555555-5555-5555-5555-555555555555');
select tests.eq('l''admin NON legge i messaggi privati direttamente', 'select count(*) from public.messages', '0');
select tests.denied('l''admin non accede senza motivazione',
  $$select public.admin_read_reported_message((select id from public.reports limit 1), 'breve')$$);
select tests.eq('con segnalazione + motivazione vede la prova conservata',
  $$select public.admin_read_reported_message((select id from public.reports limit 1), 'Verifica segnalazione per molestie') -> 'evidence' ->> 'body'$$,
  'messaggio offensivo di prova');
select tests.eq('accesso registrato nel log', 'select count(*) from public.admin_access_log', '1');
select tests.ok('admin sospende un utente', $$select public.admin_set_user_status('33333333-3333-3333-3333-333333333333', 'suspended', 'Test di sospensione')$$);
select tests.eq('azione registrata', $$select count(*) from public.moderation_actions where action = 'set_status:suspended'$$, '1');
select tests.ok('admin pubblica statistiche aggregate', $$select public.admin_stats()$$);
select tests.denied('admin non può cambiare il proprio ruolo', $$select public.admin_set_role(auth.uid(), 'user', 'test')$$);
select tests.denied('verifica età impossibile su un profilo teen',
  $$select public.admin_set_age_verification('44444444-4444-4444-4444-444444444444', 'verified', 'manual_review', 'test')$$);
rollback;

-- =====================================================================
\echo '--- 12. SENTINEL (pagina del fondatore) ---'
begin;
select tests.login('66666666-6666-6666-6666-666666666666');
set local role authenticated;
select tests.ok('Sentinel pubblica un aggiornamento',
  $$insert into public.creator_updates (author_id, kind, title, body, published) values (auth.uid(), 'update', '[TEST] Novità', 'testo', false)$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.ok('B segue Sentinel', $$insert into public.creator_followers (user_id) values (auth.uid())$$);
select tests.eq('B non vede le bozze', $$select count(*) from public.creator_updates where not published$$, '0');
select tests.denied('B non può pubblicare come Sentinel',
  $$insert into public.creator_updates (author_id, kind, title, body, published) values (auth.uid(), 'update', 'falso', 'x', true)$$);
select tests.ok('B propone un''idea', $$insert into public.creator_ideas (author_id, kind, body, is_public) values (auth.uid(), 'idea', 'Idea di prova', true)$$);
select tests.eq('l''idea non diventa pubblica da sola', $$select is_public::text from public.creator_ideas$$, 'false');
select tests.login('66666666-6666-6666-6666-666666666666');
select tests.ok('Sentinel pubblica la bozza', $$update public.creator_updates set published = true where not published$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('il follower riceve la notifica', $$select count(*) from public.notifications where kind = 'creator'$$, '1');
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('la pagina Sentinel è visibile anche alla fascia teen', $$select count(*) > 0 from public.creator_updates$$, 'true');
rollback;

-- =====================================================================
\echo '--- 13. GDPR: export e cancellazione ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.eq('export contiene il profilo', $$select public.export_my_data() -> 'profile' ->> 'username'$$, 'test_adulto_a');
select tests.eq('export contiene la data di nascita (dato proprio)', $$select (public.export_my_data() -> 'private' ->> 'birth_date') is not null$$, 'true');
select tests.ok('cancellazione account', $$select public.delete_my_account()$$);
reset role;
select tests.eq('profilo cancellato', $$select count(*) from public.profiles where id = '11111111-1111-1111-1111-111111111111'$$, '0');
select tests.eq('data di nascita cancellata', $$select count(*) from public.profiles_private where user_id = '11111111-1111-1111-1111-111111111111'$$, '0');
select tests.eq('verifiche età cancellate', $$select count(*) from public.age_verifications where user_id = '11111111-1111-1111-1111-111111111111'$$, '0');
select tests.eq('utente auth cancellato', $$select count(*) from auth.users where id = '11111111-1111-1111-1111-111111111111'$$, '0');
rollback;

\echo '=== Fine test di sicurezza ==='
