@echo off
rem NBRL - Etapa D: copia el EA a MT5, compila, ejecuta los autotests y una
rem prueba corta en el Strategy Tester (solo analisis). No abre operaciones.
rem Uso: cierra MT5 y haz doble clic en este archivo.
setlocal
set "MT5=C:\Program Files\MetaTrader 5"
set "DATA=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
set "COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files"
set "HERE=%~dp0"
for %%I in ("%HERE%..\..") do set "REPO=%%~fI"
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm"') do set "STAMP=%%T"
set "OUT=%REPO%\results\%STAMP%_D0_smoke"

tasklist /fi "imagename eq terminal64.exe" | find /i "terminal64.exe" >nul
if not errorlevel 1 (
  echo MT5 esta abierto. Cierralo y vuelve a ejecutar este archivo.
  pause & exit /b 1
)
mkdir "%OUT%" 2>nul

echo [1/5] Copiando el EA a la carpeta de datos de MT5...
xcopy /e /i /y "%REPO%\MQL5\Include\NBRL" "%DATA%\MQL5\Include\NBRL" >nul
xcopy /e /i /y "%REPO%\MQL5\Experts\NBRL" "%DATA%\MQL5\Experts\NBRL" >nul
xcopy /e /i /y "%REPO%\MQL5\Scripts\NBRL" "%DATA%\MQL5\Scripts\NBRL" >nul
mkdir "%DATA%\MQL5\Profiles\Tester" 2>nul
copy /y "%REPO%\presets\*.set" "%DATA%\MQL5\Profiles\Tester\" >nul

echo [2/5] Compilando...
"%MT5%\metaeditor64.exe" /compile:"%DATA%\MQL5\Experts\NBRL\NasdaqBreakoutReversalLab.mq5" /inc:"%DATA%\MQL5" /log:"%OUT%\compile_ea.log"
"%MT5%\metaeditor64.exe" /compile:"%DATA%\MQL5\Scripts\NBRL\NBRL_SelfTests.mq5" /inc:"%DATA%\MQL5" /log:"%OUT%\compile_selftests.log"
powershell -NoProfile -Command "if ((Select-String -Path '%OUT%\compile_ea.log','%OUT%\compile_selftests.log' -Pattern ' 0 errors').Count -eq 2) { exit 0 } else { exit 1 }"
if errorlevel 1 (
  echo La compilacion fallo. Revisa los logs en %OUT%
  pause & exit /b 1
)

echo [3/5] Ejecutando autotests (MT5 se abre y se cierra solo)...
start "" /wait "%MT5%\terminal64.exe" /config:"%HERE%selftests.ini"
powershell -NoProfile -Command "Get-ChildItem '%DATA%\MQL5\Logs\*.log' | Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content | Select-String 'NBRL_SelfTests|OK   |FAIL |NBRL autotests' | ForEach-Object { $_.Line } | Set-Content '%OUT%\autotests.txt'"
type "%OUT%\autotests.txt"

echo [4/5] Prueba corta en el Strategy Tester (USTECm, ene-mar 2024, solo analisis)...
if exist "%COMMON%\NBRL" move "%COMMON%\NBRL" "%COMMON%\NBRL_antes_%STAMP%" >nul
start "" /wait "%MT5%\terminal64.exe" /config:"%HERE%d0_smoke.ini"

echo [5/5] Guardando informe, logs y CSV en %OUT%
copy /y "%DATA%\NBRL_D0_smoke.*" "%OUT%\" >nul 2>&1
xcopy /e /i /y "%COMMON%\NBRL" "%OUT%\csv" >nul 2>&1
for /d %%A in ("%APPDATA%\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-*") do xcopy /i /y "%%A\logs\*.log" "%OUT%\tester_logs" >nul 2>&1
xcopy /i /y "%DATA%\logs\*.log" "%OUT%\terminal_logs" >nul 2>&1
xcopy /i /y "%DATA%\MQL5\Logs\*.log" "%OUT%\mql5_logs" >nul 2>&1
for /d %%C in ("%OUT%\csv\*") do (
  python "%REPO%\tools\analyze_logs.py" --dir "%%C" --capital 10000 --out "%OUT%\informe_%%~nxC.md"
)

echo.
echo Listo. Resultados en: %OUT%
pause
