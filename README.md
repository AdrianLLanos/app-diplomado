# DentalCare

La app Android utiliza ahora la API del sistema Angular y su base de Supabase.
Ver [integración, acceso y compilación del APK](docs/INTEGRACION_API_WEB.md).
La configuración actual es `config/web-api.json`; no ejecutar los instaladores
SQL antiguos de Flutter sobre la base del sistema web.

```powershell
flutter run --dart-define-from-file=config/web-api.json
flutter build apk --release --dart-define-from-file=config/web-api.json
```

Las instrucciones siguientes corresponden a la conexión directa anterior y a
la demostración local de PNG.

La demostracion actual permite cargar, visualizar y descargar un PNG en Chrome y Android.
Ver [pasos de la demostracion local](docs/DEMO_PNG_LOCAL.md).

Aplicacion Flutter para la gestion de clinicas dentales, conectada con Supabase.

## Configuracion

1. Crea un proyecto en Supabase.
2. Ejecuta la migracion con la CLI de Supabase o su contenido en SQL Editor.
3. Crea el usuario autorizado en **Authentication > Users** con el correo indicado.
4. En Windows, prepara el proyecto solo la primera vez:

```powershell
scripts\00_PREPARAR_WINDOWS.bat
```

5. Para levantar la aplicacion en cada ejecucion, usa el menu:

```powershell
scripts\01_MENU_WINDOWS.bat
```

En el menu elige `2. Supabase - Chrome`. El menu inicia Flutter con
`config/local.json` mediante `--dart-define-from-file=config/local.json`.

No uses la clave `service_role` dentro de Flutter.

## Roles y modelo clinico

Para una base vacia, ejecutar una sola vez `scripts/03_INSTALAR_SUPABASE.sql`.
Si el instalador anterior ya se ejecuto, aplicar solamente la nueva migracion
`supabase/migrations/20261012090000_roles_y_modelo_clinico.sql`.
El inicio de sesion requiere esa migracion para consultar `mi_acceso()`.
Ver [tablas, permisos y pasos de asignacion](docs/MODELO_Y_PERMISOS.md).

Para visualizar una radiografia sin sincronizar con la web, seguir
[la prueba del visor movil](docs/PROBAR_VISOR_RADIOGRAFIAS.md).
Si las tablas y roles ya estan instalados, aplicar solamente
`supabase/migrations/20261012100000_radiografias_solo_lectura_odontologo.sql`.
