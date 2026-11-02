-- SOLO BASE LOCAL DE PRUEBA VACIA. Simula Auth/Storage sin conectarse a Supabase.
\set ON_ERROR_STOP on
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
create schema auth;
create table auth.users(id uuid primary key, email text unique, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
create schema storage;
create table storage.buckets(id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text, metadata jsonb);
alter table storage.objects enable row level security;
grant usage on schema auth, storage, public to anon, authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000001', 'odontologa.e3@proyecto.test', '{}');

\ir ../../scripts/03_INSTALAR_SUPABASE.sql

begin;
insert into auth.users values
  ('00000000-0000-0000-0000-000000000002', 'admin@test.local', '{}'),
  ('00000000-0000-0000-0000-000000000003', 'other@test.local', '{}'),
  ('00000000-0000-0000-0000-000000000004', 'staff@test.local', '{}');
update public.perfiles set rol = 'admin' where id = '00000000-0000-0000-0000-000000000002';
update public.perfiles set rol = 'doctor' where id = '00000000-0000-0000-0000-000000000003';
create function pg_temp.assert_true(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %', message; end if; end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
set local role authenticated;
insert into public.pacientes(id,nombres,apellidos) values
  ('10000000-0000-0000-0000-000000000001','Asignado','Prueba'),
  ('10000000-0000-0000-0000-000000000002','Ajeno','Prueba');
insert into public.doctores(id,nombre_completo,email) values
  ('20000000-0000-0000-0000-000000000001','Odontologa','odontologa.e3@proyecto.test'),
  ('20000000-0000-0000-0000-000000000002','Otro','other@test.local');
insert into public.pacientes_odontologos(paciente_id,odontologo_id)
values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
insert into public.citas(paciente_id,doctor_id,inicia_en) values
  ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',now()),
  ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002',now());
select pg_temp.assert_true((select count(*) = 2 from public.pacientes), 'admin ve todos');
select pg_temp.assert_true(public.tiene_permiso('roles.update'), 'admin tiene permisos administrativos');
insert into public.solicitudes_radiografias(id,paciente_id,odontologo_id,tipo) values
  ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Panoramica'),
  ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','Estudio registrado por administrador');
insert into storage.objects(bucket_id,name)
values ('radiografias','30000000-0000-0000-0000-000000000001/estudio.png');
insert into public.radiografias(solicitud_id,nombre,tipo,tamano,storage_path)
values ('30000000-0000-0000-0000-000000000001','estudio.png','image/png',100,
  '30000000-0000-0000-0000-000000000001/estudio.png');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((public.mi_acceso()->>'rol') = 'doctor', 'cuenta existente recibe doctor');
select pg_temp.assert_true(not public.tiene_permiso('usuarios.read'), 'doctor sin administracion');
select pg_temp.assert_true((select count(*) = 1 from public.pacientes), 'solo paciente asignado');
select pg_temp.assert_true((select count(*) = 1 from public.citas_pacientes), 'solo citas propias; vista respeta RLS');
select pg_temp.assert_true((select count(*) = 1 from public.usuarios), 'vista usuarios no filtra perfiles ajenos');
select pg_temp.assert_true((select count(*) = 0 from public.facturas), 'doctor no ve facturacion');
insert into public.pacientes(id,nombres,apellidos)
values ('10000000-0000-0000-0000-000000000003','Propio','Prueba');
select pg_temp.assert_true((select count(*) = 2 from public.pacientes), 'doctor crea y consulta propio');
update public.pacientes set telefono = '123' where id = '10000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select telefono = '123' from public.pacientes where id = '10000000-0000-0000-0000-000000000001'), 'doctor edita asignado');
do $$ begin
  begin
    update public.perfiles set rol = 'admin' where id = auth.uid();
    raise exception 'FAIL: autoasignacion de admin permitida';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.permisos_roles values ('doctor','usuarios.read');
    raise exception 'FAIL: concesion de permisos permitida';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.citas(paciente_id,doctor_id,inicia_en)
      values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',now());
    raise exception 'FAIL: doctor crea cita';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.pacientes_odontologos(paciente_id,odontologo_id)
      values ('10000000-0000-0000-0000-000000000002', auth.uid());
    raise exception 'FAIL: doctor se asigna paciente ajeno';
  exception when insufficient_privilege then null; end;
end $$;
insert into public.antecedentes_pacientes(paciente_id,diabetes)
values ('10000000-0000-0000-0000-000000000001','No');
do $$ begin
  begin
    insert into public.antecedentes_pacientes(paciente_id,diabetes)
      values ('10000000-0000-0000-0000-000000000002','No');
    raise exception 'FAIL: doctor accede a antecedentes ajenos';
  exception when insufficient_privilege then null; end;
end $$;
select pg_temp.assert_true(not public.tiene_permiso('radiografias.create'), 'doctor no solicita radiografias');
select pg_temp.assert_true(not public.tiene_permiso('radiografias.update'), 'doctor no registra radiografias');
select pg_temp.assert_true(public.puede_ver_solicitud('30000000-0000-0000-0000-000000000002'), 'doctor ve estudio de su paciente registrado por otro usuario');
do $$ begin
  begin
    insert into public.solicitudes_radiografias(paciente_id,tipo)
    values ('10000000-0000-0000-0000-000000000001','No permitido');
    raise exception 'FAIL: doctor crea solicitud de radiografia';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name)
    values ('radiografias','30000000-0000-0000-0000-000000000001/no-permitido.png');
    raise exception 'FAIL: doctor sube radiografia';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.radiografias(solicitud_id,nombre,tipo,tamano,storage_path)
    values ('30000000-0000-0000-0000-000000000002','no.png','image/png',100,
      '30000000-0000-0000-0000-000000000002/no.png');
    raise exception 'FAIL: doctor registra radiografia';
  exception when insufficient_privilege then null; end;
end $$;
select pg_temp.assert_true((select count(*) = 1 from storage.objects), 'lectura autorizada de storage');
select pg_temp.assert_true((select count(*) = 1 from public.notificaciones_radiografias), 'notificacion propia');
select pg_temp.assert_true((select count(*) = 0 from public.eventos_radiografias), 'auditoria oculta al doctor');
do $$ begin
  begin
    perform 1 from public.accesos_radiografias;
    raise exception 'FAIL: doctor puede consultar tokens';
  exception when insufficient_privilege then null; end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
select pg_temp.assert_true((select count(*) = 0 from public.radiografias), 'otro doctor no ve radiografia');
select pg_temp.assert_true((select count(*) = 0 from storage.objects), 'otro doctor no accede al archivo');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
select pg_temp.assert_true((public.mi_acceso()->'permisos') = '[]'::jsonb, 'staff sin permisos');
select pg_temp.assert_true((select count(*) = 0 from public.pacientes), 'staff sin pacientes');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select pg_temp.assert_true((select count(*) = 3 from public.eventos_radiografias), 'auditoria generada por triggers');

reset role;
set local role anon;
do $$ begin
  begin
    perform public.mi_acceso();
    raise exception 'FAIL: anon puede consultar permisos';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo 'PASS: permisos, aislamiento, vistas, auditoria y Storage'
