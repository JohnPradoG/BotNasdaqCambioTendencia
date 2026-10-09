# 04 · Riesgos técnicos, limitaciones y políticas de riesgo (Etapa A)

## 1. Limitaciones del entorno de desarrollo

- El desarrollo se hace sin acceso a MetaTrader 5 ni a los datos de Exness.
  **No se podrá compilar ni ejecutar backtests desde aquí.** Cada etapa
  indicará explícitamente "no compilado" hasta que John compile en MetaEditor y
  comparta el resultado (errores/avisos, informe del tester o CSV).
- Ningún informe de este proyecto contendrá cifras de rendimiento que no
  procedan de un archivo real generado por MT5.

## 2. Datos, símbolo y hora del servidor

| Riesgo | Efecto | Mitigación |
|---|---|---|
| Nombre del símbolo distinto según servidor (`USTEC`, `USTECm`, `USTEC_x100`…) | EA en símbolo equivocado | Validación en `OnInit` (doc. técnico §6). |
| Historial de ticks reales de Exness corto o con huecos | Backtest poco representativo | Antes de la Fase 2: medir cuántos meses de ticks reales hay, huecos y spreads registrados; documentarlo. Si hay < 18 meses, se reduce la ambición del periodo y se dice. |
| Offset horario del servidor desconocido o con DST propio | Ventanas NY desplazadas 1 h en parte del año | `ServerUTCOffsetHours` manual en tester; verificación en vivo con `TimeTradeServer()−TimeGMT()`; prueba con fechas de cambio de horario EE. UU./UE (que no coinciden durante 2–3 semanas al año). |
| Spread en el tester distinto al real | Costes infravalorados | Usar ticks reales (spread histórico); Fase 5 con spread ×1,5 y ×2; comparar con el spread observado en demo. |
| Volumen tick de un CFD ≠ volumen real del mercado | Filtro de volumen poco informativo | Tratarlo como hipótesis (`F_UseTickVol` OFF por defecto). |
| Contract size / tick value distintos entre cuentas Exness | Lotaje erróneo | Cálculo con `OrderCalcProfit` y especificaciones leídas en tiempo real; prueba unitaria del cálculo. |
| Comisión no expuesta por la API del símbolo | Coste omitido | Parámetro `CommissionPerLotRT` + lectura de la comisión real de cada deal (`DEAL_COMMISSION`) para el registro. |
| Ajustes de dividendos/swap en índices | P/L afectado en posiciones nocturnas | Política por defecto `CLOSE_ALL` al fin de sesión; el swap se registra igualmente. |

## 3. Riesgos de lógica de señales

- **Look-ahead / repintado:** prohibido usar `[0]` y velas M15 abiertas. Los
  swings tienen retraso de N velas explícito. Prueba: autotest que reproduce
  la señal procesando las velas una a una y compara con la evaluación de una
  pasada (deben coincidir).
- **Intrabar (futuro, B1):** genera señales que no existirían al cierre,
  depende del modelado de ticks del tester y aumenta las entradas en picos de
  spread. Si se prueba: la señal se registra en el instante en que se dispara
  y nunca se modifica después, aunque la vela cierre de otra forma; se compara
  contra la versión de vela cerrada con el mismo periodo.
- **Sobreajuste:** muchos parámetros. Mitigación: solo los marcados como
  "Optimizar" en `03-parametros.md`, una familia por experimento, regiones
  estables, periodo fuera de muestra intacto, registro de todos los
  experimentos.
- **Solapamiento de motores:** A, B y C pueden reaccionar al mismo
  movimiento; con una posición por símbolo, el orden importa. Por eso cada
  motor y variante se evalúa **en solitario**; el modo combinado es un
  experimento posterior.
- **Pocas operaciones:** variantes muy filtradas pueden no tener muestra
  suficiente para concluir nada. Se declarará "muestra insuficiente", no
  "aprobado" ni "rechazado".

## 4. Política de riesgo diario (explícita, SPEC §9)

- **Referencia diaria** `Ref_d`: valor de la base de riesgo (`RiskBase`) en el
  primer tick del día de trading (17:00 NY por defecto). Persistido.
- **Pérdida realizada** `Real_d`: suma de `DEAL_PROFIT + DEAL_COMMISSION +
  DEAL_SWAP` de los deals de cierre del magic en el día de trading (negativo si
  hay pérdida). Las ganancias del día **no** amplían el límite.
- **Riesgo abierto** `Open_d`: pérdida monetaria si las posiciones abiertas
  del EA llegaran a su SL actual (calculada con `OrderCalcProfit`) + comisión
  estimada.
- **Política `REALIZED_PLUS_OPEN_RISK` (por defecto):** con
  `Usado = max(0, −Real_d) + Open_d`, una nueva entrada con riesgo `r_new`
  solo se permite si `Usado + r_new <= DailyLossLimitPct × Ref_d`.
  Con 0,25 % por operación y 1 % diario, esto permite como máximo 4 pérdidas
  completas en un día, y garantiza por construcción que el límite no se supera
  salvo por gaps o deslizamiento.
- **Corte duro:** si `Real_d + flotante_d <= −DailyLossLimitPct × Ref_d`
  (por deslizamiento, gap…), se aplica `DailyLimitAction`:
  `BLOCK_KEEP_SL` (bloquea entradas y deja las posiciones con su SL) o
  `BLOCK_CLOSE_ALL` (además cierra las posiciones **del EA**). Se registra el
  motivo y el bloqueo dura hasta el siguiente día de trading.
- Otros bloqueos del día: `MaxTradesPerDay`, `MaxTradesPerEnginePerDay`,
  `MaxConsecLosses`.
- **Drawdown total:** sobre la curva de P/L propia del EA (sus deals), desde su
  máximo, en % de la base. Al alcanzar `MaxTotalDDPct` se activa el kill
  switch persistente (sin nuevas entradas) hasta `ResetKillSwitch=true` manual.
- **Advertencia:** ningún límite garantiza una pérdida máxima exacta ante gaps
  (apertura del domingo, festivos), deslizamiento o fallos de ejecución.
- El EA **nunca** toca posiciones u órdenes con otro magic o manuales.
- Riesgo con otros robots en la misma cuenta: si `RiskBase=EQUITY`, el
  tamaño de las operaciones de este EA depende del resultado de los otros
  robots. Por eso se recomienda `RiskBase=FIXED` con el capital asignado.

## 5. Cálculo de volumen

1. `loss_1lot = |OrderCalcProfit(tipo, símbolo, 1.0, entrada, SL)|` +
   `CommissionPerLotRT`.
2. `riesgo_dinero = RiskPerTradePct/100 × base`.
3. `vol_raw = riesgo_dinero / loss_1lot`.
4. `vol = floor(vol_raw / step) × step`; limitar a `vol_max`.
5. Si `vol < vol_min` → **no operar** (`reject: min_volume_exceeds_risk`).
6. Margen: `OrderCalcMargin(vol) <= MaxMarginUsePct × margen_libre`; si no,
   se reduce `vol` al step inferior que cumpla, o se rechaza.
7. Comprobación cruzada (registro): `vol × loss_1lot <= riesgo_dinero`.
   Alternativa de contraste con `tick_value/tick_size` registrada para detectar
   discrepancias de especificación.

Prohibido: martingala, grid, promediar, aumentar lotaje tras pérdidas o tras
ganancias, alejar el SL.

## 6. Ejecución y seguridad

| Riesgo | Mitigación |
|---|---|
| Orden duplicada por ticks repetidos o reinicio | Evaluación una vez por vela; set de `signal_id`; comprobación de posición/orden del magic y de "solicitud en curso" antes de enviar. |
| Retcode no exitoso | Lista explícita: reintentar (máx. 2, precio actualizado) solo `REQUOTE`, `PRICE_CHANGED`, `PRICE_OFF`, `CONNECTION`, `TIMEOUT`; nunca reintentar `NO_MONEY`, `INVALID_STOPS`, `INVALID_VOLUME`, `MARKET_CLOSED`, `TRADE_DISABLED`, `LIMIT_POSITIONS`. Todo se registra. |
| Orden "enviada" que no existe | La operación solo se marca como abierta tras localizar la posición por ticket/deal del magic. Si no aparece, `exec_error: not_confirmed`. |
| SL demasiado cerca / freeze level | Validación previa con `SYMBOL_TRADE_STOPS_LEVEL` y `SYMBOL_TRADE_FREEZE_LEVEL`; el SL se aleja hasta el mínimo, nunca se recorta. |
| Envío sin SL | El SL va en la misma solicitud. Si el servidor no lo acepta, se cierra la posición de inmediato y se registra el fallo. |
| Desconexión o reinicio de MT5 | Reconstrucción del día desde el historial del magic; las posiciones abiertas se readoptan con su SL; los setups armados no se recuperan (se registran como `expired: restart`) para no entrar con información obsoleta. |
| Spread anómalo | Filtros de spread (absoluto, % ATR, % R) en el momento del envío, no solo en la señal. |
| Mercado cerrado / festivos EE. UU. | Comprobación de sesión de trading del símbolo (`SymbolInfoSessionTrade`) + días permitidos. |

## 7. Noticias

- El calendario económico de MQL5 (`CalendarValueHistory`) no funciona en el
  Strategy Tester. Usarlo en vivo y no en backtest haría que ambos entornos no
  fueran comparables.
- **Decisión v1:** no hay filtro automático de noticias. Se ofrecen ventanas de
  exclusión diarias y una lista manual de eventos (FOMC, CPI, NFP…) con
  márgenes. El EA no afirma conocer las noticias. Para backtest se puede
  preparar una lista histórica de fechas en el `.set` (tarea opcional de la
  Etapa E).

## 8. Riesgo de investigación

- Es posible que ninguna variante muestre ventaja neta tras costes. Eso es un
  resultado válido y se informará como tal, aplicando el protocolo del SPEC
  §15 (una familia de parámetros por experimento, conservar estadísticas
  originales).
- El rendimiento pasado no garantiza el futuro, ni siquiera tras validación
  fuera de muestra y demo.
