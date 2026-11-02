# DentalCare 1.1.0 — APK conectado al sistema web

Actualización: instalar `Clinica-San-Martin-1.1.1.apk`, versión 1.1.1, código 3.
Esta versión muestra **Clínica San Martín** en el teléfono y dentro de la app.
Puede instalarse como actualización del APK 1.1.0 generado en este proyecto.
Su nombre y firma se comprobaron con las herramientas Android. El resto de las
instrucciones de instalación y conexión de este documento sigue siendo aplicable.

Archivo: `DentalCare-1.1.0-api-web.apk`, en la raíz del proyecto.

- Versión: 1.1.0, código 2.
- Android mínimo: 7.0 (API 24).
- Arquitecturas: arm64-v8a, armeabi-v7a y x86_64, en un solo APK.
- Conexión: API HTTPS del sistema Angular; datos compartidos en Supabase.
- Firma: Android Debug, verificada con apksigner (esquema v2).
- Compilación Flutter release; optimización adicional R8 desactivada para esta
  entrega local. La configuración predeterminada mantiene R8 habilitado.

## Instalar

1. Copiar el APK al teléfono por USB, Drive o un enlace de descarga.
2. Abrir el archivo desde el teléfono y autorizar la instalación desde la fuente
   utilizada si Android lo solicita.
3. Instalar y abrir DentalCare (`dental_care`).
4. Iniciar sesión con el mismo correo y contraseña del sistema web, con rol
   Administrador u Odontólogo. Se necesita Internet.

El paquete conserva `bo.edu.uajms.dental_care`. Si la versión instalada está
firmada con el mismo certificado, Android podrá actualizarla. Si Android informa
de un conflicto de firmas, retirar la instalación anterior antes de instalar
este APK; esto elimina los datos locales de esa instalación. Los registros
guardados en el backend web permanecen en el servidor.

## Probar radiografías

Odontólogo → Visualizar radiografías → Solicitar radiografía. Elegir un paciente
asignado, crear la solicitud y generar Enlace / QR CERPAX. Copiar el enlace,
enviarlo por WhatsApp y abrirlo sin sesión para simular la carga de CERPAX.
Actualizar la lista en el móvil para consultar el resultado.

El APK y su firma se verificaron el 27/10/2026. La instalación en un teléfono y
el recorrido autenticado completo con CERPAX todavía requieren una prueba manual.
La firma actual es para pruebas; usar una clave propia para distribución definitiva.

## Reproducir esta compilación con bajo consumo de CPU

Desde la raíz del proyecto, después de instalar las dependencias:

```powershell
$env:ORG_GRADLE_PROJECT_optimizeRelease = 'false'
try {
  flutter build apk --release --no-pub --target=C:/PROYECTO_APP_DIPLOMADO/lib/main.dart --dart-define-from-file=config/web-api.json --build-name=1.1.0 --build-number=2
} finally {
  Remove-Item Env:ORG_GRADLE_PROJECT_optimizeRelease -ErrorAction SilentlyContinue
}
```

Gradle utiliza un trabajador y no ejecuta tareas en paralelo. No iniciar otra
compilación ni validación mientras este comando esté activo.
