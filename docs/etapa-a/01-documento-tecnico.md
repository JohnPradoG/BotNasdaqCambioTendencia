# 01 · Documento técnico de la estrategia (Etapa A)

Referencia: `docs/SPEC.md` (especificación maestra). Este documento define la
arquitectura, las hipótesis de trabajo y las definiciones comunes que usan
todos los motores. Las reglas exactas por motor están en
`02-reglas-motores.md`; los parámetros en `03-parametros.md`.

> Estado: diseño. No existe todavía código, compilación ni backtest. Ninguna
> afirmación de este documento es un resultado; todo son hipótesis a probar.

---

## 1. Objetivo operativo

Un EA independiente (magic number, registros y estadísticas propios) que opera
únicamente el índice Nasdaq 100 en Exness (símbolo detectado y validado en
`OnInit`, ver §6) buscando cuatro tipos de oportunidad:

| Tipo | Motor | Variantes |
|---|---|---|
| Giro bajista/alcista anticipado | A · ReversalAnticipationEngine | A1 agresiva, A2 con confirmación estructural |
| Ruptura de consolidación | B · ConsolidationBreakoutEngine | B1 entrada directa, B2 entrada tras retesteo |
| Falsa ruptura → operación contraria | C · FalseBreakoutEngine | C1 (única en v1) |

Configuración de referencia: **M15 contexto + M5 entradas**. Alternativa a
comparar después: M15 + M1. Todos los motores pueden activarse/desactivarse y
evaluarse por separado; el riesgo es común.

## 2. Hipótesis de trabajo (a validar, no supuestos)

Cada hipótesis es falsable con los registros y métricas definidos en
`05-plan-pruebas.md`.

- **H-A (giros):** tras un tramo direccional amplio (≥ 3 ATR M15), la
  coincidencia de al menos dos evidencias de agotamiento basadas en precio
  (desaceleración, rechazo por mecha, fallos repetidos en el extremo,
  divergencia RSI opcional) aumenta la probabilidad de un retroceso de al
  menos 1,5R respecto a entradas aleatorias en el mismo contexto.
  - H-A1: entrar en la primera vela de rechazo captura más recorrido pero
    con más falsas señales.
  - H-A2: exigir la ruptura del último mínimo/máximo local (microestructura)
    reduce la tasa de fallo lo suficiente para compensar la peor entrada.
- **H-B (rupturas):** una salida de un rango comprimido, con cierre fuera del
  rango, cuerpo dominante y expansión de rango de vela, continúa al menos 1,5R
  con más frecuencia que una ruptura sin esos requisitos.
  - H-B1: la entrada directa capta los movimientos que no retestean.
  - H-B2: la entrada en retesteo mejora la relación R:R a cambio de perder los
    movimientos sin retesteo.
- **H-C (falsas rupturas):** cuando el precio sobrepasa un nivel relevante y
  vuelve a cerrar dentro con una vela de confirmación, el movimiento hacia el
  interior del rango alcanza al menos 1,5R con frecuencia suficiente. No se
  interpreta como "intención institucional": solo se describe lo que hizo el
  precio.
- **H-0 (control):** si un motor no supera a su propio control (mismas
  condiciones de contexto, sin el disparador específico), el disparador no
  aporta valor aunque el resultado sea positivo. Ver control aleatorio en
  `05-plan-pruebas.md` §4.4.

## 3. Arquitectura modular

```
            ┌──────────────────────────────── OnTick ───────────────────────────────┐
            │                                                                       │
   SafetyController ──► SessionManager ──► (¿nueva vela M5 cerrada?) ──► MarketStructureDetector
     (kill switch,       (hora NY, DST,                                   (swings, zonas, rangos,
      estado, panel)      ventanas)                                         régimen, ATR)
                                                                                │
                         ┌──────────────────────┬───────────────────────┬──────┘
                         ▼                      ▼                       ▼
              ReversalAnticipation    ConsolidationBreakout     FalseBreakout
                  Engine (A1/A2)          Engine (B1/B2)          Engine (C)
                         └──────────── Signal (struct) ─────────────────┘
                                             ▼
                                   SignalQualityFilter  (filtros opcionales A/B)
                                             ▼
                                       RiskManager  (lotaje, límites diarios, DD)
                                             ▼
                                   SafetyController.Execute (validación + envío + verificación)
                                             ▼
                                      PositionManager  (SL/TP, salidas, nunca alejar SL)
                                             ▼
                       TradeLogger (CSV)  ─────►  PerformanceAnalyzer (informe por motor/variante)
```

### 3.1 Responsabilidad de cada módulo

| Módulo | Responsabilidad | No hace |
|---|---|---|
| **MarketStructureDetector** | Calcula, solo con velas cerradas: ATR por TF, swings confirmados, estructura (HH/HL/LH/LL), zonas relevantes (swings M15, máximo/mínimo del día anterior, rango overnight), rangos de consolidación, etiqueta de régimen (tendencia/rango/alta volatilidad). Expone una "foto" inmutable por vela. | No genera señales ni opera. |
| **ReversalAnticipationEngine** | Reglas A1/A2 sobre la foto. Devuelve 0..n `Signal`. | No calcula lotaje ni aplica filtros opcionales. |
| **ConsolidationBreakoutEngine** | Reglas B1/B2. Mantiene el estado de rangos "en espera de retesteo". | Ídem. |
| **FalseBreakoutEngine** | Clasifica eventos de ruptura (verdadera / falsa con regreso / barrido sin confirmación / extensión y reversión) y genera señales C. | Ídem. |
| **SignalQualityFilter** | Aplica los filtros opcionales del SPEC §8, cada uno con su interruptor. Devuelve aceptada o rechazada con el nombre del filtro. | No modifica precios de la señal. |
| **SessionManager** | Conversión servidor → hora de Nueva York con DST, ventana operativa, hora límite de entradas, ventanas de exclusión, día de trading. | No decide señales. |
| **RiskManager** | Volumen por riesgo, límites diarios (pérdida, nº operaciones, pérdidas consecutivas), DD total, política al alcanzar límites. | No envía órdenes. |
| **PositionManager** | Aplica la salida configurada (TP en R, trailing ATR/estructura, parcial, invalidación, fin de sesión, tiempo máximo, break-even). Garantiza que el SL nunca se aleja. MFE/MAE. | No abre posiciones. |
| **TradeLogger** | CSV de señales, operaciones y eventos con ID único de señal. | No calcula estadísticas agregadas. |
| **PerformanceAnalyzer** | Métricas por motor/variante (SPEC §13) en `OnTester`/`OnDeinit` + script externo de análisis (Etapa E). | — |
| **SafetyController** | Validación pre-orden (volumen, stops level, freeze level, spread, margen, modo de trading), envío con reintentos limitados, verificación de la posición real, anti-duplicados, persistencia, recuperación tras reinicio, modo solo análisis, interruptor global, panel. | — |

### 3.2 Contrato de señal (struct `Signal`)

Campos mínimos que todos los motores rellenan (y que el logger escribe tal cual):

`signal_id, engine, variant, direction, tf_context, tf_entry, signal_bar_time,
signal_type, structure_id, entry_ref, sl_price, tp_price, invalidation_price,
atr_ctx, atr_entry, reasons (texto con los componentes que se cumplieron),
expires_at`.

`signal_id` = hash estable de `engine|variant|symbol|tf_entry|signal_bar_time|direction|structure_id`.
Una señal con un `signal_id` ya registrado **nunca** se vuelve a procesar
(memoria + persistencia, §7). Una vez registrada, una señal no se modifica:
cualquier cambio posterior (invalidación, expiración, ejecución) se registra
como un evento nuevo que la referencia.

## 4. Definiciones comunes (reproducibles)

Notación: índice `[1]` = última vela **cerrada** del TF indicado; `[0]` es la
vela abierta y no se usa para decidir en el modo por defecto. `ATRc` = ATR(14)
del TF de contexto (M15) en `[1]`; `ATRe` = ATR(14) del TF de entrada (M5)
en `[1]`.

### 4.1 Evaluación por vela cerrada (modo por defecto)

- Las reglas se evalúan una sola vez por vela de entrada cerrada: cuando
  `iTime(TF_entry, 0)` cambia respecto al último valor procesado.
- La foto M15 usa solo la última vela M15 **cerrada** cuyo cierre sea
  `<= iTime(TF_entry,0)`. Una vela M15 abierta nunca se usa como si estuviera
  cerrada (SPEC §7).
- Las entradas se ejecutan a mercado al abrir la vela siguiente a la señal
  (primer tick tras el cierre). El precio de referencia de la señal es
  `Close[1]`; el precio real de ejecución se registra y la diferencia se
  registra como deslizamiento respecto a la referencia.
- **Intrabar (experimental, desactivado en v1):** solo para B1 en una etapa
  posterior. Riesgos documentados en `04-riesgos-limitaciones.md` §3. Se
  decide con datos (comparación A/B), no por preferencia.

**Justificación:** las reglas de vela cerrada son idénticas en tester y en
demo, no dependen del modo de modelado de ticks y no producen señales que
"desaparecen". El coste es entrar más tarde; se medirá en R.

### 4.2 Swings (máximos y mínimos locales) sin repintado

- Una vela `i` es **swing high** en un TF si `High[i] > High[i+k]` y
  `High[i] >= High[i-k]` para `k = 1..N` (N = `SwingStrength`; empate a la
  izquierda rompe a favor de la vela más antigua). Simétrico para swing low.
- El swing solo se considera **confirmado** cuando las N velas de su derecha
  están cerradas: el retraso de confirmación es explícito (N velas) y forma
  parte de la regla. Nada se dibuja ni se usa antes.
- **Filtro de amplitud (zigzag por ATR):** un swing solo entra en la lista si
  su distancia al swing opuesto anterior es `>= SwingMinATR × ATR` del TF.
  Si dos swings del mismo tipo quedan consecutivos, se conserva el más extremo.
- Valores iniciales: M15 `N=3`, M5 `N=2`, `SwingMinATR=0,5`.

### 4.3 Estructura

Sobre los dos últimos swing highs (H1 anterior, H2 reciente) y lows (L1, L2)
confirmados del TF:

- **Alcista:** H2 > H1 y L2 > L1. **Bajista:** H2 < H1 y L2 < L1.
- **Neutral:** cualquier otra combinación.
- **Ruptura de microestructura (M5):** en un tramo alcista, el "último mínimo
  más alto" (`L_micro`) es el swing low M5 confirmado más reciente anterior al
  extremo del tramo. Un cierre M5 por debajo de `L_micro − BreakBufferATR×ATRe`
  es un cambio local de estructura a la baja. Simétrico al alza.

### 4.4 Zonas relevantes

Lista de niveles recalculada en cada vela M15 cerrada:

1. Swings M15 confirmados de las últimas `ZoneLookbackBars` (96 = 24 h).
2. Máximo y mínimo del día de trading anterior (día NY, §5).
3. Máximo y mínimo del rango overnight (18:00–09:30 NY) del día actual,
   disponibles solo desde las 09:30 NY.
4. Techo y suelo del rango de consolidación activo (motor B), si existe.

Una **zona** = nivel ± `ZoneWidthATR × ATRc` (0,25). Niveles a menos de una
anchura de zona se fusionan (se conserva el promedio y el número de toques).
Distancia al soporte/resistencia más próximo = distancia desde la entrada al
borde de la zona más cercana en la dirección de la operación.

### 4.5 Régimen de mercado (etiqueta para métricas, no filtro por defecto)

- **Eficiencia** `ER = |C[1] − C[1+n]| / Σ|C[i] − C[i+1]|`, n = 20 velas M15.
  `ER >= 0,35` → *tendencia*; `ER <= 0,20` → *consolidación*; resto *mixto*.
- **Volatilidad relativa** `VR = ATR14(M15) / ATR100(M15)`. `VR >= 1,5` →
  *alta volatilidad*.
- Cada señal y operación registra `regime` y `VR`. Sirve para los informes
  por régimen (SPEC §13). Usarlo como filtro es una hipótesis aparte.

### 4.6 Medida de riesgo R

`R` = distancia en precio entre la entrada real y el SL inicial. Resultado en R
= beneficio neto (con comisión y swap) / riesgo monetario previsto. El riesgo
monetario previsto se calcula con `OrderCalcProfit` entre entrada y SL para el
volumen enviado, más comisión estimada.

### 4.7 Reglas comunes de stop loss

Aplican a todos los motores:

1. El SL es **estructural** (definido por cada motor) + `SLBufferATR × ATRe`
   + spread actual en la dirección de cierre.
2. Si la distancia estructural es menor que
   `max(SLMinATR × ATRe, stops_level + freeze margen)`, el SL **se aleja** hasta
   ese mínimo (nunca se acerca para aumentar lotaje, SPEC §9).
3. Si la distancia resultante supera `SLMaxATR × ATRc`, la señal se **rechaza**
   (`reject: sl_too_wide`). Nunca se recorta el stop para que "quepa".
4. Una vez abierta la posición, el SL solo puede moverse a favor
   (PositionManager valida antes de cada `PositionModify`).

### 4.8 Salida base (v1)

Para poder medir la contribución de cada mecanismo (SPEC §10), la
configuración base de todos los motores es: **SL estructural + TP fijo en R
(1,5R) + cierre antes del fin de semana (o fin de ventana en modo `WINDOW`)** (configurable). Trailing ATR,
trailing estructural, parcial, break-even, invalidación y tiempo máximo existen
como opciones independientes y desactivadas por defecto; cada una se prueba
contra la base en un experimento propio.

## 5. Sesión de Nueva York

- **Conversión de hora:** `NY = UTC − 5 h` (EST) o `UTC − 4 h` (EDT). EDT rige
  desde el segundo domingo de marzo 02:00 local hasta el primer domingo de
  noviembre 02:00 local (reglas vigentes desde 2007). Se implementa con una
  función propia que calcula esas fechas para cada año; no se usa la zona
  horaria del PC.
- **UTC del servidor:** `ServerTimeMode`:
  - `AUTO` (solo en vivo): offset = `TimeTradeServer() − TimeGMT()` redondeado
    a 30 min; se registra en el log al iniciar y cada día.
  - `MANUAL`: offset fijo introducido por el usuario (`ServerUTCOffsetHours`).
  - En el Strategy Tester `TimeGMT()` no es fiable (se basa en el PC), por eso
    en tester se usa siempre `MANUAL`. **Hay que verificar el offset real del
    servidor de Exness de John antes de la Etapa E** (ver
    `04-riesgos-limitaciones.md` §2). No se supone que coincida con NY.
- **Modo de operación por defecto: 24/5** (decisión de John, 2026-10-09,
  ver `docs/DECISIONES.md`). `SessionMode`:
  - `H24_5` (por defecto): se permiten entradas durante todo el horario de
    negociación del símbolo de domingo a viernes, respetando siempre las
    sesiones de trading que publica el broker (`SymbolInfoSessionTrade`), más
    estos bloqueos configurables:
    - **Rollover diario:** sin nuevas entradas de 16:50 a 17:20 NY (pausa
      diaria y picos de spread alrededor del cierre del día).
    - **Reapertura del domingo:** sin entradas durante los primeros 30 min tras
      la reapertura semanal (huecos y spreads amplios).
    - **Cierre del viernes:** última entrada nueva el viernes a las 15:30 NY y
      cierre de las posiciones del EA a las 16:30 NY (`WeekendClosePolicy` =
      `CLOSE_ALL` por defecto) para no quedar expuesto al hueco del fin de
      semana.
    - Posiciones abiertas durante el rollover diario: se mantienen con su SL
      (`DailyRolloverPolicy` = `KEEP_WITH_SL`); el swap se registra.
  - `WINDOW`: ventana única configurable (p. ej. 09:35–15:30 NY, cierre 15:55
    NY), útil para comparar contra el modo 24/5.
- **Bloques horarios para medir (no filtran por defecto):** cada señal se
  etiqueta con su bloque horario NY: `ASIA` 18:00–03:00, `EUROPA`
  03:00–09:30, `NY` 09:30–16:00, `POST` 16:00–18:00. Cada bloque puede
  activarse o desactivarse (`AllowAsia`, `AllowEurope`, `AllowNY`,
  `AllowPost`) para pruebas A/B. Hipótesis a comprobar: los umbrales en ATR se
  adaptan a la menor volatilidad de Asia, pero el spread relativo es mayor,
  por lo que los filtros de spread respecto a ATR y a R son críticos fuera de
  la sesión de NY.
- **Exclusiones:** hasta 4 ventanas diarias fijas `HH:MM-HH:MM` NY y una lista
  de fechas/horas de eventos (`YYYY.MM.DD HH:MM`) con margen antes/después
  configurable. El calendario económico de MQL5 no está disponible en el
  Strategy Tester, por lo que en v1 **el EA no conoce las noticias**: solo
  respeta las ventanas que se le introduzcan (limitación documentada).
- **Día de trading:** comienza a las 17:00 NY (cierre diario del CME,
  configurable). La referencia de equity diaria se fija en el primer tick
  posterior a ese cambio.
- Todo registro incluye `server_time` y `ny_time`.

## 6. Detección y validación del símbolo

En `OnInit`:

1. Símbolo = `InpSymbol` si no está vacío; si no, el del gráfico.
2. Debe existir y estar seleccionado en Market Watch (`SymbolSelect`).
3. Validación de que es Nasdaq 100: nombre o descripción o ruta
   (`SYMBOL_DESCRIPTION`, `SYMBOL_PATH`) contiene alguno de
   `USTEC, NAS100, NAS, NDX, US100, Nasdaq, US Tech` (lista configurable). Si
   no coincide → `INIT_PARAMETERS_INCORRECT`, salvo `InpAllowUnverifiedSymbol`.
4. `SYMBOL_TRADE_MODE` debe permitir abrir en ambas direcciones.
5. Se registran: dígitos, point, tick size, tick value, contract size, volumen
   mín/máx/step, stops level, freeze level, modo de llenado, modo de ejecución,
   divisa de beneficio/margen, swap y spread actual.
6. El modo de llenado se elige según `SYMBOL_FILLING_MODE` (FOK → IOC →
   RETURN). No se supone uno fijo.

Ejemplo de nombre posible: `USTEC_x100` o `USTECm`. **No se da por supuesto.**

## 7. Persistencia, duplicados y recuperación

- Estado persistente por `magic+symbol` en un archivo `state.json`-like (texto
  clave=valor) en `MQL5/Files/NBRL/` y respaldo en Variables Globales del
  terminal: inicio del día de trading, equity de referencia, P/L realizado del
  día, nº de operaciones del día, pérdidas consecutivas, pico de P/L del EA,
  kill switch, último `signal_bar_time` procesado por motor.
- En `OnInit`: se reconstruye el día desde el historial de deals del magic
  (fuente de verdad) y se compara con el estado guardado; si difieren, manda el
  historial y se registra el evento.
- Anti-duplicados (tres capas): (1) una evaluación por vela cerrada; (2) set de
  `signal_id` procesados; (3) antes de enviar, se comprueba que no hay posición
  ni orden pendiente con el magic en el símbolo ni una solicitud en curso.

## 8. Plan de archivos (para las Etapas B–D)

| Archivo | Contenido | Depende de |
|---|---|---|
| `MQL5/Experts/NBRL/NasdaqBreakoutReversalLab.mq5` | EA principal: inputs, `OnInit/OnTick/OnTester/OnDeinit` | todos |
| `MQL5/Include/NBRL/Types.mqh` | enums, `Signal`, `Snapshot`, constantes | — |
| `MQL5/Include/NBRL/SessionManager.mqh` | hora NY, DST, ventanas | Types |
| `MQL5/Include/NBRL/MarketStructureDetector.mqh` | ATR, swings, zonas, rangos, régimen | Types |
| `MQL5/Include/NBRL/ReversalAnticipationEngine.mqh` | A1/A2 | Types, MSD |
| `MQL5/Include/NBRL/ConsolidationBreakoutEngine.mqh` | B1/B2 | Types, MSD |
| `MQL5/Include/NBRL/FalseBreakoutEngine.mqh` | C | Types, MSD |
| `MQL5/Include/NBRL/SignalQualityFilter.mqh` | filtros §8 | Types, MSD, Session |
| `MQL5/Include/NBRL/RiskManager.mqh` | lotaje, límites | Types |
| `MQL5/Include/NBRL/PositionManager.mqh` | salidas, MFE/MAE | Types, Risk, Safety |
| `MQL5/Include/NBRL/TradeLogger.mqh` | CSV | Types |
| `MQL5/Include/NBRL/PerformanceAnalyzer.mqh` | métricas | Types, Logger |
| `MQL5/Include/NBRL/SafetyController.mqh` | ejecución, estado, panel | Types |
| `MQL5/Scripts/NBRL/NBRL_SelfTests.mq5` | pruebas de unidad (DST, lotaje, swings) | Include |
| `tools/analyze_logs.py` | informe offline por motor/variante | CSV |
| `presets/*.set` | configuraciones de prueba por motor | — |

Reparto por etapas (SPEC §18): **B** = Types, Session, MSD, motor A, motor B,
Risk, Safety, Position (base), logger mínimo. **C** = motor C, logger completo,
PerformanceAnalyzer, script de análisis. **D** = autotests, casos límite,
correcciones tras compilar en MT5 (requiere que John compile, ver
`04-riesgos-limitaciones.md` §1).
