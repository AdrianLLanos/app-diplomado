@echo off
setlocal
cd /d "%~dp0\.."

if not exist config\local.json (
  copy config\local.example.json config\local.json >nul
)

echo config\local.json listo.
echo Verifica API_BASE_URL del sistema web.
pause
