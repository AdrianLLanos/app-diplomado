-- Aplicar sobre las tablas ya instaladas. No borra pacientes, solicitudes ni archivos.
begin;

delete from public.permisos_roles
where rol_id = 'doctor' and permiso_id like 'radiografias.%'
  and permiso_id <> 'radiografias.read';
delete from public.permisos_modelos pm using public.perfiles p
where pm.modelo_id = p.id and p.rol = 'doctor'
  and pm.permiso_id like 'radiografias.%' and pm.permiso_id <> 'radiografias.read';
insert into public.permisos_roles(rol_id, permiso_id)
values ('doctor', 'radiografias.read') on conflict do nothing;

-- El archivo pertenece al paciente. Puede haberlo registrado otro usuario autorizado.
create or replace function public.puede_ver_solicitud(solicitud uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.es_administrador() or exists (
    select 1 from public.solicitudes_radiografias s
    where s.id = solicitud and public.puede_ver_paciente(s.paciente_id)
      and public.tiene_permiso('radiografias.read')
  );
$$;

-- Las escrituras quedan reservadas al administrador incluso con concesiones individuales.
drop policy if exists solicitudes_crear on public.solicitudes_radiografias;
create policy solicitudes_crear on public.solicitudes_radiografias for insert to authenticated
  with check (public.es_administrador() and public.tiene_permiso('radiografias.create'));
drop policy if exists solicitudes_editar on public.solicitudes_radiografias;
create policy solicitudes_editar on public.solicitudes_radiografias for update to authenticated
  using (public.es_administrador() and public.tiene_permiso('radiografias.update'))
  with check (public.es_administrador() and public.tiene_permiso('radiografias.update'));
drop policy if exists radiografias_registrar on public.radiografias;
create policy radiografias_registrar on public.radiografias for insert to authenticated
  with check (public.es_administrador() and public.tiene_permiso('radiografias.update')
    and split_part(storage_path, '/', 1) = solicitud_id::text);
drop policy if exists clinica_radiografias_cargar on storage.objects;
create policy clinica_radiografias_cargar on storage.objects for insert to authenticated
  with check (bucket_id = 'radiografias' and public.es_administrador()
    and public.tiene_permiso('radiografias.update') and exists (
      select 1 from public.solicitudes_radiografias s
      where s.id::text = split_part(name, '/', 1)
    ));

notify pgrst, 'reload schema';
commit;

select r.nombre as rol, pr.permiso_id
from public.permisos_roles pr join public.roles r on r.id = pr.rol_id
where pr.rol_id = 'doctor' and pr.permiso_id like 'radiografias.%';
