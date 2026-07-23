-- ============================================================================
-- CORRECCIÓN: mensajes de la función register_attendance con ortografía
-- correcta (acentos/ñ). Ejecutar en Supabase -> SQL Editor -> Run.
-- Reemplaza la función existente sin borrar datos.
-- ============================================================================
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
  v_r         double precision := 6371000;
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
    raise exception 'La sesión no existe';
  end if;

  if not v_session.is_active then
    raise exception 'La sesión está cerrada';
  end if;

  -- (a) QR dinámico
  if v_session.rotating_token is null
     or v_session.rotating_token <> p_token
     or now() > v_session.token_expires_at then
    raise exception 'El código QR expiró. Escanea el código actual.';
  end if;

  -- (b) GPS (Haversine)
  if v_session.latitude is not null and v_session.longitude is not null then
    v_dlat := radians(p_lat - v_session.latitude);
    v_dlng := radians(p_lng - v_session.longitude);
    v_a := sin(v_dlat / 2) ^ 2
         + cos(radians(v_session.latitude)) * cos(radians(p_lat))
         * sin(v_dlng / 2) ^ 2;
    v_distance := v_r * 2 * atan2(sqrt(v_a), sqrt(1 - v_a));

    if v_distance > v_session.radius_m then
      raise exception 'Estás fuera del aula (% m del punto permitido)',
        round(v_distance);
    end if;
  else
    v_distance := null;
  end if;

  -- (c) Registro único por sesión y por dispositivo
  begin
    insert into public.attendance
      (session_id, student_id, device_id, latitude, longitude, distance_m)
    values
      (p_session_id, v_student, p_device_id, p_lat, p_lng, v_distance);
  exception
    when unique_violation then
      raise exception 'Ya se registró asistencia (por ti o por este dispositivo)';
  end;

  return json_build_object(
    'ok', true,
    'distance_m', round(coalesce(v_distance, 0)),
    'at', now()
  );
end;
$$;
