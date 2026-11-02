# Modelo y permisos

Referencias revisadas: `LLanosZenteno_AdrianAlejandro.pdf`, secciones 2.3 y 2.4.2
(paginas impresas 20 a 23), y `C:\clinica-angular\database`. Se uso el documento
como referencia de requisitos y datos.

| Documento / Angular | Aplicacion movil |
| --- | --- |
| usuarios | auth.users + perfiles; vista usuarios para consulta |
| detalles_medicos | doctores; vista detalles_medicos |
| horarios_medicos | horarios_doctores; vista horarios_medicos |
| citas_pacientes | citas; vista citas_pacientes |
| antecedentes_pacientes | Nueva tabla asociada a pacientes |
| recetas | Tabla existente, estructura simplificada |
| pacientes_odontologos | Nueva tabla de asignaciones paciente/cuenta odontologo |
| roles, permisos, permisos_roles | Nuevas tablas del mismo nombre |
| roles_modelos | Vista del rol unico de perfiles, evitando duplicar la asignacion |
| permisos_modelos | Nueva tabla de concesiones individuales desde servidor |
| solicitudes_radiografias | Nueva tabla del mismo nombre |
| accesos_radiografias | Nueva tabla exclusiva del servidor; guarda hashes |
| radiografias | Nueva tabla con metadatos y ruta de Storage privado |
| eventos_radiografias | Nueva tabla de auditoria, sin escrituras del cliente |
| notificaciones_radiografias | Nueva tabla, lectura propia y marcado de leido |
| empresas, usuarios_empresas | No se trasladan: esta app trabaja con una sola clinica |

Se usan UUID compatibles con Supabase Auth y los registros existentes, en lugar
de los BIGINT de Angular. Las vistas respetan RLS (`security_invoker`). Los
pacientes son registros clinicos sin cuenta obligatoria. Auth gestiona correos y
contrasenas: no se duplican contrasenas en public. No se trasladan SMTP, campanas,
sesiones o recuperacion de contrasenas de Node.

Se conservan las tablas anteriores de seguros, facturacion y laboratorio para no
borrar datos. Quedan reservadas al administrador y fuera del menu actual, siguiendo
la retirada de modulos en la migracion 09 de Angular.

## Permisos

| Accion | Administrador | Odontologo |
| --- | --- | --- |
| Modulo Administrador | Si | No |
| Modulo Odontologo | Si | Si |
| Pacientes | Todos | Crear; consultar, editar y eliminar propios/asignados |
| Profesionales y horarios | Gestionar | Consulta |
| Citas | Gestionar | Consultar propias, con paciente autorizado |
| Antecedentes y recetas | Todos | Gestionar en pacientes propios/asignados |
| Solicitudes y radiografias | Consulta, solicitudes, registro | Solo visualizar las de pacientes propios/asignados |
| Auditoria radiografica | Consulta | No |
| Usuarios y roles | Consulta en app; asignacion desde Supabase | No |

La matriz parte de las semillas de Angular y sus migraciones 04, 05, 07 y 09.
RLS comprueba permisos y ambito en cada consulta, incluso si se llama directamente
a la API. El cliente no puede modificar perfiles.rol ni las concesiones. La app
consulta `mi_acceso()` al iniciar sesion. Cambios de permisos requieren volver a
iniciar sesion para renovar el menu; RLS aplica el estado actual inmediatamente.

## Instalacion

- Base vacia: ejecutar UNA VEZ `scripts/03_INSTALAR_SUPABASE.sql` completo.
- Instalador anterior ya aplicado: ejecutar UNA VEZ
  `supabase/migrations/20261012090000_roles_y_modelo_clinico.sql`.
- Si ya existen roles y radiografias, aplicar solamente la actualizacion
  `supabase/migrations/20261012100000_radiografias_solo_lectura_odontologo.sql`.
- No ejecutar ambos sobre la misma instalacion; no borrar tablas ni usuarios.
- La instalacion manual no registra versiones en la CLI. Reconciliar su historial
  antes de combinarla con `supabase db push`.

La cuenta existente `odontologa.e3@proyecto.test` recibe `doctor`. No se crean
cuentas ni se incluyen contrasenas. Crear el administrador en Authentication y
asignar su rol desde SQL Editor, sustituyendo el correo:

```sql
update public.perfiles set rol = 'admin'
where id = (select id from auth.users where email = 'CORREO_DEL_ADMINISTRADOR')
returning id, nombre_completo, rol;
```

Registrar el profesional desde Administrador con el mismo correo de Authentication
para vincular automaticamente `doctores.perfil_id`. La migracion vincula profesionales
existentes cuando hay una coincidencia unica. Si se asigna doctor despues de crear
el profesional, volver a guardar su correo para renovar el vinculo.

Para compartir un paciente creado por administrador con la odontologa:

```sql
insert into public.pacientes_odontologos (paciente_id, odontologo_id)
select 'UUID_DEL_PACIENTE'::uuid, id from public.perfiles
where id = (select id from auth.users where email = 'odontologa.e3@proyecto.test')
on conflict do nothing;
```

## Alcance y pendientes

Las pantallas funcionales son pacientes, profesionales/horarios, citas y el visor
de radiografias. Ver [prueba manual del visor](PROBAR_VISOR_RADIOGRAFIAS.md).
Antecedentes, recetas y administracion de cuentas/permisos siguen
mostrando una pantalla pendiente; sus tablas y politicas estan preparadas.
No se implemento el portal CERPAX ni la generacion/validacion/consumo de accesos
temporales. Ese flujo requiere backend o Edge Function para validar tokens,
vencimiento, revocacion, uso unico y URLs firmadas. No hay acceso anonimo al bucket.
No se ejecuto SQL en el proyecto remoto ni se regenero la APK.
