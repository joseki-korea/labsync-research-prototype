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
