@echo off
setlocal
cd /d "%~dp0\.."

:menu
cls
echo ============================================================
echo DENTALCARE - MENU WINDOWS
echo ============================================================
echo 1. API web - elegir dispositivo
echo 2. API web - Chrome
echo 3. Ver dispositivos
echo 4. Crear configuracion local
echo 0. Salir
echo ============================================================
set /p "option=Opcion: "

if "%option%"=="1" goto :run_device
if "%option%"=="2" goto :run_chrome
if "%option%"=="3" flutter devices
if "%option%"=="4" call scripts\02_CREAR_CONFIG_WINDOWS.bat
if "%option%"=="0" exit /b 0

echo.
pause
goto menu

:run_device
if not exist config\local.json goto :missing_config
flutter run --dart-define-from-file=config/local.json
goto :after_run

:run_chrome
if not exist config\local.json goto :missing_config
flutter run -d chrome --dart-define-from-file=config/local.json
goto :after_run

:missing_config
echo.
echo No existe config\local.json.
echo Selecciona la opcion 4 para crearlo y agrega la direccion API_BASE_URL del sistema web.

:after_run
echo.
pause
goto menu
