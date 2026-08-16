
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

