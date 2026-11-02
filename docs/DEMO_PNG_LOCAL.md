# Demostracion Chrome y Android: cargar, visualizar y descargar PNG

El acceso Radiografias del menu y de la ficha del paciente abre ahora una pantalla
local de demostracion. No necesita la API web ni cargar objetos en Supabase.
El inicio de sesion y los permisos existentes siguen usando Supabase.

1. En Chrome, ejecutar `flutter run -d chrome --dart-define-from-file=config/local.json`.
   En Android, instalar la APK. Iniciar sesion con la odontologa.
2. Abrir Odontologo > Visualizar radiografias.
3. Pulsar Cargar PNG y seleccionar una imagen desde la computadora o el telefono.
4. En Chrome, ampliar con la rueda del mouse; en Android, con dos dedos. Arrastrar para mover.
5. Pulsar Descargar. Chrome inicia la descarga del PNG segun la configuracion del
   navegador; Android permite elegir una carpeta, por ejemplo Downloads.

El selector de Android concede acceso al archivo elegido sin permisos generales
de almacenamiento. Cancelar la seleccion conserva la imagen anterior. Solo se
aceptan archivos PNG de hasta 50 MB. La imagen se mantiene en memoria durante esa
pantalla; al salir hay que seleccionarla de nuevo. Abrir desde una ficha muestra
el nombre del paciente como contexto, sin guardar una asociacion en la base.

El visor de Supabase queda conservado en el codigo para retomarlo posteriormente,
pero el menu de esta demostracion abre el visor local. No hace falta ejecutar
las migraciones o scripts de carga manual para esta demostracion.
