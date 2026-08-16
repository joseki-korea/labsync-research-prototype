-- applied via Supabase MCP on 2026-08-16 — see schema.sql comment for storage bucket/RLS detail
ALTER TABLE public.papers ADD COLUMN IF NOT EXISTS file_path text;
ALTER TABLE public.papers ADD COLUMN IF NOT EXISTS file_name text;
ALTER TABLE public.papers ADD COLUMN IF NOT EXISTS file_size_bytes bigint;
