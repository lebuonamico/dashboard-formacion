-- Auditoría de los mails de cursos pendientes.
-- La completa solo la Edge Function `notificar-pendientes`, con la service
-- role: los clientes pueden leerla (Administrador y Academia) pero no escribir.
-- Correr una vez en el SQL Editor de Supabase. Es idempotente.

create table if not exists public.notificaciones_pendientes (
  id bigint generated always as identity primary key,
  creado_en timestamptz not null default now(),
  enviado_por text not null,
  legajo text not null,
  correo text not null,
  cursos jsonb not null,
  estado text not null check (estado in ('enviado', 'error')),
  resend_id text,
  detalle text
);

create index if not exists notificaciones_pendientes_legajo_idx
  on public.notificaciones_pendientes (legajo, creado_en desc);

alter table public.notificaciones_pendientes enable row level security;

revoke insert, update, delete on public.notificaciones_pendientes
  from anon, authenticated;

drop policy if exists notificaciones_pendientes_select
  on public.notificaciones_pendientes;

create policy notificaciones_pendientes_select
  on public.notificaciones_pendientes
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.usuarios_autorizados u
      where u.email = lower(auth.jwt() ->> 'email')
        and u.activo
        and u.ff_eliminar is null
        and u.ff_bloqueo is null
        and u.rol in ('admin', 'academia')
    )
  );
