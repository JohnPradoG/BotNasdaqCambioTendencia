# 03 · Parámetros y valores iniciales (Etapa A)

Todos son `input` del EA (SPEC §2). Los valores iniciales son **puntos de
partida razonados, no optimizados**. La columna "Optimizar" marca los pocos
parámetros que se permitirá mover en la Fase 3 (SPEC §14), siempre una familia
por experimento; el resto queda fijo para evitar sobreajuste.

Unidades: `ATRe` = ATR14 del TF de entrada; `ATRc` = ATR14 del TF de contexto;
R = distancia entrada–SL.

## 1. General y símbolo

| Parámetro | Inicial | Rango de prueba | Optimizar | Descripción |
|---|---|---|---|---|
| `InpSymbol` | `""` | — | — | Vacío = símbolo del gráfico. |
| `InpSymbolKeywords` | `USTEC,NAS100,NAS,NDX,US100,Nasdaq,US Tech` | — | — | Palabras para validar que es Nasdaq 100. |
| `InpAllowUnverifiedSymbol` | false | — | — | Permitir símbolo no reconocido (solo pruebas). |
| `InpMagic` | 26100901 | — | — | Magic exclusivo de este EA. |
| `InpTFContext` | M15 | M15 | — | TF de contexto. |
| `InpTFEntry` | M5 | M5 / M1 | Comparación | TF de entradas (M1 como alternativa). |
| `InpAnalysisOnly` | false | — | — | Solo análisis: registra señales, no envía órdenes. |
| `InpBlockNewEntries` | false | — | — | Interruptor global de nuevas entradas. |
| `InpEnableA1` / `A2` / `B1` / `B2` / `C` | true/true/true/true/false | on/off | A/B | Activación por variante (C se activa en Etapa C). |
| `InpPriority` | `C,B2,B1,A2,A1` | — | — | Prioridad si coinciden señales. |
| `InpATRPeriod` | 14 | — | — | ATR de ambos TF. |

## 2. Estructura y zonas (MarketStructureDetector)

| Parámetro | Inicial | Rango de prueba | Optimizar | Descripción |
|---|---|---|---|---|
| `SwingStrengthCtx` | 3 | 2–4 | — | Velas a cada lado para swing M15. |
| `SwingStrengthEntry` | 2 | 2–3 | — | Velas a cada lado para swing M5. |
| `SwingMinATR` | 0,5 | 0,3–0,8 | — | Amplitud mínima entre swings opuestos. |
| `ZoneLookbackBars` | 96 | — | — | Velas M15 para zonas (24 h). |
| `ZoneWidthATR` | 0,25 | 0,15–0,4 | — | Semi-anchura de zona en ATRc. |
| `RegimeERPeriod` | 20 | — | — | Periodo de eficiencia para etiquetar régimen. |
| `RegimeTrendER` / `RegimeRangeER` | 0,35 / 0,20 | — | — | Umbrales de etiqueta. |
| `RegimeHighVolRatio` | 1,5 | — | — | ATR14/ATR100 para "alta volatilidad". |

## 3. Motor A

| Parámetro | Inicial | Rango de prueba | Optimizar | Descripción |
|---|---|---|---|---|
| `A_LegLookback` | 24 | 16–40 | — | Velas M15 para buscar el tramo. |
| `A_LegMinATR` | 3,0 | 2,0–4,0 | **Sí** | Amplitud mínima del tramo en ATRc. |
| `A_LegMinBars` | 6 | 4–10 | — | Duración mínima del tramo (M15). |
| `A_MaxDistFromExtremeATR` | 1,0 | — | — | Distancia máxima al extremo para evaluar. |
| `A_RequireZone` | true | on/off | A/B | Exigir extremo en zona relevante. |
| `A_DecelK` | 3 | — | — | Velas por bloque de impulso. |
| `A_DecelRatio` | 0,5 | 0,3–0,7 | — | Umbral de desaceleración. |
| `A_WickMinRatio` | 0,5 | 0,4–0,6 | — | Mecha mínima respecto al rango. |
| `A_FailLookback` | 12 | — | — | Ventana para fallos sucesivos. |
| `A_FailMinTouches` | 2 | 2–3 | — | Toques mínimos. |
| `A_FailTolATR` | 0,15 | — | — | Tolerancia de toque en ATRe. |
| `A_UseRSIDiv` | true | on/off | A/B | Usar divergencia RSI como componente. |
| `A_RSIPeriod` | 14 | — | — | — |
| `A_RSIDivMin` | 3 | — | — | Diferencia mínima de RSI. |
| `A_MinScore` | 2 | 2–3 | **Sí** | Puntuación mínima de agotamiento. |
| `A_InvalidBufATR` | 0,2 | — | — | Margen sobre `H*` que invalida el setup. |
| `A_SetupExpiryBars` | 12 | 6–24 | — | Vida del setup (velas M5). |
| `A_BreakBufATR` | 0,05 | — | — | Margen de ruptura de microestructura (A2). |
| `A2_MaxChaseATR` | 1,5 | 1,0–2,0 | — | Distancia máxima desde `H*` al disparo A2. |

## 4. Motor B

| Parámetro | Inicial | Rango de prueba | Optimizar | Descripción |
|---|---|---|---|---|
| `B_RangeTF` | M5 | M5 / M15 | Comparación | TF donde se detecta el rango. |
| `B_RangeMinBars` / `MaxBars` | 12 / 48 | 8–24 / 36–72 | **Sí** (familia) | Duración del rango. |
| `B_RangeMinATR` / `MaxATR` | 0,8 / 3,0 | 0,5–1,2 / 2,0–4,0 | **Sí** (familia) | Anchura del rango en ATRc. |
| `B_CompressionMax` | 0,8 | 0,6–1,0 | — | Rango medio interior / ATR previo. |
| `B_MinTouches` | 2 | 2–3 | — | Toques por lado. |
| `B_MaxOutsideCloses` | 0 | — | — | Cierres fuera del rango tolerados. |
| `B_BreakDistATR` | 0,1 | 0,05–0,3 | — | Distancia del cierre al nivel. |
| `B_BodyRatio` | 0,5 | 0,4–0,7 | — | Cuerpo mínimo de la vela de ruptura. |
| `B_ExpansionATR` | 1,0 | 0,8–1,5 | — | Rango mínimo de la vela de ruptura. |
| `B_TickVolMult` | 1,2 | — | — | Volumen tick relativo (si `F_TickVol`). |
| `B_ExpectedMoveMult` | 1,0 | — | — | Movimiento esperado = mult × anchura. |
| `B_MaxChaseFrac` | 0,4 | 0,25–0,6 | — | Fracción máxima del movimiento ya recorrida. |
| `B_SLMode` | 0 (medio) | 0/1/2 | A/B | Tipo de SL estructural. |
| `B_TPMode` | 0 (R fijo) | 0/1 | A/B | R fijo o movimiento medido. |
| `B_RetestMaxBars` | 12 | 6–18 | — | Espera máxima de retesteo (B2). |
| `B_RetestTolATR` | 0,2 | — | — | Tolerancia del retesteo. |
| `B_ReentryTolATR` | 0,2 | — | — | Margen que define "vuelta al rango". |
| `B_ReentryBars` | 3 | — | — | Ventana de invalidación con posición. |

## 5. Motor C

| Parámetro | Inicial | Rango de prueba | Optimizar | Descripción |
|---|---|---|---|---|
| `C_MinLevelAgeBars` | 6 | — | — | Antigüedad mínima del nivel (M5). |
| `C_SweepMinATR` | 0,1 | 0,05–0,2 | — | Sobrepaso mínimo para abrir evento. |
| `C_WindowBars` | 6 | 3–9 | **Sí** | Ventana de clasificación. |
| `C_LateWindowBars` | 12 | — | — | Ventana para extensión y reversión. |
| `C_HoldBars` | 2 | — | — | Cierres que confirman ruptura verdadera. |
| `C_ReentryDepthATR` | 0,1 | 0,05–0,25 | — | Profundidad del regreso al rango. |
| `C_BodyRatio` | 0,5 | — | — | Cuerpo mínimo de confirmación. |
| `C_MaxExcursionATR` | 1,5 | 1,0–2,0 | — | Excursión máxima aceptada (ATRc). |
| `C_TPMode` | 0 | 0/1 | A/B | R fijo o medio del rango. |

## 6. Filtros de calidad (SignalQualityFilter) — todos opcionales

Por defecto solo están activos los filtros **de seguridad** (spread y
horario); el resto empieza en OFF y se prueba uno a uno (SPEC §8).

| Parámetro | Inicial | Descripción |
|---|---|---|
| `F_MaxSpreadPoints` | 0 = calcular | Spread máximo absoluto en puntos. 0 = no usar absoluto; se fijará tras medir el spread típico del símbolo de Exness. |
| `F_MaxSpreadATRFrac` | 0,10 (ON) | Spread ≤ 10 % de ATRe. |
| `F_SpreadRFrac` | 0,15 (ON) | Spread ≤ 15 % de R (coste relativo de la operación). |
| `F_UseVolFilter` | OFF | Volatilidad: `F_MinATRc` ≤ ATRc ≤ `F_MaxATRc` (en puntos, a calibrar con datos). |
| `F_UseRoom` | OFF | Distancia a zona opuesta ≥ `F_RoomMinR` (1,0) R. |
| `F_UseTickVol` | OFF | Volumen tick en rupturas (B). |
| `F_UseRegime` | OFF | Solo operar en régimen permitido por motor (hipótesis). |
| `F_UseMinRR` | ON | Relación recorrido esperado / SL ≥ `F_MinRR` (1,0) usando objetivo y SL reales. |
| (rechazo por mecha, divergencia RSI, calidad de consolidación, impulso de ruptura) | — | Son componentes de los motores; sus interruptores están en las tablas de cada motor. |

## 7. Sesión (SessionManager)

| Parámetro | Inicial | Descripción |
|---|---|---|
| `ServerTimeMode` | MANUAL | AUTO solo en vivo; tester siempre MANUAL. |
| `ServerUTCOffsetHours` | **pendiente de verificar** (probable 0) | Offset del servidor de Exness respecto a UTC. Se confirma en la cuenta de John antes de la Etapa E. |
| `TradeStartNY` | 09:35 | Inicio de entradas. |
| `LastEntryNY` | 15:30 | Hora límite de nuevas entradas. |
| `SessionEndNY` | 15:55 | Fin de ventana. |
| `SessionClosePolicy` | CLOSE_ALL | `CLOSE_ALL` / `KEEP_WITH_SL`. |
| `ExcludeWindowsNY` | `""` | Hasta 4 `HH:MM-HH:MM` separadas por `;`. |
| `EventTimesNY` | `""` | Lista `YYYY.MM.DD HH:MM;...` (FOMC, CPI, etc.) introducida manualmente. |
| `EventMarginBeforeMin` / `AfterMin` | 15 / 15 | Exclusión alrededor de cada evento. |
| `TradingDayStartNY` | 17:00 | Inicio del día de trading (referencia diaria). |
| `TradeWeekdays` | `1,2,3,4,5` | Días permitidos. |

## 8. Riesgo (RiskManager)

| Parámetro | Inicial | Descripción |
|---|---|---|
| `RiskBase` | EQUITY | `EQUITY` / `BALANCE` / `FIXED` (capital asignado al EA, recomendado si hay otros robots en la cuenta). |
| `RiskFixedCapital` | 0 | Capital usado si `RiskBase=FIXED`. |
| `RiskPerTradePct` | 0,25 | % de riesgo por operación. |
| `DailyLossLimitPct` | 1,0 | % de la referencia diaria. |
| `DailyLossPolicy` | REALIZED_PLUS_OPEN_RISK | Ver `04-riesgos-limitaciones.md` §4. |
| `DailyLimitAction` | BLOCK_KEEP_SL | `BLOCK_KEEP_SL` / `BLOCK_CLOSE_ALL`. |
| `MaxTradesPerDay` | 6 | Operaciones abiertas por día de trading. |
| `MaxTradesPerEnginePerDay` | 3 | Por motor. |
| `MaxConsecLosses` | 3 | Pérdidas seguidas que bloquean el día. |
| `MaxTradesPerSignal` | 1 | Fijo. |
| `MaxTotalDDPct` | 6,0 | DD del EA desde su pico (sobre la base de riesgo) → kill switch. |
| `ResetKillSwitch` | false | Rearme manual del kill switch. |
| `CommissionPerLotRT` | 0 | Comisión ida y vuelta por lote en divisa de la cuenta (depende del tipo de cuenta Exness; a confirmar). |
| `SLBufferATR` | 0,1 | Margen sobre el nivel estructural (ATRe). |
| `SLMinATR` | 0,5 | Distancia mínima del SL (ATRe). |
| `SLMaxATR` | 2,0 | Distancia máxima del SL (ATRc); si se supera, se rechaza. |
| `MaxMarginUsePct` | 30 | Margen requerido máximo respecto al margen libre. |
| `MaxSlippagePoints` | 0 = calcular | Desviación permitida en la orden (se fijará tras medir el símbolo). |

## 9. Salidas (PositionManager)

| Parámetro | Inicial | Descripción |
|---|---|---|
| `TP_R` | 1,5 | Objetivo en múltiplos de R (pruebas: 1,0 / 1,5 / 2,0). |
| `X_BE` / `X_BETriggerR` | OFF / 1,0 | Break-even. |
| `X_TrailATR` / `X_TrailStartR` / `X_TrailATRMult` | OFF / 1,0 / 2,0 | Trailing ATR. |
| `X_TrailStruct` | OFF | Trailing por swings M5. |
| `X_Partial` / `X_PartialR` / `X_PartialFrac` | OFF / 1,0 / 50 | Cierre parcial (si el volumen permite dividir respetando el step). |
| `X_Invalidation` / `X_InvalidBars` | OFF / 6 | Salida por invalidación. |
| `X_MaxBars` / `X_MaxBarsM5` | OFF / 24 | Tiempo máximo. |

## 10. Seguridad y registros

| Parámetro | Inicial | Descripción |
|---|---|---|
| `MaxOrderRetries` | 2 | Solo para retcodes recuperables. |
| `RetryDelayMs` | 300 | Solo en vivo (en tester no hay espera). |
| `LogFolder` | `NBRL` | Subcarpeta en `MQL5/Files`. |
| `LogToCommon` | false | Usar carpeta común (útil en tester). |
| `ShowPanel` | true | Panel en el gráfico. |
| `VerboseLog` | false | Registro de diagnóstico ampliado. |

## 11. Frecuencia esperada (a comprobar, no es un resultado)

Con estos valores se busca del orden de 0–3 señales operables por día y motor
en la sesión de Nueva York. Si la Fase 2 muestra < 1 operación por semana en
un motor, los filtros son demasiado restrictivos (SPEC §1) y se revisará la
familia de parámetros responsable usando el registro de señales rechazadas.
