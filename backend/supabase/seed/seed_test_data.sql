-- =====================================================================
-- DATI DI TEST – FITTIZI
-- Nessun dato personale reale. Tutti gli username iniziano con "test_",
-- tutte le email usano il dominio riservato example.test.
-- NON eseguire in produzione.
-- =====================================================================
do $$ begin
  if exists (select 1 from public.profiles where username not like 'test\_%') then
    raise exception 'Il database contiene utenti reali: seed annullato.';
  end if;
end $$;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'adulto.a@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'adulto.b@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'adulto.c@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'minore@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'admin@example.test'),
  ('66666666-6666-6666-6666-666666666666', 'sentinel@example.test'),
  ('77777777-7777-7777-7777-777777777777', 'segnalato@example.test'),
  ('88888888-8888-8888-8888-888888888888', 'nuovo@example.test'),
  ('99999999-9999-9999-9999-999999999999', 'minore2@example.test');

-- Profili creati direttamente (come farebbe complete_onboarding).
-- I profili "teen" simulano il futuro ambiente 13–17, oggi disattivato.
insert into public.profiles (id, username, display_name, country, city, interests, favorite_games, age_band, role, status) values
  ('11111111-1111-1111-1111-111111111111', 'test_adulto_a', '[TEST] Adulto A', 'IT', 'Milano', '{gaming,musica}', '{Minecraft}', 'adult', 'user', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'test_adulto_b', '[TEST] Adulto B', 'IT', 'Milano', '{gaming,fanart}', '{Fortnite}', 'adult', 'user', 'active'),
  ('33333333-3333-3333-3333-333333333333', 'test_adulto_c', '[TEST] Adulto C', 'IT', 'Roma',   '{gaming}',        '{}',          'adult', 'user', 'active'),
  ('44444444-4444-4444-4444-444444444444', 'test_minore',   '[TEST] Minore',   'IT', 'Milano', '{gaming}',        '{}',          'teen',  'user', 'active'),
  ('55555555-5555-5555-5555-555555555555', 'test_admin',    '[TEST] Admin',    'IT', 'Torino', '{}',              '{}',          'adult', 'admin', 'active'),
  ('66666666-6666-6666-6666-666666666666', 'test_sentinel', '[TEST] Sentinel', 'IT', 'Torino', '{}',              '{}',          'adult', 'creator', 'active'),
  ('77777777-7777-7777-7777-777777777777', 'test_segnalato','[TEST] Segnalato','IT', 'Napoli', '{gaming}',        '{}',          'adult', 'user', 'suspended'),
  ('99999999-9999-9999-9999-999999999999', 'test_minore_2', '[TEST] Minore 2', 'IT', 'Milano', '{gaming}',        '{}',          'teen',  'user', 'active');

insert into public.profiles_private (user_id, birth_date) values
  ('11111111-1111-1111-1111-111111111111', date '2000-01-01'),
  ('22222222-2222-2222-2222-222222222222', date '1998-06-15'),
  ('33333333-3333-3333-3333-333333333333', date '1995-03-10'),
  ('44444444-4444-4444-4444-444444444444', current_date - interval '15 years'),
  ('55555555-5555-5555-5555-555555555555', date '1990-01-01'),
  ('66666666-6666-6666-6666-666666666666', current_date - interval '18 years'),
  ('77777777-7777-7777-7777-777777777777', date '1999-09-09'),
  ('99999999-9999-9999-9999-999999999999', current_date - interval '16 years');

insert into public.user_preferences (user_id)
select id from public.profiles;

-- Adulti A e B verificati (procedura manuale di test, nessun documento)
insert into public.age_verifications (user_id, method, status, verified_at) values
  ('11111111-1111-1111-1111-111111111111', 'manual_review', 'verified', now()),
  ('22222222-2222-2222-2222-222222222222', 'manual_review', 'verified', now());

insert into public.groups (id, name, description, category, audience_band, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '[TEST] Gaming Milano', 'Gruppo di prova', 'gaming', 'adult', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '[TEST] Gruppo Teen', 'Gruppo di prova per la fascia 13–17', 'gaming', 'teen', '44444444-4444-4444-4444-444444444444');

insert into public.posts (id, author_id, body, hashtags, audience_band) values
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '[TEST] Primo post di prova', '{test}', 'adult'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', '[TEST] Post della fascia teen', '{test}', 'teen');

insert into public.events (id, organizer_id, title, description, category, country, city, venue_public, starts_at, max_participants, audience_band, status) values
  ('cccccccc-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', '[TEST] Raduno di prova', 'Evento fittizio', 'meetup', 'IT', 'Milano', 'Luogo pubblico di prova', now() + interval '30 days', 2, 'adult', 'published');

insert into public.creator_updates (author_id, kind, title, body, published) values
  ('66666666-6666-6666-6666-666666666666', 'devlog', '[TEST] Diario di sviluppo #1', 'Contenuto di prova', true);
