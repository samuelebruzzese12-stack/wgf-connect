-- WGF CONNECT – Migrazione 0007: search_path fisso sulle funzioni trigger (avviso del linter Supabase)
alter function app_private.protect_profile_columns() set search_path = '';
alter function app_private.set_updated_at() set search_path = '';
alter function app_private.protect_content_columns() set search_path = '';
alter function app_private.normalize_hashtags() set search_path = '';
