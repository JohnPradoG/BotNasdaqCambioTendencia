@echo off
rem NBRL - Validacion fuera de muestra (OOS) de M15 A2: UNA sola ejecucion, 2025-01-01 a 2026-06-30.
rem Configuracion congelada: presets\NBRL_OOS_A2_M15_USTECm.set. No repetirla tras ajustar nada.
rem Solo Strategy Tester (cuenta simulada): no opera en la cuenta real.
rem Uso: cierra MT5, enchufa el PC y haz doble clic. Dura unos minutos.
setlocal enabledelayedexpansion
set "MT5=C:\Program Files\MetaTrader 5"
set "DATA=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
set "COMMON=%APPDATA%\MetaQuotes\Terminal\Common\Files"
set "HERE=%~dp0"
for %%I in ("%HERE%..\..") do set "REPO=%%~fI"
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmm"') do set "STAMP=%%T"
set "OUT=%REPO%\results\%STAMP%_OOS_A2_M15"
tasklist /fi "imagename eq terminal64.exe" | find /i "terminal64.exe" >nul
if not errorlevel 1 (
  echo MT5 esta abierto. Cierralo y vuelve a ejecutar este archivo.
  pause & exit /b 1
)
mkdir "%OUT%" 2>nul
xcopy /e /i /y "%REPO%\MQL5\Include\NBRL" "%DATA%\MQL5\Include\NBRL" >nul
xcopy /e /i /y "%REPO%\MQL5\Experts\NBRL" "%DATA%\MQL5\Experts\NBRL" >nul
mkdir "%DATA%\MQL5\Profiles\Tester" 2>nul
copy /y "%REPO%\presets\NBRL_OOS_A2_M15_USTECm.set" "%DATA%\MQL5\Profiles\Tester\" >nul
"%MT5%\metaeditor64.exe" /compile:"%DATA%\MQL5\Experts\NBRL\NasdaqBreakoutReversalLab.mq5" /inc:"%DATA%\MQL5" /log:"%OUT%\compile_ea.log"
powershell -NoProfile -Command "if (Select-String -Path '%OUT%\compile_ea.log' -Pattern ' 0 errors' -Quiet) { exit 0 } else { exit 1 }"
if errorlevel 1 (
  echo La compilacion fallo. Revisa %OUT%\compile_ea.log
  pause & exit /b 1
)
if exist "%COMMON%\NBRL" move "%COMMON%\NBRL" "%COMMON%\NBRL_antes_%STAMP%_OOS" >nul
set "INI=%TEMP%\nbrl_oos_a2_m15.ini"
> "%INI%" echo [Tester]
>>"%INI%" echo Expert=NBRL\NasdaqBreakoutReversalLab
>>"%INI%" echo ExpertParameters=NBRL_OOS_A2_M15_USTECm.set
>>"%INI%" echo Symbol=USTECm
>>"%INI%" echo Period=M15
>>"%INI%" echo Model=4
>>"%INI%" echo Optimization=0
>>"%INI%" echo FromDate=2025.01.01
>>"%INI%" echo ToDate=2026.06.30
>>"%INI%" echo ForwardMode=0
>>"%INI%" echo Deposit=10000
>>"%INI%" echo Currency=USD
>>"%INI%" echo Leverage=100
>>"%INI%" echo Visual=0
>>"%INI%" echo Report=NBRL_OOS_A2_M15
>>"%INI%" echo ReplaceReport=1
>>"%INI%" echo ShutdownTerminal=1
copy /y "%INI%" "%OUT%\tester.ini" >nul
start "" /wait "%MT5%\terminal64.exe" /config:"%INI%"
copy /y "%DATA%\NBRL_OOS_A2_M15.*" "%OUT%\" >nul 2>&1
xcopy /e /i /y "%COMMON%\NBRL" "%OUT%\csv" >nul 2>&1
for /d %%A in ("%APPDATA%\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-*") do xcopy /i /y "%%A\logs\*.log" "%OUT%\tester_logs\%%~nxA\" >nul 2>&1
xcopy /i /y "%DATA%\MQL5\Logs\*.log" "%OUT%\mql5_logs\" >nul 2>&1
for /d %%C in ("%OUT%\csv\*") do python "%REPO%\tools\analyze_logs.py" --dir "%%C" --capital 10000 --split 2026-01-01 --out "%OUT%\informe_%%~nxC.md"
echo.
echo Listo. Resultados en: %OUT%
pause
