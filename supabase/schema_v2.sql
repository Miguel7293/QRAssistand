-- ============================================================================
-- MIGRACION v2: inscripciones (estilo Classroom) + resumen de asistencia
-- Ejecutar DESPUES de schema.sql en: Supabase -> SQL Editor -> Run
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ENROLLMENTS: relaciona estudiantes con cursos (se unen por codigo)
-- ---------------------------------------------------------------------------
create table if not exists public.enrollments (
  id         uuid primary key default gen_random_uuid(),
  course_id  uuid not null references public.courses (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (course_id, student_id)
);

alter table public.enrollments enable row level security;

-- El estudiante ve sus inscripciones; el docente ve las de sus cursos.
drop policy if exists enrollments_select on public.enrollments;
create policy enrollments_select on public.enrollments
  for select to authenticated using (
    student_id = auth.uid()
    or exists (select 1 from public.courses c
               where c.id = course_id and c.teacher_id = auth.uid())
  );

-- El estudiante puede inscribirse a si mismo.
drop policy if exists enrollments_insert on public.enrollments;
create policy enrollments_insert on public.enrollments
  for insert to authenticated with check (student_id = auth.uid());

drop policy if exists enrollments_delete on public.enrollments;
create policy enrollments_delete on public.enrollments
  for delete to authenticated using (student_id = auth.uid());

-- ---------------------------------------------------------------------------
-- join_course: el estudiante se une a un curso usando su codigo publico.
-- ---------------------------------------------------------------------------
create or replace function public.join_course(p_code text)
returns json
language plpgsql
security definer set search_path = public
as $$
declare
  v_course public.courses;
begin
  select * into v_course
  from public.courses
  where upper(code) = upper(trim(p_code));

  if not found then
    raise exception 'No existe un curso con ese codigo';
  end if;

  insert into public.enrollments (course_id, student_id)
  values (v_course.id, auth.uid())
  on conflict (course_id, student_id) do nothing;

  return json_build_object('ok', true, 'course_name', v_course.name);
end;
$$;

-- ---------------------------------------------------------------------------
-- student_course_summary: por cada curso inscrito, total de clases y a cuantas
-- asistio el estudiante. Alimenta las tarjetas y el grafico del inicio.
-- ---------------------------------------------------------------------------
create or replace function public.student_course_summary()
returns json
language sql
security definer set search_path = public
as $$
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  from (
    select
      c.id   as course_id,
      c.name as course_name,
      c.code as course_code,
      (select count(*) from public.class_sessions s
         where s.course_id = c.id)                     as total_sessions,
      (select count(*) from public.attendance a
         join public.class_sessions s on s.id = a.session_id
         where s.course_id = c.id and a.student_id = auth.uid()) as attended
    from public.enrollments e
    join public.courses c on c.id = e.course_id
    where e.student_id = auth.uid()
    order by c.name
  ) t;
$$;

-- ===========================================================================
-- Fin migracion v2.
-- ===========================================================================
