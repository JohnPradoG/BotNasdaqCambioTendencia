# Etapa B · Primera versión funcional (v0.1)

> **Estado real (2026-10-09): compila en el MetaEditor del PC de John con 0
> errores.** El único aviso (versión `0.10` no válida para el MQL5 Market) se
> eliminó pasando `#property version` a `1.00`. El EA todavía **no se ha
> ejecutado** en el Strategy Tester ni en demo, y los autotests no se han
> ejecutado. No existe ningún backtest ni resultado.

## Qué está implementado

| Módulo | Archivo | Contenido |
|---|---|---|
| Tipos | `MQL5/Include/NBRL/Types.mqh` | Enums, `SSignal`, utilidades (hash de señal, horas). |
| Parámetros | `MQL5/Include/NBRL/Inputs.mqh` | Todas las entradas de `docs/etapa-a/03-parametros.md`, salvo las del motor C y las salidas pendientes. |
| SessionManager | `SessionManager.mqh` | Hora NY con DST propio, modo 24/5 (rollover, reapertura, corte y cierre del viernes, bloques horarios) y modo `WINDOW`, exclusiones, eventos manuales, día de trading 17:00 NY, sesiones del broker. |
| MarketStructureDetector | `MarketStructureDetector.mqh` | ATR M5/M15, RSI, swings confirmados con filtro ATR, zonas (swings M15, día anterior, overnight), régimen (ER, ATR14/ATR100) y marco espejo para compras. |
| Motor A | `ReversalAnticipationEngine.mqh` | A.0 contexto, A.1 puntuación (DEC, WCK, FAIL, DIV), A.2 invalidación y expiración, A1 y A2 con anti-persecución. |
| Motor B | `ConsolidationBreakoutEngine.mqh` | Detección de rango (anchura, compresión, toques), confirmación de ruptura, B1 (3 modos de SL, TP fijo o medido), B2 con espera de retesteo y cancelaciones. |
| SignalQualityFilter | `SignalQualityFilter.mqh` | Spread (puntos, % ATR, % R), volatilidad, espacio a la zona opuesta, relación recorrido/SL. |
| RiskManager | `RiskManager.mqh` | Volumen por riesgo con `OrderCalcProfit`, redondeo hacia abajo, margen, presupuesto diario (realizado + riesgo abierto), máximos diarios, pérdidas consecutivas, DD total y kill switch persistentes. |
| SafetyController | `SafetyController.mqh` | Validación del símbolo, stops/freeze level, envío con SL y TP, reintentos solo con retcodes recuperables, verificación de la posición real, SL obligatorio, anti-duplicados. |
| PositionManager | `PositionManager.mqh` | MFE/MAE, cierre por sesión y por riesgo, break-even, trailing ATR, tiempo máximo, el SL nunca se aleja, registro del cierre con datos del servidor, readopción tras reinicio. |
| TradeLogger | `TradeLogger.mqh` | `signals.csv` (todas las señales, también rechazadas, con motivo), `trades.csv`, `events.csv`. |
| PerformanceAnalyzer | `PerformanceAnalyzer.mqh` | Resumen por variante en el diario y criterio `OnTester` (expectativa R × √N, 0 si N < 30). |
| EA | `MQL5/Experts/NBRL/NasdaqBreakoutReversalLab.mq5` | Orquestación por vela cerrada, deduplicación por `signal_id`, conflictos (opuestas se anulan, prioridad), modo solo análisis, interruptor global, panel. |
| Autotests | `MQL5/Scripts/NBRL/NBRL_SelfTests.mq5` | DST (T-DST-1..4), swings (T-SW-1, T-SW-2), utilidades y redondeo de volumen (T-VOL-1..4). |

## Qué falta (pendiente para las Etapas C y D)

- Motor C (falsas rupturas) y su variante C1.
- Salidas: trailing por estructura, cierre parcial y salida por invalidación (los parámetros existen en el diseño y están en OFF en la configuración base).
- Script de análisis `tools/analyze_logs.py` con el informe completo del SPEC §13.
- Persistencia de setups armados tras un reinicio (por diseño se descartan; ver `04-riesgos-limitaciones.md` §6).
- Archivos `.set` de ejemplo por motor.
- Compilación, corrección de errores y casos límite (Etapa D).

## Desviaciones conocidas respecto al diseño

- Break-even: el SL va a entrada ± spread de apertura como estimación de costes; la comisión no se incluye todavía.
- La reapertura del mercado se detecta por un hueco sin ticks de `ReopenGapMin` minutos (no se suponen los horarios de Exness); el bloqueo se aplica tras cualquier reapertura, no solo la del domingo.
- El criterio de `OnTester` aún no aplica el corte por DD > 15R.

## Instalación en MT5 (para compilar)

1. En MT5: *Archivo → Abrir carpeta de datos*.
2. Copiar la carpeta `MQL5` del repositorio sobre la carpeta `MQL5` de datos
   (se añaden `Experts/NBRL`, `Include/NBRL` y `Scripts/NBRL`).
3. Abrir MetaEditor, abrir `Experts/NBRL/NasdaqBreakoutReversalLab.mq5` y
   pulsar *Compilar*. Copiar el resultado completo de la pestaña *Errores*
   (errores y avisos) y pasárnoslo.
4. Compilar y ejecutar `Scripts/NBRL/NBRL_SelfTests.mq5` sobre un gráfico de
   `ustec100`; el resultado sale en la pestaña *Expertos*.
5. Para la primera prueba en el Strategy Tester: símbolo `ustec100`, M5,
   "cada tick basado en ticks reales", `InpAnalysisOnly=true` y
   `LogToCommon=true`. Los CSV quedan en la carpeta común
   `Terminal/Common/Files/NBRL/`.

`ServerUTCOffsetHours` debe ajustarse al offset real del servidor de Exness
antes de cualquier prueba con horarios (ver el evento `INIT` en `events.csv`,
que registra la hora del servidor y la hora NY calculada).
