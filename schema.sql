-- Graduate Research Management App (Phase 0 + Phase 1 MVP) Schema
-- Target Supabase Project: apwjwaryrlpqmdabilvu (agy-vibe-coding)

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  display_name text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Trigger: create profile when new auth.user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Backfill profiles for existing users
INSERT INTO public.profiles (id, email, display_name)
SELECT 
  id, 
  email, 
  COALESCE(raw_user_meta_data->>'display_name', split_part(email, '@', 1))
FROM auth.users
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email;

-- 2. Projects Table
CREATE TABLE IF NOT EXISTS public.projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- 3. Project Members Table
CREATE TABLE IF NOT EXISTS public.project_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(project_id, user_id)
);

-- Trigger: creator automatically becomes owner in project_members
CREATE OR REPLACE FUNCTION public.handle_new_project()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.project_members (project_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'owner')
  ON CONFLICT (project_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_project_created ON public.projects;
CREATE TRIGGER on_project_created
  AFTER INSERT ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_project();

-- 4. Helper Function: is_project_member
CREATE OR REPLACE FUNCTION public.is_project_member(p_project_id uuid, p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.project_members
    WHERE project_id = p_project_id
      AND user_id = p_user_id
  );
$$;

-- 5. Tracks Table
CREATE TABLE IF NOT EXISTS public.tracks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- 6. Hypotheses Table
CREATE TABLE IF NOT EXISTS public.hypotheses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  track_id uuid REFERENCES public.tracks(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'testing', 'supported', 'rejected', 'inconclusive')),
  rationale text,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_project_members_user ON public.project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_project_members_project ON public.project_members(project_id);
CREATE INDEX IF NOT EXISTS idx_tracks_project ON public.tracks(project_id);
CREATE INDEX IF NOT EXISTS idx_hypotheses_project ON public.hypotheses(project_id);
CREATE INDEX IF NOT EXISTS idx_hypotheses_track ON public.hypotheses(track_id);
CREATE INDEX IF NOT EXISTS idx_hypotheses_status ON public.hypotheses(status);

-- 7. Enable RLS on all 5 tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hypotheses ENABLE ROW LEVEL SECURITY;

-- 8. Profiles Policies
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

-- 9. Projects Policies
DROP POLICY IF EXISTS "projects_select_policy" ON public.projects;
CREATE POLICY "projects_select_policy" ON public.projects
  FOR SELECT TO authenticated
  USING (created_by = auth.uid() OR public.is_project_member(id, auth.uid()));

DROP POLICY IF EXISTS "projects_insert_policy" ON public.projects;
CREATE POLICY "projects_insert_policy" ON public.projects
  FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "projects_update_policy" ON public.projects;
CREATE POLICY "projects_update_policy" ON public.projects
  FOR UPDATE TO authenticated
  USING (created_by = auth.uid() OR public.is_project_member(id, auth.uid()))
  WITH CHECK (created_by = auth.uid() OR public.is_project_member(id, auth.uid()));

DROP POLICY IF EXISTS "projects_delete_policy" ON public.projects;
CREATE POLICY "projects_delete_policy" ON public.projects
  FOR DELETE TO authenticated
  USING (created_by = auth.uid() OR EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = projects.id AND user_id = auth.uid() AND role IN ('owner', 'admin')
  ));

-- 10. Project Members Policies
DROP POLICY IF EXISTS "project_members_select_policy" ON public.project_members;
CREATE POLICY "project_members_select_policy" ON public.project_members
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "project_members_insert_policy" ON public.project_members;
CREATE POLICY "project_members_insert_policy" ON public.project_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.project_members
      WHERE project_id = project_members.project_id AND user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

DROP POLICY IF EXISTS "project_members_update_policy" ON public.project_members;
CREATE POLICY "project_members_update_policy" ON public.project_members
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = project_members.project_id AND user_id = auth.uid() AND role IN ('owner', 'admin')
  ));

DROP POLICY IF EXISTS "project_members_delete_policy" ON public.project_members;
CREATE POLICY "project_members_delete_policy" ON public.project_members
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.project_members
      WHERE project_id = project_members.project_id AND user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- 11. Tracks Policies
DROP POLICY IF EXISTS "tracks_select_policy" ON public.tracks;
CREATE POLICY "tracks_select_policy" ON public.tracks
  FOR SELECT TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "tracks_insert_policy" ON public.tracks;
CREATE POLICY "tracks_insert_policy" ON public.tracks
  FOR INSERT TO authenticated
  WITH CHECK (public.is_project_member(project_id, auth.uid()) AND created_by = auth.uid());

DROP POLICY IF EXISTS "tracks_update_policy" ON public.tracks;
CREATE POLICY "tracks_update_policy" ON public.tracks
  FOR UPDATE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()))
  WITH CHECK (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "tracks_delete_policy" ON public.tracks;
CREATE POLICY "tracks_delete_policy" ON public.tracks
  FOR DELETE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

-- 12. Hypotheses Policies
DROP POLICY IF EXISTS "hypotheses_select_policy" ON public.hypotheses;
CREATE POLICY "hypotheses_select_policy" ON public.hypotheses
  FOR SELECT TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "hypotheses_insert_policy" ON public.hypotheses;
CREATE POLICY "hypotheses_insert_policy" ON public.hypotheses
  FOR INSERT TO authenticated
  WITH CHECK (public.is_project_member(project_id, auth.uid()) AND created_by = auth.uid());

DROP POLICY IF EXISTS "hypotheses_update_policy" ON public.hypotheses;
CREATE POLICY "hypotheses_update_policy" ON public.hypotheses
  FOR UPDATE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()))
  WITH CHECK (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "hypotheses_delete_policy" ON public.hypotheses;
CREATE POLICY "hypotheses_delete_policy" ON public.hypotheses
  FOR DELETE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

-- ============================================================
-- Papers Table (added 2026-08-16: 논문조사 파이프라인)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.papers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  hypothesis_id uuid REFERENCES public.hypotheses(id) ON DELETE SET NULL,
  semantic_scholar_id text,
  title text NOT NULL,
  authors text,
  year int,
  source_url text,
  abstract text,
  fit_score numeric,
  insight_summary text,
  saved_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_papers_project ON public.papers(project_id);
CREATE INDEX IF NOT EXISTS idx_papers_hypothesis ON public.papers(hypothesis_id);

ALTER TABLE public.papers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "papers_select_policy" ON public.papers;
CREATE POLICY "papers_select_policy" ON public.papers
  FOR SELECT TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "papers_insert_policy" ON public.papers;
CREATE POLICY "papers_insert_policy" ON public.papers
  FOR INSERT TO authenticated
  WITH CHECK (public.is_project_member(project_id, auth.uid()) AND saved_by = auth.uid());

DROP POLICY IF EXISTS "papers_update_policy" ON public.papers;
CREATE POLICY "papers_update_policy" ON public.papers
  FOR UPDATE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()))
  WITH CHECK (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "papers_delete_policy" ON public.papers;
CREATE POLICY "papers_delete_policy" ON public.papers
  FOR DELETE TO authenticated
  USING (saved_by = auth.uid() OR EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = papers.project_id AND user_id = auth.uid() AND role IN ('owner', 'admin')
  ));

-- ============================================================
-- Thesis Chapters Table (added 2026-08-16: 논문 완성도 체크)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.thesis_chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
  chapter_order int NOT NULL,
  chapter_name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'draft_done', 'reviewed')),
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_thesis_chapters_project ON public.thesis_chapters(project_id);

ALTER TABLE public.thesis_chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "thesis_chapters_select_policy" ON public.thesis_chapters;
CREATE POLICY "thesis_chapters_select_policy" ON public.thesis_chapters
  FOR SELECT TO authenticated
  USING (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "thesis_chapters_insert_policy" ON public.thesis_chapters;
CREATE POLICY "thesis_chapters_insert_policy" ON public.thesis_chapters
  FOR INSERT TO authenticated
  WITH CHECK (public.is_project_member(project_id, auth.uid()) AND created_by = auth.uid());

DROP POLICY IF EXISTS "thesis_chapters_update_policy" ON public.thesis_chapters;
CREATE POLICY "thesis_chapters_update_policy" ON public.thesis_chapters
  FOR UPDATE TO authenticated
  USING (public.is_project_member(project_id, auth.uid()))
  WITH CHECK (public.is_project_member(project_id, auth.uid()));

DROP POLICY IF EXISTS "thesis_chapters_delete_policy" ON public.thesis_chapters;
CREATE POLICY "thesis_chapters_delete_policy" ON public.thesis_chapters
  FOR DELETE TO authenticated
  USING (created_by = auth.uid() OR EXISTS (
    SELECT 1 FROM public.project_members
    WHERE project_id = thesis_chapters.project_id AND user_id = auth.uid() AND role IN ('owner', 'admin')
  ));
