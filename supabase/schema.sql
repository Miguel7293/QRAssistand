-- ============================================================================
-- Sistema de Control de Asistencia mediante QR Dinamico
-- Esquema de base de datos + funcion de validacion (Supabase / PostgreSQL)
-- ----------------------------------------------------------------------------
-- Ejecutar TODO este archivo en: Supabase -> SQL Editor -> New query -> Run
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. PROFILES: extiende auth.users con nombre y rol (teacher / student)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null,
  role       text not null check (role in ('teacher', 'student')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. COURSES: cursos que administra un docente
-- ---------------------------------------------------------------------------
create table if not exists public.courses (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  code       text not null unique,
  teacher_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. CLASS_SESSIONS: cada clase. Guarda el token QR rotativo, su expiracion,
--    y la ubicacion del aula (para la validacion GPS).
-- ---------------------------------------------------------------------------
create table if not exists public.class_sessions (
  id               uuid primary key default gen_random_uuid(),
  course_id        uuid not null references public.courses (id) on delete cascade,
  title            text not null,
  session_date     date not null default current_date,
  rotating_token   text,
  token_expires_at timestamptz,
  latitude         double precision,
  longitude        double precision,
  radius_m         integer not null default 50,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. ATTENDANCE: registros de asistencia.
--    UNIQUE(session_id, student_id) -> nadie registra dos veces.
--    UNIQUE(session_id, device_id)  -> un telefono no marca por dos personas
--                                      (nucleo anti-suplantacion).
-- ---------------------------------------------------------------------------
create table if not exists public.attendance (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.class_sessions (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  device_id  text not null,
  latitude   double precision,
  longitude  double precision,
  distance_m double precision,
  status     text not null default 'present',
  created_at timestamptz not null default now(),
  unique (session_id, student_id),
  unique (session_id, device_id)
);

-- ---------------------------------------------------------------------------
-- 5. Auto-crear el profile cuando se registra un usuario en Auth.
--    Lee full_name y role desde la metadata del signUp.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Sin nombre'),
    coalesce(new.raw_user_meta_data ->> 'role', 'student')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 6. register_attendance: LA funcion clave. Corre en el servidor
--    (security definer) para que el estudiante no pueda hacer trampa.
--    Aplica las 3 validaciones del perfil:
--      (a) QR dinamico: token correcto y no expirado
--      (b) GPS: distancia al aula <= radius_m (formula de Haversine)
--      (c) ID dispositivo: unico por sesion (via constraint UNIQUE)
-- ---------------------------------------------------------------------------
create or replace function public.register_attendance(
  p_session_id uuid,
  p_token      text,
  p_lat        double precision,
  p_lng        double precision,
  p_device_id  text
)
returns json
language plpgsql
security definer set search_path = public
as $$
declare
  v_session   public.class_sessions;
  v_student   uuid := auth.uid();
  v_distance  double precision;
  v_r         double precision := 6371000; -- radio terrestre en metros
  v_dlat      double precision;
  v_dlng      double precision;
  v_a         double precision;
begin
  if v_student is null then
    raise exception 'No autenticado';
  end if;

  select * into v_session
  from public.class_sessions
  where id = p_session_id;

  if not found then
    raise exception 'La sesion no existe';
  end if;

  if not v_session.is_active then
    raise exception 'La sesion esta cerrada';
  end if;

  -- (a) Validacion QR dinamico
  if v_session.rotating_token is null
     or v_session.rotating_token <> p_token
     or now() > v_session.token_expires_at then
    raise exception 'El codigo QR expiro. Escanea el codigo actual.';
  end if;

  -- (b) Validacion GPS (Haversine)
  if v_session.latitude is not null and v_session.longitude is not null then
    v_dlat := radians(p_lat - v_session.latitude);
    v_dlng := radians(p_lng - v_session.longitude);
    v_a := sin(v_dlat / 2) ^ 2
         + cos(radians(v_session.latitude)) * cos(radians(p_lat))
         * sin(v_dlng / 2) ^ 2;
    v_distance := v_r * 2 * atan2(sqrt(v_a), sqrt(1 - v_a));

    if v_distance > v_session.radius_m then
      raise exception 'Estas fuera del aula (% m del punto permitido)',
        round(v_distance);
    end if;
  else
    v_distance := null;
  end if;

  -- (c) Insertar. Las constraints UNIQUE frenan doble registro y device repetido.
  begin
    insert into public.attendance
      (session_id, student_id, device_id, latitude, longitude, distance_m)
    values
      (p_session_id, v_student, p_device_id, p_lat, p_lng, v_distance);
  exception
    when unique_violation then
      raise exception 'Ya se registro asistencia (por ti o por este dispositivo)';
  end;

  return json_build_object(
    'ok', true,
    'distance_m', round(coalesce(v_distance, 0)),
    'at', now()
  );
end;
$$;

-- ===========================================================================
-- 7. ROW LEVEL SECURITY
-- ===========================================================================
alter table public.profiles       enable row level security;
alter table public.courses        enable row level security;
alter table public.class_sessions enable row level security;
alter table public.attendance     enable row level security;

-- profiles: cualquiera autenticado puede leer (para mostrar nombres en reportes);
--           cada quien inserta/actualiza el suyo.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles
  for update to authenticated using (id = auth.uid());

-- courses: el docente administra los suyos; todos los autenticados los leen.
drop policy if exists courses_select on public.courses;
create policy courses_select on public.courses
  for select to authenticated using (true);

drop policy if exists courses_write on public.courses;
create policy courses_write on public.courses
  for all to authenticated
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

-- class_sessions: el docente dueno del curso administra; todos leen.
drop policy if exists sessions_select on public.class_sessions;
create policy sessions_select on public.class_sessions
  for select to authenticated using (true);

drop policy if exists sessions_write on public.class_sessions;
create policy sessions_write on public.class_sessions
  for all to authenticated
  using (
    exists (select 1 from public.courses c
            where c.id = course_id and c.teacher_id = auth.uid())
  )
  with check (
    exists (select 1 from public.courses c
            where c.id = course_id and c.teacher_id = auth.uid())
  );

-- attendance: el estudiante ve lo suyo; el docente del curso ve todo.
--   La insercion NO se hace directa: se hace via register_attendance().
drop policy if exists attendance_select on public.attendance;
create policy attendance_select on public.attendance
  for select to authenticated using (
    student_id = auth.uid()
    or exists (
      select 1
      from public.class_sessions s
      join public.courses c on c.id = s.course_id
      where s.id = session_id and c.teacher_id = auth.uid()
    )
  );

-- ===========================================================================
-- Fin del esquema. Si todo corrio sin errores, la base esta lista.
-- ===========================================================================
