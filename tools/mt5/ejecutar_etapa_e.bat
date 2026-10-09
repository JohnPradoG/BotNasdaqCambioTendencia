@echo off
rem NBRL - Etapa E: un backtest por variante en solitario (A1, A2, B1, B2, C1)
rem en USTECm, in-sample 2021-01-01 a 2024-12-31, cada tick con ticks reales.
rem Solo Strategy Tester (cuenta simulada): no opera en la cuenta real.
rem Uso: cierra MT5 y haz doble clic en este archivo. Puede tardar horas.
setlocal enabledelayedexpansion
set "MT5=C:\Program Files\MetaTrader 5"
set "DATA=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
set "COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files"
set "HERE=%~dp0"
for %%I in ("%HERE%..\..") do set "REPO=%%~fI"
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm"') do set "STAMP=%%T"
set "OUTROOT=%REPO%\results\%STAMP%_E_IS"

tasklist /fi "imagename eq terminal64.exe" | find /i "terminal64.exe" >nul
if not errorlevel 1 (
  echo MT5 esta abierto. Cierralo y vuelve a ejecutar este archivo.
  pause & exit /b 1
)
mkdir "%OUTROOT%" 2>nul

echo Copiando el EA y los presets a MT5 y compilando...
xcopy /e /i /y "%REPO%\MQL5\Include\NBRL" "%DATA%\MQL5\Include\NBRL" >nul
xcopy /e /i /y "%REPO%\MQL5\Experts\NBRL" "%DATA%\MQL5\Experts\NBRL" >nul
mkdir "%DATA%\MQL5\Profiles\Tester" 2>nul
copy /y "%REPO%\presets\*.set" "%DATA%\MQL5\Profiles\Tester\" >nul
"%MT5%\metaeditor64.exe" /compile:"%DATA%\MQL5\Experts\NBRL\NasdaqBreakoutReversalLab.mq5" /inc:"%DATA%\MQL5" /log:"%OUTROOT%\compile_ea.log"

for %%V in (A1 A2 B1 B2 C1) do (
  set "OUT=%OUTROOT%\%%V"
  mkdir "!OUT!" 2>nul
  echo Backtest %%V ...
  if exist "%COMMON%\NBRL" move "%COMMON%\NBRL" "%COMMON%\NBRL_antes_%STAMP%_%%V" >nul
  set "INI=%TEMP%\nbrl_e_%%V.ini"
  > "!INI!" echo [Tester]
  >>"!INI!" echo Expert=NBRL\NasdaqBreakoutReversalLab
  >>"!INI!" echo ExpertParameters=NBRL_E_%%V_USTECm.set
  >>"!INI!" echo Symbol=USTECm
  >>"!INI!" echo Period=M5
  >>"!INI!" echo Model=4
  >>"!INI!" echo Optimization=0
  >>"!INI!" echo FromDate=2021.01.01
  >>"!INI!" echo ToDate=2024.12.31
  >>"!INI!" echo ForwardMode=0
  >>"!INI!" echo Deposit=10000
  >>"!INI!" echo Currency=USD
  >>"!INI!" echo Leverage=100
  >>"!INI!" echo Visual=0
  >>"!INI!" echo Report=NBRL_E_%%V
  >>"!INI!" echo ReplaceReport=1
  >>"!INI!" echo ShutdownTerminal=1
  copy /y "!INI!" "!OUT!\tester.ini" >nul
  start "" /wait "%MT5%\terminal64.exe" /config:"!INI!"
  copy /y "%DATA%\NBRL_E_%%V.*" "!OUT!\" >nul 2>&1
  xcopy /e /i /y "%COMMON%\NBRL" "!OUT!\csv" >nul 2>&1
  for /d %%C in ("!OUT!\csv\*") do python "%REPO%\tools\analyze_logs.py" --dir "%%C" --capital 10000 --out "!OUT!\informe.md"
)

echo.
echo Listo. Resultados en: %OUTROOT%
pause
