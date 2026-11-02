-- Ejecutar UNA SOLA VEZ en SQL Editor sobre un esquema dental vacio.
-- No borra usuarios ni tablas existentes. Si hay un error, la transaccion se revierte.
-- Instalacion manual: no registra versiones en el historial de la CLI de Supabase.
begin;
-- Ejecutar mediante `supabase db push` o en Supabase SQL Editor.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'staff' check (role in ('admin', 'doctor', 'reception', 'staff')),
  created_at timestamptz not null default now()
);

create or replace function public.create_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute procedure public.create_profile();

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  first_name text not null, last_name text not null, document_number text,
  birth_date date, phone text, email text, address text, medical_notes text,
  created_at timestamptz not null default now()
);

create table public.doctors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  full_name text not null, specialty text, phone text, email text,
  created_at timestamptz not null default now()
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete cascade,
  doctor_id uuid references public.doctors(id) on delete set null,
  starts_at timestamptz not null, ends_at timestamptz, reason text,
  status text not null default 'scheduled' check (status in ('scheduled', 'confirmed', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

create table public.clinical_cases (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete cascade,
  diagnosis text, treatment_plan text, notes text, created_at timestamptz not null default now()
);

create table public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete cascade,
  doctor_id uuid references public.doctors(id) on delete set null,
  medication text not null, instructions text, issued_at timestamptz not null default now()
);

create table public.lab_reports (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete cascade,
  title text not null, result text, status text not null default 'pending' check (status in ('pending', 'completed')),
  created_at timestamptz not null default now()
);

create table public.insurances (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete cascade,
  provider_name text not null, policy_number text, coverage_percent numeric(5,2),
  created_at timestamptz not null default now()
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  patient_id uuid not null references public.patients(id) on delete restrict,
  invoice_date date not null default current_date, total numeric(12,2) not null default 0,
  paid numeric(12,2) not null default 0, status text not null default 'pending' check (status in ('pending', 'partial', 'paid', 'void')),
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  invoice_id uuid references public.invoices(id) on delete set null,
  payment_date date not null default current_date, amount numeric(12,2) not null check (amount > 0),
  method text not null default 'cash', notes text, created_at timestamptz not null default now()
);

create index patients_owner_idx on public.patients(owner_id);
create index appointments_owner_starts_idx on public.appointments(owner_id, starts_at);
create index invoices_owner_idx on public.invoices(owner_id);

do $$
declare tab text;
begin
  foreach tab in array array['patients', 'doctors', 'appointments', 'clinical_cases', 'prescriptions', 'lab_reports', 'insurances', 'invoices', 'payments']
  loop
    execute format('alter table public.%I enable row level security', tab);
    execute format('create policy %I on public.%I for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid())', tab || '_own_data', tab);
  end loop;
end $$;

alter table public.profiles enable row level security;
create policy profiles_own_data on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());


-- Traduce el esquema dental ya aplicado, conservando datos, claves foraneas y RLS.
alter table public.profiles rename to perfiles;
alter table public.patients rename to pacientes;
alter table public.doctors rename to doctores;
alter table public.appointments rename to citas;
alter table public.clinical_cases rename to casos_clinicos;
alter table public.prescriptions rename to recetas;
alter table public.lab_reports rename to informes_laboratorio;
alter table public.insurances rename to seguros;
alter table public.invoices rename to facturas;
alter table public.payments rename to pagos;

alter table public.perfiles rename column full_name to nombre_completo;
alter table public.perfiles rename column role to rol;
alter table public.perfiles rename column created_at to creado_en;

alter table public.pacientes rename column owner_id to propietario_id;
alter table public.pacientes rename column first_name to nombres;
alter table public.pacientes rename column last_name to apellidos;
alter table public.pacientes rename column document_number to numero_documento;
alter table public.pacientes rename column birth_date to fecha_nacimiento;
alter table public.pacientes rename column phone to telefono;
alter table public.pacientes rename column address to direccion;
alter table public.pacientes rename column medical_notes to notas_medicas;
alter table public.pacientes rename column created_at to creado_en;

alter table public.doctores rename column owner_id to propietario_id;
alter table public.doctores rename column full_name to nombre_completo;
alter table public.doctores rename column specialty to especialidad;
alter table public.doctores rename column phone to telefono;
alter table public.doctores rename column created_at to creado_en;

alter table public.citas rename column owner_id to propietario_id;
alter table public.citas rename column patient_id to paciente_id;
alter table public.citas rename column starts_at to inicia_en;
alter table public.citas rename column ends_at to finaliza_en;
alter table public.citas rename column reason to motivo;
alter table public.citas rename column status to estado;
alter table public.citas rename column created_at to creado_en;

alter table public.casos_clinicos rename column owner_id to propietario_id;
alter table public.casos_clinicos rename column patient_id to paciente_id;
alter table public.casos_clinicos rename column treatment_plan to plan_tratamiento;
alter table public.casos_clinicos rename column notes to notas;
alter table public.casos_clinicos rename column created_at to creado_en;

alter table public.recetas rename column owner_id to propietario_id;
alter table public.recetas rename column patient_id to paciente_id;
alter table public.recetas rename column medication to medicamento;
alter table public.recetas rename column instructions to indicaciones;
alter table public.recetas rename column issued_at to emitida_en;

alter table public.informes_laboratorio rename column owner_id to propietario_id;
alter table public.informes_laboratorio rename column patient_id to paciente_id;
alter table public.informes_laboratorio rename column title to titulo;
alter table public.informes_laboratorio rename column result to resultado;
alter table public.informes_laboratorio rename column status to estado;
alter table public.informes_laboratorio rename column created_at to creado_en;

alter table public.seguros rename column owner_id to propietario_id;
alter table public.seguros rename column patient_id to paciente_id;
alter table public.seguros rename column provider_name to aseguradora;
alter table public.seguros rename column policy_number to numero_poliza;
alter table public.seguros rename column coverage_percent to porcentaje_cobertura;
alter table public.seguros rename column created_at to creado_en;

alter table public.facturas rename column owner_id to propietario_id;
alter table public.facturas rename column patient_id to paciente_id;
alter table public.facturas rename column invoice_date to fecha_factura;
alter table public.facturas rename column paid to pagado;
alter table public.facturas rename column status to estado;
alter table public.facturas rename column created_at to creado_en;

alter table public.pagos rename column owner_id to propietario_id;
alter table public.pagos rename column invoice_id to factura_id;
alter table public.pagos rename column payment_date to fecha_pago;
alter table public.pagos rename column amount to monto;
alter table public.pagos rename column method to metodo;
alter table public.pagos rename column notes to notas;
alter table public.pagos rename column created_at to creado_en;

create or replace function public.create_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nombre_completo)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email));
  return new;
end;
$$;


-- Horarios de atencion por doctor para el modulo DentalCare.
create table if not exists public.horarios_doctores (
  id uuid primary key default gen_random_uuid(),
  propietario_id uuid not null default auth.uid() references auth.users(id),
  doctor_id uuid not null references public.doctores(id) on delete cascade,
  dia_semana text not null check (dia_semana in ('Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo')),
  hora_inicio time not null,
  hora_fin time not null,
  duracion_cita integer not null default 30 check (duracion_cita > 0),
  tipo_turno text not null default 'horario' check (tipo_turno in ('secuencial', 'horario')),
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  check (hora_fin > hora_inicio)
);

alter table public.horarios_doctores enable row level security;

create policy horarios_doctores_propios on public.horarios_doctores
  for all to authenticated
  using (propietario_id = auth.uid())
  with check (propietario_id = auth.uid());

create index horarios_doctores_doctor_dia_idx
  on public.horarios_doctores(doctor_id, dia_semana, hora_inicio);


-- Los usuarios existentes se crearon antes de instalar el trigger de perfiles.
insert into public.perfiles (id, nombre_completo, rol)
select id,
       coalesce(raw_user_meta_data ->> 'full_name', email),
       case when lower(email) = 'odontologa.e3@proyecto.test'
            then 'doctor' else 'staff' end
from auth.users
on conflict (id) do nothing;

-- Solo el panel/servidor de administracion puede asignar roles.
drop policy if exists profiles_own_data on public.perfiles;
create policy perfiles_lectura_propia on public.perfiles
  for select to authenticated using (id = auth.uid());
revoke insert, update, delete on public.perfiles from anon, authenticated;
grant select on public.perfiles to authenticated;

commit;

-- Verificacion: debe aparecer la cuenta con rol doctor.
select u.email, p.nombre_completo, p.rol
from public.perfiles p
join auth.users u on u.id = p.id
where lower(u.email) = 'odontologa.e3@proyecto.test';

-- ACTUALIZACION DEL MODELO CLINICO Y PERMISOS
-- Adaptacion del PDF (seccion 2.4.2) y C:\clinica-angular\database.
-- Ejecutar despues de las migraciones anteriores. Conserva los datos existentes.
begin;

create table public.roles (
  id text primary key check (id in ('admin', 'doctor')),
  nombre text not null unique
);
insert into public.roles values ('admin', 'Administrador'), ('doctor', 'Odontologo');

create table public.permisos (
  nombre text primary key,
  recurso text not null,
  accion text not null check (accion in ('read', 'create', 'update', 'delete', 'audit')),
  unique (recurso, accion)
);
create table public.permisos_roles (
  rol_id text not null references public.roles(id) on delete cascade,
  permiso_id text not null references public.permisos(nombre) on delete cascade,
  primary key (rol_id, permiso_id)
);
create table public.permisos_modelos (
  modelo_id uuid not null references public.perfiles(id) on delete cascade,
  permiso_id text not null references public.permisos(nombre) on delete cascade,
  primary key (modelo_id, permiso_id)
);

insert into public.permisos (nombre, recurso, accion)
select recurso || '.' || accion, recurso, accion
from unnest(array['pacientes','doctores','horarios','citas','antecedentes',
  'recetas','radiografias','usuarios','roles','asignaciones',
  'casos_clinicos','informes_laboratorio','seguros','facturas','pagos']) recurso
cross join unnest(array['read','create','update','delete']) accion;
insert into public.permisos values ('radiografias.audit', 'radiografias', 'audit');
insert into public.permisos_roles select 'admin', nombre from public.permisos;
insert into public.permisos_roles
select 'doctor', nombre from public.permisos
where nombre in (
  'pacientes.read','pacientes.create','pacientes.update','pacientes.delete',
  'doctores.read','horarios.read','citas.read',
  'antecedentes.read','antecedentes.create','antecedentes.update','antecedentes.delete',
  'recetas.read','recetas.create','recetas.update','recetas.delete',
  'radiografias.read','radiografias.create','radiografias.update'
);

-- Supabase Auth conserva las credenciales; perfiles conserva un unico rol efectivo.
insert into public.perfiles (id, nombre_completo)
select id, coalesce(raw_user_meta_data ->> 'full_name', email) from auth.users
on conflict (id) do nothing;
update public.perfiles set rol = 'doctor'
where id in (select id from auth.users where lower(email) = 'odontologa.e3@proyecto.test');

alter table public.doctores add column perfil_id uuid unique references public.perfiles(id);
-- Vincular solamente correspondencias de correo inequívocas.
update public.doctores d set perfil_id = u.id
from auth.users u join public.perfiles p on p.id = u.id
where lower(d.email) = lower(u.email) and p.rol = 'doctor'
  and (select count(*) from public.doctores d2 where lower(d2.email) = lower(u.email)) = 1;

create function public.vincular_cuenta_odontologo()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select u.id into new.perfil_id from auth.users u
  join public.perfiles p on p.id = u.id
  where lower(u.email) = lower(new.email) and p.rol = 'doctor';
  return new;
end $$;
revoke all on function public.vincular_cuenta_odontologo() from public, anon, authenticated;
create trigger doctores_vincular_cuenta before insert or update of email on public.doctores
  for each row execute function public.vincular_cuenta_odontologo();

create table public.antecedentes_pacientes (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null unique references public.pacientes(id) on delete cascade,
  alergia_alimentaria text, enfermedad_cardiaca text, hipertension text,
  diabetes text, cirugias text, accidentes text, otros text,
  antecedentes_familiares text, medicacion_actual text, embarazo text,
  lactancia text, seguro_salud text, archivo text,
  creado_en timestamptz not null default now()
);
create table public.pacientes_odontologos (
  paciente_id uuid not null references public.pacientes(id) on delete cascade,
  odontologo_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key (paciente_id, odontologo_id)
);
create index pacientes_odontologos_odontologo_idx
  on public.pacientes_odontologos(odontologo_id, paciente_id);

create table public.solicitudes_radiografias (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references public.pacientes(id) on delete restrict,
  odontologo_id uuid not null default auth.uid() references public.perfiles(id),
  tipo varchar(150) not null check (length(trim(tipo)) > 0),
  indicaciones varchar(2000) not null default '',
  estado text not null default 'Pendiente' check (estado in ('Pendiente','Completada','Cancelada')),
  creado_en timestamptz not null default now(),
  completado_en timestamptz
);
create index solicitudes_radiografias_paciente_idx
  on public.solicitudes_radiografias(paciente_id, odontologo_id);
create table public.accesos_radiografias (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes_radiografias(id) on delete cascade,
  token_hash text not null unique,
  vence_en timestamptz not null,
  revocado_en timestamptz, usado_en timestamptz, storage_path text,
  creado_en timestamptz not null default now()
);
create table public.radiografias (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null unique references public.solicitudes_radiografias(id),
  nombre text not null,
  tipo text not null check (tipo in ('application/pdf','image/png','image/jpeg','image/webp')),
  tamano bigint not null check (tamano > 0 and tamano <= 52428800),
  storage_path text not null unique,
  sha256 text,
  creado_en timestamptz not null default now()
);
create table public.eventos_radiografias (
  id bigint generated always as identity primary key,
  solicitud_id uuid not null references public.solicitudes_radiografias(id),
  usuario_id uuid references public.perfiles(id),
  evento text not null,
  creado_en timestamptz not null default now()
);
create table public.notificaciones_radiografias (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes_radiografias(id),
  usuario_id uuid not null references public.perfiles(id),
  creado_en timestamptz not null default now(),
  leido_en timestamptz,
  unique(solicitud_id, usuario_id)
);

create function public.tiene_permiso(permiso text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.perfiles p where p.id = auth.uid()
    and p.rol in ('admin','doctor') and (
      exists (select 1 from public.permisos_roles pr
              where pr.rol_id = p.rol and pr.permiso_id = permiso)
      or exists (select 1 from public.permisos_modelos pm
                 where pm.modelo_id = p.id and pm.permiso_id = permiso)
    )
  );
$$;
create function public.es_administrador()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and rol = 'admin');
$$;
create function public.puede_ver_paciente(paciente uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.es_administrador() or (
    public.tiene_permiso('pacientes.read') and (
      exists (select 1 from public.pacientes p where p.id = paciente and p.propietario_id = auth.uid())
      or exists (select 1 from public.pacientes_odontologos po
                 where po.paciente_id = paciente and po.odontologo_id = auth.uid())
    )
  );
$$;
create function public.puede_ver_cita(paciente uuid, doctor uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.es_administrador() or (
    public.puede_ver_paciente(paciente) and exists (
      select 1 from public.doctores d where d.id = doctor and d.perfil_id = auth.uid()
    )
  );
$$;
create function public.puede_ver_solicitud(solicitud uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.es_administrador() or exists (
    select 1 from public.solicitudes_radiografias s
    where s.id = solicitud and s.odontologo_id = auth.uid()
      and public.puede_ver_paciente(s.paciente_id)
      and public.tiene_permiso('radiografias.read')
  );
$$;
create function public.mi_acceso()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('rol', coalesce(p.rol, ''), 'permisos', coalesce((
    select jsonb_agg(nombre order by nombre) from public.permisos
    where public.tiene_permiso(nombre)
  ), '[]'::jsonb))
  from (select 1) dummy left join public.perfiles p on p.id = auth.uid();
$$;

-- Cada funcion usa exclusivamente la identidad autenticada, sin aceptar otro usuario.
revoke all on function public.tiene_permiso(text), public.es_administrador(),
  public.puede_ver_paciente(uuid), public.puede_ver_cita(uuid,uuid),
  public.puede_ver_solicitud(uuid), public.mi_acceso() from public, anon;
grant execute on function public.tiene_permiso(text), public.es_administrador(),
  public.puede_ver_paciente(uuid), public.puede_ver_cita(uuid,uuid),
  public.puede_ver_solicitud(uuid), public.mi_acceso() to authenticated;

-- Reemplazar las politicas anteriores: combinarlas permitiria saltarse los permisos.
do $$ declare r record; begin
  for r in select tablename, policyname from pg_policies
    where schemaname = 'public' and tablename in (
      'perfiles','pacientes','doctores','horarios_doctores','citas','casos_clinicos',
      'recetas','informes_laboratorio','seguros','facturas','pagos'
    )
  loop execute format('drop policy %I on public.%I', r.policyname, r.tablename); end loop;
end $$;

alter table public.perfiles enable row level security;
revoke all on public.perfiles from anon, authenticated;
grant select on public.perfiles to authenticated;
create policy perfiles_lectura on public.perfiles for select to authenticated
  using (id = auth.uid() or public.es_administrador());
-- Las asignaciones de rol se hacen desde SQL Editor, no por update del cliente.

do $$ declare tabla text; begin
  foreach tabla in array array['roles','permisos','permisos_roles','permisos_modelos',
    'antecedentes_pacientes','pacientes_odontologos','solicitudes_radiografias',
    'accesos_radiografias','radiografias','eventos_radiografias','notificaciones_radiografias']
  loop
    execute format('alter table public.%I enable row level security', tabla);
    execute format('revoke all on public.%I from anon, authenticated', tabla);
  end loop;
end $$;
grant select on public.roles, public.permisos, public.permisos_roles, public.permisos_modelos to authenticated;
create policy roles_lectura on public.roles for select to authenticated using (true);
create policy permisos_lectura on public.permisos for select to authenticated using (true);
create policy permisos_roles_lectura on public.permisos_roles for select to authenticated using (true);
create policy permisos_modelos_lectura on public.permisos_modelos for select to authenticated
  using (modelo_id = auth.uid() or public.es_administrador());

grant select, insert, update, delete on public.pacientes, public.doctores,
  public.horarios_doctores, public.citas, public.antecedentes_pacientes,
  public.pacientes_odontologos, public.solicitudes_radiografias, public.radiografias,
  public.casos_clinicos, public.recetas, public.informes_laboratorio,
  public.seguros, public.facturas, public.pagos to authenticated;

create policy pacientes_leer on public.pacientes for select to authenticated
  using (public.tiene_permiso('pacientes.read') and public.puede_ver_paciente(id));
create policy pacientes_crear on public.pacientes for insert to authenticated
  with check (public.tiene_permiso('pacientes.create') and propietario_id = auth.uid());
create policy pacientes_editar on public.pacientes for update to authenticated
  using (public.tiene_permiso('pacientes.update') and public.puede_ver_paciente(id))
  with check (public.tiene_permiso('pacientes.update') and public.puede_ver_paciente(id));
create policy pacientes_eliminar on public.pacientes for delete to authenticated
  using (public.tiene_permiso('pacientes.delete') and public.puede_ver_paciente(id));

create function public.conservar_propietario() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.propietario_id is distinct from old.propietario_id then
    raise exception 'No se puede cambiar el propietario del registro';
  end if;
  return new;
end $$;
create trigger pacientes_conservar_propietario before update on public.pacientes
  for each row execute function public.conservar_propietario();

create policy asignaciones_leer on public.pacientes_odontologos for select to authenticated
  using (public.es_administrador() or odontologo_id = auth.uid());
create policy asignaciones_administrar on public.pacientes_odontologos for all to authenticated
  using (public.es_administrador()) with check (public.es_administrador());

-- Los odontologos consultan profesionales y horarios; solo admin los modifica.
create policy doctores_leer on public.doctores for select to authenticated
  using (public.tiene_permiso('doctores.read'));
create policy doctores_administrar on public.doctores for all to authenticated
  using (public.es_administrador()) with check (public.es_administrador());
create policy horarios_leer on public.horarios_doctores for select to authenticated
  using (public.tiene_permiso('horarios.read'));
create policy horarios_administrar on public.horarios_doctores for all to authenticated
  using (public.es_administrador()) with check (public.es_administrador());
create policy citas_leer on public.citas for select to authenticated
  using (public.tiene_permiso('citas.read') and public.puede_ver_cita(paciente_id, doctor_id));
create policy citas_administrar on public.citas for all to authenticated
  using (public.es_administrador()) with check (public.es_administrador());

-- Antecedentes y recetas: operaciones por permiso y dentro del ambito del paciente.
do $$ declare tabla text; recurso text; accion text; operacion text; condicion text; begin
  for tabla, recurso in select * from (values
    ('antecedentes_pacientes','antecedentes'), ('recetas','recetas')
  ) mapping(tabla, recurso)
  loop
    foreach accion in array array['read','create','update','delete'] loop
      operacion := case accion when 'read' then 'select' when 'create' then 'insert'
        when 'update' then 'update' else 'delete' end;
      condicion := format('public.tiene_permiso(%L) and public.puede_ver_paciente(paciente_id)', recurso || '.' || accion);
      execute format('create policy %I on public.%I for %s to authenticated %s %s',
        tabla || '_' || accion, tabla, operacion,
        case when accion = 'create' then '' else 'using (' || condicion || ')' end,
        case when accion in ('create','update') then 'with check (' || condicion || ')' else '' end);
    end loop;
  end loop;
end $$;

-- Modulos retirados del menu actual, conservados para no destruir datos historicos.
do $$ declare tabla text; begin
  foreach tabla in array array['casos_clinicos','informes_laboratorio','seguros','facturas','pagos'] loop
    execute format('create policy %I on public.%I for all to authenticated using (public.es_administrador()) with check (public.es_administrador())', tabla || '_solo_admin', tabla);
  end loop;
end $$;

create policy solicitudes_leer on public.solicitudes_radiografias for select to authenticated
  using (public.tiene_permiso('radiografias.read') and public.puede_ver_solicitud(id));
create policy solicitudes_crear on public.solicitudes_radiografias for insert to authenticated
  with check (public.tiene_permiso('radiografias.create')
    and odontologo_id = auth.uid() and public.puede_ver_paciente(paciente_id));
create policy solicitudes_editar on public.solicitudes_radiografias for update to authenticated
  using (public.tiene_permiso('radiografias.update') and public.puede_ver_solicitud(id))
  with check (public.tiene_permiso('radiografias.update') and public.puede_ver_paciente(paciente_id)
    and (public.es_administrador() or odontologo_id = auth.uid()));
-- No se permite borrar solicitudes ni archivos: se conserva la trazabilidad.
create policy radiografias_leer on public.radiografias for select to authenticated
  using (public.tiene_permiso('radiografias.read') and public.puede_ver_solicitud(solicitud_id));
create policy radiografias_registrar on public.radiografias for insert to authenticated
  with check (public.tiene_permiso('radiografias.update') and public.puede_ver_solicitud(solicitud_id)
    and split_part(storage_path, '/', 1) = solicitud_id::text);

grant select on public.eventos_radiografias, public.notificaciones_radiografias to authenticated;
grant update(leido_en) on public.notificaciones_radiografias to authenticated;
create policy eventos_auditoria on public.eventos_radiografias for select to authenticated
  using (public.tiene_permiso('radiografias.audit'));
create policy notificaciones_propias on public.notificaciones_radiografias for select to authenticated
  using (usuario_id = auth.uid() and public.puede_ver_solicitud(solicitud_id));
create policy notificaciones_leidas on public.notificaciones_radiografias for update to authenticated
  using (usuario_id = auth.uid() and public.puede_ver_solicitud(solicitud_id))
  with check (usuario_id = auth.uid() and public.puede_ver_solicitud(solicitud_id));

create function public.auditar_radiografia()
returns trigger language plpgsql security definer set search_path = '' as $$
declare solicitud uuid; destinatario uuid;
begin
  if tg_table_name = 'radiografias' then
    solicitud := new.solicitud_id;
  else
    solicitud := new.id;
  end if;
  insert into public.eventos_radiografias(solicitud_id, usuario_id, evento)
    values (solicitud, auth.uid(), tg_table_name || '.' || lower(tg_op));
  if tg_table_name = 'radiografias' then
    select odontologo_id into destinatario from public.solicitudes_radiografias where id = solicitud;
    insert into public.notificaciones_radiografias(solicitud_id, usuario_id)
      values (solicitud, destinatario) on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.auditar_radiografia() from public, anon, authenticated;
create trigger solicitudes_auditar after insert or update on public.solicitudes_radiografias
  for each row execute function public.auditar_radiografia();
create trigger radiografias_auditar after insert on public.radiografias
  for each row execute function public.auditar_radiografia();

-- Nombres equivalentes del documento; las vistas respetan RLS de sus tablas base.
create view public.usuarios with (security_invoker = true) as
  select id, nombre_completo as nombre, rol, creado_en from public.perfiles;
create view public.roles_modelos with (security_invoker = true) as
  select rol as rol_id, id as modelo_id from public.perfiles where rol in ('admin','doctor');
create view public.detalles_medicos with (security_invoker = true) as select * from public.doctores;
create view public.horarios_medicos with (security_invoker = true) as select * from public.horarios_doctores;
create view public.citas_pacientes with (security_invoker = true) as select * from public.citas;
grant select on public.usuarios, public.roles_modelos, public.detalles_medicos,
  public.horarios_medicos, public.citas_pacientes to authenticated;
revoke all on public.usuarios, public.roles_modelos, public.detalles_medicos,
  public.horarios_medicos, public.citas_pacientes from anon;

-- Bucket privado. Los enlaces temporales externos requieren un backend/Edge Function.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('radiografias', 'radiografias', false, 52428800,
  array['application/pdf','image/png','image/jpeg','image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
create policy clinica_radiografias_leer on storage.objects for select to authenticated
  using (bucket_id = 'radiografias' and exists (
    select 1 from public.radiografias r where r.storage_path = name
      and public.puede_ver_solicitud(r.solicitud_id)
  ));
create policy clinica_radiografias_cargar on storage.objects for insert to authenticated
  with check (bucket_id = 'radiografias' and public.tiene_permiso('radiografias.update')
    and exists (select 1 from public.solicitudes_radiografias s
                where s.id::text = split_part(name, '/', 1) and public.puede_ver_solicitud(s.id)));

notify pgrst, 'reload schema';
commit;


-- VISOR MOVIL: RADIOGRAFIAS EN SOLO LECTURA
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
