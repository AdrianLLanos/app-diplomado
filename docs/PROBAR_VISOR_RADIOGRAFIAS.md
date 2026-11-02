# Ver una radiografia en el movil sin sincronizar con la web

Esta prueba usa exclusivamente el Supabase configurado en `config/local.json`.
No consulta la API web ni representa una entrega real de CERPAX.

## 1. Aplicar el permiso de consulta

Como ya estan instaladas las tablas, copiar todo el contenido de
`supabase/migrations/20261012100000_radiografias_solo_lectura_odontologo.sql`
en SQL Editor y ejecutar. Puede volver a ejecutarse. Debe mostrar solamente
`radiografias.read` para Odontologo. No ejecutar de nuevo el instalador completo.

La app permite visualizar archivos, sin botones de carga, solicitudes o edicion.
Las politicas tambien impiden esas escrituras al odontologo. Se pueden ver estudios
de pacientes propios o asignados aunque el archivo lo haya registrado otra persona.

## 2. Preparar una prueba sin datos personales

Ejecutar UNA VEZ `scripts/05_PREPARAR_RADIOGRAFIA_PRUEBA.sql` en SQL Editor.
Crea un paciente ficticio vinculado a `odontologa.e3@proyecto.test` y una solicitud
pendiente. El resultado muestra `solicitud_id` y `ruta_para_subir`.
Conservar esos valores. Si se repite, creara otro paciente/solicitud de prueba.

Para usar pacientes reales ya existentes, crear la solicitud en Table Editor con
su `paciente_id`, el `odontologo_id` de perfiles y el tipo de estudio. El odontologo
debe ser propietario del paciente o estar vinculado en `pacientes_odontologos`.

## 3. Subir un archivo de prueba

1. Abrir Storage, bucket **radiografias**, que debe permanecer privado.
2. Crear una carpeta con el UUID de `solicitud_id`.
3. Subir dentro un JPG llamado `estudio.jpg` desde tu equipo.
   Tambien se admiten PNG, WebP y PDF (hasta 50 MB), conservando su extension.
4. La ruta del objeto debe ser `UUID_DE_LA_SOLICITUD/estudio.jpg`.
   No es una URL y no incluye el nombre del bucket.

El visor presenta el archivo recibido. No crea ni interpreta estudios medicos.

## 4. Registrar el archivo en las tablas

Abrir `scripts/06_REGISTRAR_ARCHIVO_RADIOGRAFIA.sql` y reemplazar
`UUID_DE_LA_SOLICITUD/estudio.jpg` por la ruta exacta del objeto subido.
Copiar el SQL completo en SQL Editor y ejecutar una vez. El script comprueba que
el objeto exista, lee su tipo/tamano, crea el registro y completa la solicitud.
La auditoria y notificacion se generan mediante los triggers existentes.

Subir el objeto a Storage no basta: tambien debe existir su registro en
`public.radiografias`, enlazado a la solicitud correcta.

## 5. Abrir desde la app actualizada

```powershell
flutter run --dart-define-from-file=config/local.json
```

Cerrar sesion y volver a entrar con la odontologa para renovar permisos.
Ir a **Odontologo > Visualizar radiografias** y pulsar **Visualizar radiografia**.
Tambien existe un acceso desde la ficha del paciente, filtrado por su ID.
Deslizar hacia abajo actualiza la lista; incluye paginacion para mas de 25 estudios.

- JPG/PNG/WebP: se muestran dentro de la app, con zoom y desplazamiento.
- PDF: pulsar **Abrir PDF**; se usa el visor o navegador del telefono.
- Sin archivo registrado: aparece **Radiografia pendiente**.
- Error de carga: **Reintentar** genera un enlace nuevo.

Se crean URLs privadas de acceso de 60 segundos al abrir el estudio. La politica
de Storage comprueba el acceso del usuario antes de emitir el enlace, segun la
[documentacion de Supabase](https://supabase.com/docs/reference/dart/v1/storage-from-createsignedurl).
Los PDF se abren mediante [url_launcher](https://pub.dev/packages/url_launcher/versions/6.3.2/example).

Una APK anterior no contiene este visor: hay que volver a compilarla para instalarlo.
La validacion automatizada comprueba permisos y estados de pantalla con datos de
prueba; la apertura de un archivo real requiere completar estos pasos en Supabase
y probar en un dispositivo.
