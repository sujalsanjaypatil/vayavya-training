create extension if not exists pgcrypto;

create type public.user_role as enum ('teacher', 'student', 'admin');
create type public.assessment_type as enum ('C_TEST', 'GENERAL_SUBMISSION');
create type public.assessment_status as enum ('DRAFT', 'PUBLISHED', 'ACTIVE', 'CLOSED');
create type public.test_visibility as enum ('PUBLIC', 'HIDDEN');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.user_role not null default 'student',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.assessments (
  id uuid primary key default gen_random_uuid(), teacher_id uuid not null references public.profiles(id),
  title text not null, description text, type public.assessment_type not null,
  instructions text, start_at timestamptz, end_at timestamptz, duration_minutes integer,
  max_marks numeric not null default 100 check (max_marks >= 0), passing_marks numeric,
  attempt_limit integer not null default 1 check (attempt_limit > 0), status public.assessment_status not null default 'DRAFT',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.assessment_questions (
  id uuid primary key default gen_random_uuid(), assessment_id uuid not null references public.assessments(id) on delete cascade,
  title text not null, problem_statement text not null, input_format text, output_format text, constraints text,
  examples jsonb not null default '[]', starter_code text, language text not null default 'C', difficulty text,
  tags text[] not null default '{}', max_marks numeric not null default 0, time_limit_ms integer, memory_limit_mb integer,
  position integer not null default 0, reference_solution text, created_at timestamptz not null default now()
);
create table public.test_cases (
  id uuid primary key default gen_random_uuid(), question_id uuid not null references public.assessment_questions(id) on delete cascade,
  name text not null, input text not null, expected_output text not null, marks numeric not null default 0,
  visibility public.test_visibility not null default 'HIDDEN', enabled boolean not null default true,
  category text not null default 'Custom', explanation text, position integer not null default 0
);
create table public.rubrics (id uuid primary key default gen_random_uuid(), assessment_id uuid not null unique references public.assessments(id) on delete cascade, created_at timestamptz not null default now());
create table public.rubric_criteria (id uuid primary key default gen_random_uuid(), rubric_id uuid not null references public.rubrics(id) on delete cascade, name text not null, description text, marks numeric not null default 0, position integer not null default 0);
create table public.assessment_students (assessment_id uuid references public.assessments(id) on delete cascade, student_id uuid references public.profiles(id) on delete cascade, assigned_at timestamptz not null default now(), primary key (assessment_id, student_id));
create table public.submissions (id uuid primary key default gen_random_uuid(), assessment_id uuid not null references public.assessments(id), student_id uuid not null references public.profiles(id), question_id uuid references public.assessment_questions(id), attempt integer not null default 1, source_code text, file_path text, submitted_at timestamptz, score numeric, status text not null default 'SUBMITTED', integrity_status text, created_at timestamptz not null default now());
create table public.code_snapshots (id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions(id) on delete cascade, version integer not null, source_code text not null, reason text not null, created_at timestamptz not null default now());
create table public.activity_events (id uuid primary key default gen_random_uuid(), submission_id uuid references public.submissions(id) on delete cascade, student_id uuid not null references public.profiles(id), event_type text not null, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create table public.execution_results (id uuid primary key default gen_random_uuid(), submission_id uuid references public.submissions(id) on delete cascade, status text not null, compile_output text, execution_time_ms integer, created_at timestamptz not null default now());
create table public.test_results (id uuid primary key default gen_random_uuid(), execution_id uuid not null references public.execution_results(id) on delete cascade, test_case_id uuid not null references public.test_cases(id), status text not null, actual_output text, score numeric, error text, created_at timestamptz not null default now());
create table public.integrity_analyses (id uuid primary key default gen_random_uuid(), submission_id uuid not null unique references public.submissions(id) on delete cascade, indicator_level text not null, confidence text not null, evidence jsonb not null default '[]', ai_declaration text, created_at timestamptz not null default now());
create table public.similarity_results (id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions(id) on delete cascade, compared_submission_id uuid references public.submissions(id), similarity_percent numeric not null, method text not null, created_at timestamptz not null default now());
create table public.viva_questions (id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions(id) on delete cascade, question text not null, created_at timestamptz not null default now());
create table public.viva_answers (id uuid primary key default gen_random_uuid(), question_id uuid not null references public.viva_questions(id) on delete cascade, answer text, evaluation text, teacher_id uuid references public.profiles(id), created_at timestamptz not null default now());
create table public.teacher_reviews (id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions(id) on delete cascade, teacher_id uuid not null references public.profiles(id), score numeric, comments text, created_at timestamptz not null default now());
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create index assessments_teacher_id_idx on public.assessments(teacher_id);
create index submissions_student_id_idx on public.submissions(student_id);
create index submissions_assessment_id_idx on public.submissions(assessment_id);
create index activity_events_submission_id_idx on public.activity_events(submission_id);

alter table public.profiles enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_questions enable row level security;
alter table public.test_cases enable row level security;
alter table public.assessment_students enable row level security;
alter table public.submissions enable row level security;
alter table public.code_snapshots enable row level security;
alter table public.activity_events enable row level security;
alter table public.integrity_analyses enable row level security;

create policy "profiles are visible to signed in users" on public.profiles for select to authenticated using (true);
create policy "users update their profile" on public.profiles for update to authenticated using (id = auth.uid());
create policy "teachers manage their assessments" on public.assessments for all to authenticated using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy "students see published assessments" on public.assessments for select to authenticated using (status in ('PUBLISHED', 'ACTIVE', 'CLOSED'));
create policy "teachers manage questions" on public.assessment_questions for all to authenticated using (exists (select 1 from public.assessments a where a.id = assessment_id and a.teacher_id = auth.uid()));
create policy "students see questions without reference solutions" on public.assessment_questions for select to authenticated using (exists (select 1 from public.assessments a join public.assessment_students s on s.assessment_id = a.id where a.id = assessment_id and s.student_id = auth.uid()));
create policy "teachers manage test cases" on public.test_cases for all to authenticated using (exists (select 1 from public.assessment_questions q join public.assessments a on a.id = q.assessment_id where q.id = question_id and a.teacher_id = auth.uid()));
create policy "students see public test cases" on public.test_cases for select to authenticated using (visibility = 'PUBLIC' and exists (select 1 from public.assessment_questions q join public.assessment_students s on s.assessment_id = q.assessment_id where q.id = question_id and s.student_id = auth.uid()));
create policy "students manage own submissions" on public.submissions for all to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy "teachers review submissions" on public.submissions for select to authenticated using (exists (select 1 from public.assessments a where a.id = assessment_id and a.teacher_id = auth.uid()));
create policy "students access own activity" on public.activity_events for all to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy "students access own snapshots" on public.code_snapshots for select to authenticated using (exists (select 1 from public.submissions s where s.id = submission_id and s.student_id = auth.uid()));
create policy "teachers access integrity analyses" on public.integrity_analyses for select to authenticated using (exists (select 1 from public.submissions s join public.assessments a on a.id = s.assessment_id where s.id = submission_id and a.teacher_id = auth.uid()));
