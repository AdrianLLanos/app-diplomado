-- Ejecutar DESPUES de subir el archivo al bucket privado radiografias.
-- Sustituir SOLO la ruta siguiente por la ruta exacta del objeto (sin URL ni bucket).
begin;
do $$
declare
  ruta text := 'UUID_DE_LA_SOLICITUD/estudio.jpg';
  solicitud uuid;
  objeto record;
begin
  solicitud := split_part(ruta, '/', 1)::uuid;
  select name, metadata into objeto from storage.objects
    where bucket_id = 'radiografias' and name = ruta;
  if not found then raise exception 'Archivo no encontrado: subelo primero al bucket radiografias'; end if;
  if not exists (select 1 from public.solicitudes_radiografias where id = solicitud) then
    raise exception 'La carpeta no corresponde a una solicitud existente';
  end if;
  if objeto.metadata->>'mimetype' not in ('image/jpeg','image/png','image/webp','application/pdf')
     or objeto.metadata->>'mimetype' is null then
    raise exception 'Tipo de archivo no admitido';
  end if;
  insert into public.radiografias(solicitud_id,nombre,tipo,tamano,storage_path)
  values (solicitud, regexp_replace(ruta, '^.*/', ''), objeto.metadata->>'mimetype',
          (objeto.metadata->>'size')::bigint, ruta);
  update public.solicitudes_radiografias
    set estado = 'Completada', completado_en = now() where id = solicitud;
end $$;
commit;
