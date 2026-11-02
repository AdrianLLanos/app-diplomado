-- OPCIONAL: crea un paciente FICTICIO y una solicitud para probar el visor sin la web.
-- Ejecutar una vez en SQL Editor despues de instalar las migraciones de roles.
-- No crea imagenes, no sube archivos y no modifica pacientes existentes.
begin;
do $$ begin
  if not exists (select 1 from auth.users u join public.perfiles p on p.id = u.id
                 where u.email = 'odontologa.e3@proyecto.test' and p.rol = 'doctor') then
    raise exception 'Primero crea la cuenta odontologa.e3@proyecto.test y asignale doctor';
  end if;
end $$;
with cuenta as (
  select id from auth.users where email = 'odontologa.e3@proyecto.test'
), paciente as (
  insert into public.pacientes(propietario_id, nombres, apellidos, notas_medicas)
  select id, 'Paciente', 'Prueba del visor', 'Registro ficticio para comprobar la visualizacion movil.'
  from cuenta returning id
), asignacion as (
  insert into public.pacientes_odontologos(paciente_id, odontologo_id)
  select p.id, c.id from paciente p cross join cuenta c
), solicitud as (
  insert into public.solicitudes_radiografias(paciente_id, odontologo_id, tipo)
  select p.id, c.id, 'Prueba del visor movil' from paciente p cross join cuenta c
  returning id, paciente_id
)
select paciente_id, id as solicitud_id, id::text || '/estudio.jpg' as ruta_para_subir
from solicitud;
commit;
