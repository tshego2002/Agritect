@echo off
setlocal
cd /d "%~dp0"
if defined SSL_CERT_FILE if not exist "%SSL_CERT_FILE%" set SSL_CERT_FILE=
if defined REQUESTS_CA_BUNDLE if not exist "%REQUESTS_CA_BUNDLE%" set REQUESTS_CA_BUNDLE=
if defined PIP_CERT if not exist "%PIP_CERT%" set PIP_CERT=
echo ==== Agritect - laptop test (Windows) ====
echo.

set PY=
py -3 --version >nul 2>nul
if not errorlevel 1 set PY=py -3
if "%PY%"=="" (
  python --version >nul 2>nul
  if not errorlevel 1 set PY=python
)
if "%PY%"=="" (
  echo Python is not installed on this laptop yet.
  echo   1. Go to  python.org/downloads  and install the latest Python.
  echo   2. IMPORTANT: tick "Add python.exe to PATH" on the first screen.
  echo   3. Close this window and double-click this file again.
  echo.
  pause
  exit /b 1
)

if not exist pi\server\.venv (
  echo Setting up a private Python workspace...
  %PY% -m venv pi\server\.venv
)
set VPY=pi\server\.venv\Scripts\python.exe
"%VPY%" -m pip install --quiet --upgrade pip
echo Installing the app's building blocks (first time: a few minutes)...
"%VPY%" -m pip install --quiet -r pi\server\requirements.txt -r laptop\requirements.txt
if errorlevel 1 goto fail
"%VPY%" -c "import sysconfig,pathlib;(pathlib.Path(sysconfig.get_paths()['purelib'])/'zz_truststore.pth').write_text('import truststore; truststore.inject_into_ssl()\n')"

if not exist pi\server\model\efficientnet_v2_s_best.onnx (
  echo Downloading the AI model, about 85 MB - internet needed...
  "%VPY%" laptop\01_download_model.py
  if errorlevel 1 goto fail
)

echo Checking voice clips and plan cards - first time 10 to 20 minutes, later runs only add what is missing.
echo Lots of text may scroll past. Leave this window alone.
"%VPY%" laptop\02_build_content.py
if errorlevel 1 echo Some clips could not be generated - the app will use the built-in voice for those.

echo.
echo =====================================================
echo   Agritect is starting at  http://localhost:8000
echo   A browser tab will open by itself.
echo   If Windows asks about the firewall, click ALLOW
echo   (only needed if you also want to test from a phone).
echo   To stop the app: close this window.
echo =====================================================
start "" http://localhost:8000
"%VPY%" -m uvicorn app:app --host 0.0.0.0 --port 8000 --app-dir pi\server
goto :eof

:fail
echo.
echo Something failed above. Check the internet connection, then
echo double-click this file again - it continues where it stopped.
pause
