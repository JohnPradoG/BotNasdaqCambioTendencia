# Ejecutar la Etapa D en el PC de John

`ejecutar_etapa_d.bat` hace todo con un doble clic (con MT5 cerrado):

1. Copia `MQL5/Include/NBRL`, `Experts/NBRL`, `Scripts/NBRL` y los presets a la
   carpeta de datos de MT5 (`D0E8209F77C8CF37AD8BF550E51FF075`).
2. Compila el EA y los autotests con `metaeditor64.exe`.
3. Abre MT5 con `selftests.ini`: ejecuta `NBRL_SelfTests` en un gráfico de
   USTEC_x100m M5 y MT5 se cierra solo. Las líneas OK/FAIL quedan en
   `autotests.txt`.
4. Abre MT5 con `d0_smoke.ini`: Strategy Tester, **USTECm** M5, OHLC de 1
   minuto, 2024-01-01 → 2024-03-31, preset `NBRL_D0_smoke_USTECm.set`
   (todas las variantes, **solo análisis: no envía órdenes**), depósito 10 000 USD.
5. Guarda el informe, los logs y los CSV en `results/<fecha>_D0_smoke/` y, si
   hay Python, genera `informe.md` con `tools/analyze_logs.py`.

Nada de esto opera en la cuenta: el script de autotests no envía órdenes y el
Strategy Tester trabaja con una cuenta simulada. Los CSV de ejecuciones
anteriores en `Common\Files\NBRL` se mueven a `NBRL_antes_<fecha>`, no se borran.

Por qué USTECm: en Exness-MT5Trial11 el historial de USTEC_x100m solo tiene
2025 y 2026, y 2025 es el periodo OOS reservado. USTECm (el mismo Nasdaq,
contrato 1) tiene historial desde 2021.

## Etapa E: `ejecutar_etapa_e.bat`

Un backtest por variante en solitario (A1, A2, B1, B2, C1) en **USTECm**, M5,
in-sample **2021-11-01** → 2024-12-31 (el historial de USTECm en el PC empieza el 2021-10-27), modelo "cada tick basado en ticks reales",
depósito 10 000 USD, presets `presets/NBRL_E_<variante>_USTECm.set`. Guarda
informe, CSV e `informe.md` por variante en `results/<fecha>_E_IS/<variante>/`.
Puede tardar horas. El periodo 2025-01 → 2026-06 (OOS) no se toca.

Si el servidor no tiene ticks reales para todo el periodo, MT5 los genera y lo
indica en el log del agente; eso se revisará antes de sacar conclusiones.

Ambos lanzadores se detienen si la compilación no da 0 errores, y copian los
logs del agente del tester, `MQL5\Logs` y el log del terminal para comprobar si
hubo ticks reales o generados. No uses MT5 hasta que el .bat diga "Listo".

Por defecto la Etapa E corre en modo **diagnóstico** (`MODO=_diag` en el .bat):
presets `NBRL_E_<variante>_USTECm_diag.set`, con el filtro de spread al 50 % del
ATR M5 en vez del 10 % y spread hasta el 30 % de R en vez del 15 %, porque en D0 el spread (≈5 puntos, 43 % del ATR M5)
rechazó todas las señales. El backtest cobra el spread igual. Para el modo
estricto, cambia `MODO=` a vacío.
