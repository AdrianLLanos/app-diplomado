# Integración con el sistema web

Flutter utiliza la misma API Node.js que Angular, cuyo código se encuentra en
`C:\clinica-angular\backend\src`. La API es quien accede a PostgreSQL y al
almacenamiento privado de Supabase. No se copia el servidor dentro del APK.

Dirección configurada en `config/web-api.json`:

```text
https://proyecto-diplomado-angular-frontend.vercel.app/api/v1
```

## Acceso y datos

- Iniciar sesión con el correo y contraseña del sistema web, con rol
  `Super Admin` o `Doctor`. No se utiliza Supabase Authentication ni `mi_acceso()`.
- La API devuelve la empresa inicial autorizada. Las consultas siguientes envían
  `Authorization: Bearer ...` y `X-Company-ID`, igual que Angular.
- El token permanece en memoria; al cerrar y abrir la app se inicia sesión otra
  vez. Al expirar la sesión se vuelve al inicio de sesión. Cerrar sesión en el
  móvil descarta su token localmente.
- Pacientes, odontólogos, horarios y citas usan las rutas y los campos reales de
  la web. Las listas recorren todas las páginas, de forma secuencial.
- El nombre de paciente se guarda en `nombre`. El correo es obligatorio.
  El backend web no tiene los antiguos campos móviles de documento y notas
  médicas; por eso ya no se ofrecen en el formulario.
- Las citas eligen su intervalo en `/slots`. El servidor comprueba los cruces,
  las asignaciones, los permisos y los horarios. La web no tiene un estado de
  confirmación/cancelación de citas, por lo que no se envían estados ficticios.
- Antecedentes, recetas, usuarios y roles consultan registros reales en modo
  lectura. Sus editores y las asignaciones de pacientes se gestionan en Angular.
- El selector de empresas de Angular no se replica aún: la app utiliza la
  primera empresa autorizada que devuelve `/session`.

## Radiografías y CERPAX

1. El administrador asigna el paciente al odontólogo desde Angular.
2. En Flutter: Radiografías → Solicitar radiografía → Crear solicitud.
3. Sobre la solicitud pendiente: Enlace / QR CERPAX. Se genera un acceso de
   24 horas; el servidor revoca cualquier acceso anterior para esa solicitud.
4. Copiar el enlace y compartirlo con CERPAX. No se envían mensajes automáticamente.
5. CERPAX abre la página web existente y carga el estudio.
6. Actualizar la lista en Flutter o deslizar hacia abajo para consultar el
   resultado. No hay sincronización en segundo plano ni Realtime.
7. Las imágenes se visualizan con zoom. Los PDF se guardan para abrirlos con un
   visor del teléfono. También se pueden guardar las imágenes.

El archivo se obtiene con la API autenticada. Si la API devuelve una redirección
al almacenamiento privado, el cliente sigue el enlace HTTPS firmado sin reenviar
el token de la API. También admite los archivos que la API devuelve directamente
desde PostgreSQL. Nunca se construye una URL pública ni se agrega el token a la URL.

## Ejecutar y compilar Android

```powershell
flutter pub get
flutter run --dart-define-from-file=config/web-api.json
flutter build apk --release --dart-define-from-file=config/web-api.json
```

Salida: `build\app\outputs\flutter-apk\app-release.apk`.

La URL pública también es el valor predeterminado de `AppConfig`. Para cambiarla,
usar `API_BASE_URL` en un archivo de configuración o como `--dart-define`.
No incluir `DATABASE_URL`, `JWT_SECRET`, contraseñas de PostgreSQL ni claves
`service_role` en Flutter. Los valores anteriores `SUPABASE_URL` y
`SUPABASE_PUBLISHABLE_KEY` ya no intervienen en la conexión de esta app.

La configuración Android existente usa una firma de depuración incluso para
release; configurar una firma propia antes de una distribución definitiva.

## Alcance de la verificación

Las pruebas de contrato usan un transporte HTTP simulado y no crean pacientes,
cuentas ni solicitudes en producción. Para comprobar el recorrido completo,
iniciar sesión con una cuenta autorizada y realizar una solicitud de prueba
identificada como tal. No se han copiado credenciales del backend.

Verificación del 27/10/2026: las 21 pruebas de Flutter finalizaron correctamente.
La API pública respondió `200 {"ok":true}` en `/salud` y `401` en `/session`
sin credenciales. Esto verifica la disponibilidad y la exigencia de sesión;
no sustituye la prueba completa de inicio de sesión, solicitud y carga de CERPAX.
El APK actualizado se generó posteriormente como `DentalCare-1.1.0-api-web.apk`.
Ver [instalación y detalles de la compilación](INSTALAR_APK_1_1_0.md).

Esta integración se dirige a la APK Android. Flutter Web tendría un origen
distinto del de Angular; requiere configurar CORS y las solicitudes OPTIONS
en el backend antes de publicarla en otro dominio.

No ejecutar los instaladores SQL antiguos de este proyecto Flutter sobre la
base del sistema Angular: describen un esquema diferente. No hace falta aplicar
nuevas migraciones a la base web para esta integración.
