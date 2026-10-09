# 05 · Plan de pruebas y criterios de aprobación (Etapa A)

Protocolo reproducible según SPEC §14. Los **criterios de aprobación se fijan
aquí, antes de ver ningún resultado**, y solo se podrán cambiar documentando el
motivo antes de ejecutar la prueba afectada.

Quién ejecuta: las pruebas que requieren MT5 las ejecuta John (o una sesión en
su equipo con MT5). Los resultados se guardan en el repo
(`results/<fecha>_<experimento>/`: `.set`, informe HTML/XML del tester y CSV
del EA) para que el análisis sea verificable.

---

## Fase 1 · Verificación técnica (Etapa D)

### 1.1 Compilación
- Compila sin errores en MetaEditor (build actual de John). Objetivo: 0 avisos;
  cada aviso restante se justifica.

### 1.2 Autotests (`Scripts/NBRL/NBRL_SelfTests.mq5`, sin operar)

| ID | Caso | Resultado esperado |
|---|---|---|
| T-DST-1 | 2024-03-10 06:59 UTC / 07:00 UTC | 01:59 EST / 03:00 EDT |
| T-DST-2 | 2024-11-03 05:59 UTC / 06:00 UTC | 01:59 EDT / 01:00 EST |
| T-DST-3 | 2025-03-09, 2025-11-02, 2026-03-08, 2026-11-01 | Cambios en esas fechas |
| T-DST-4 | Semana con EE. UU. en EDT y Europa aún en invierno (p. ej. 2025-03-12) | 09:35 NY = 13:35 UTC |
| T-VOL-1 | Pérdida por lote 400, riesgo 25, step 0,01, min 0,01 | 0,06 lotes |
| T-VOL-2 | Riesgo menor que pérdida con volumen mínimo | Rechazo `min_volume_exceeds_risk` |
| T-VOL-3 | `vol_raw` mayor que `vol_max` | `vol_max` |
| T-VOL-4 | Step 0,1 y `vol_raw` 0,19 | 0,1 (siempre hacia abajo) |
| T-SW-1 | Serie sintética con picos conocidos | Swings confirmados exactamente N velas después |
| T-SW-2 | Evaluación incremental vs. de una pasada | Mismas señales (sin look-ahead) |
| T-SL-1 | SL estructural más cerca que el mínimo | SL alejado al mínimo, nunca acercado |
| T-SL-2 | SL más lejos que `SLMaxATR` | Rechazo `sl_too_wide` |
| T-SL-3 | Trailing propone SL peor | Modificación descartada y registrada |
| T-DAY-1 | Real −0,8 % y nueva operación de 0,25 % | Rechazo (0,8 + 0,25 > 1) |
| T-DAY-2 | Cambio de día de trading a las 17:00 NY | Contadores y referencia reiniciados |
| T-ID-1 | Misma señal evaluada dos veces | Un único `signal_id` y una única operación |

### 1.3 Pruebas en el Strategy Tester (visual y no visual)

- Una semana con cada motor en solitario, modo "cada tick basado en ticks
  reales": revisar en el gráfico 20 señales al azar y comprobar a mano que
  cumplen las reglas de `02-reglas-motores.md` (lista de chequeo en el CSV).
- Ninguna posición sin SL; ninguna operación fuera de ventana; ninguna
  posición simultánea del magic; ningún `signal_id` repetido en `trades.csv`.
- Fin de sesión: todas las posiciones cerradas a las 15:55 NY con `CLOSE_ALL`.
- Spread elevado: ejecución con spread fijo alto (p. ej. ×3 del típico): las
  señales deben rechazarse por spread y registrarse.
- Rechazo de órdenes / desconexión: en demo, desactivar el trading
  algorítmico y reconectar con posición abierta; comprobar readopción y
  registros. (El tester no simula todos los retcodes; se documenta lo que no se
  pudo probar.)
- Modo solo análisis: mismas señales registradas, cero órdenes.

**Criterio Fase 1:** todos los autotests pasan y no hay ningún fallo crítico
(posición sin SL, duplicado, operación de otro magic tocada, límite diario
superado sin gap/deslizamiento que lo explique).

---

## Fase 2 · Backtest inicial (Etapa E)

- **Datos:** primero se mide el historial de ticks reales disponible en el
  servidor de Exness de John para el símbolo (fecha inicial, huecos). Objetivo
  2–3 años.
- **Partición propuesta (se ajusta a los datos disponibles antes de empezar):**
  - In-sample (IS): 2023-01-01 → 2025-06-30.
  - Out-of-sample (OOS) reservado: 2025-07-01 → 2026-06-30. **No se usa en las
    Fases 2–3.**
  - Forward/demo: desde 2026-07-01 y en tiempo real.
- Modelado: "cada tick basado en ticks reales"; depósito y divisa como la
  cuenta de John; comisión según su tipo de cuenta; retraso de ejecución
  aleatorio o fijo moderado.
- Un backtest por variante en solitario (A1, A2, B1, B2, C) con parámetros
  iniciales y salida base.
- Se guardan `.set`, informe y CSV de cada ejecución.

## Fase 3 · Optimización controlada (Etapa E, solo IS)

- Solo parámetros marcados "Optimizar" en `03-parametros.md`, una familia por
  experimento, rejilla gruesa (3–5 valores).
- Criterio de optimización: personalizado en `OnTester` =
  `expectativa_R × sqrt(N)` con N = nº de operaciones, y 0 si `N < 30` o
  `DD > 15R` (evita premiar pocas operaciones afortunadas).
- Se elige el centro de una **región** estable (vecinos ±1 paso con
  expectativa > 0), no el máximo aislado.
- Las salidas alternativas (BE, trailing, parcial, invalidación, tiempo) se
  prueban **una a una** contra la salida base con las mismas entradas.
- Los filtros opcionales se prueban uno a uno (ON vs OFF); un filtro solo se
  queda si mejora en IS **y** después en OOS.
- Todo experimento, incluido el fallido, se apunta en `docs/experimentos.md`
  (fecha, hipótesis, cambio único, periodo, resultado, decisión).

## Fase 4 · Validación fuera de muestra

- Una sola ejecución OOS por configuración candidata (máximo 3 candidatas por
  variante). Si se vuelve a ajustar tras ver el OOS, ese periodo deja de ser
  independiente y se marca como "contaminado" en el registro.
- Forward testing de MT5 configurado sobre el tramo final si se usa la
  optimización integrada.

## Fase 5 · Robustez

- Spread ×1,5 y ×2; deslizamiento adicional equivalente a 1 y 2 veces el spread típico
  (retraso de ejecución del tester o penalización en el análisis del CSV).
- Parámetros optimizados ±20 %.
- Desglose por año, mes, día de la semana, franja horaria, régimen (tendencia,
  consolidación, alta volatilidad), compras vs ventas.
- Dependencia de pocas operaciones: resultado quitando el 5 % de mejores
  operaciones y quitando el mejor mes.

## Fase 6 · Demo (Etapa F)

- Cuenta demo de Exness, mismo símbolo y tipo de cuenta que la real prevista.
- Duración: hasta tener al menos 40 operaciones de la variante (o 8 semanas,
  lo que llegue después). No se pasa a real por calendario.
- Cada semana: ejecutar el tester en ese mismo periodo con ticks reales y
  comparar señal a señal con el CSV de la demo.

---

## 4. Criterios cuantitativos de aprobación (fijados antes de probar)

Una variante **pasa a demo** solo si cumple **todos** en OOS:

| # | Criterio | Umbral |
|---|---|---|
| 1 | Operaciones OOS | ≥ 60 (si 30–59: "muestra insuficiente", no se aprueba ni descarta) |
| 2 | Expectativa neta (con comisión, swap y spread) | ≥ +0,10 R por operación |
| 3 | Profit factor neto | ≥ 1,15 |
| 4 | Intervalo de confianza | Límite inferior bootstrap 90 % de la expectativa en R > −0,05 R |
| 5 | Degradación IS → OOS | Expectativa OOS ≥ 50 % de la IS |
| 6 | Drawdown máximo | ≤ 12 R (≈ 3 % con 0,25 %/operación) y nunca se dispara el kill switch |
| 7 | Concentración | Sin el mejor 5 % de operaciones, expectativa ≥ 0; ningún mes aporta > 35 % del beneficio neto |
| 8 | Costes | Con spread ×1,5 la expectativa sigue ≥ 0 |
| 9 | Estabilidad de parámetros | ≥ 70 % de vecinos (±20 %) con expectativa > 0 en IS |
| 10 | Fallos técnicos | Cero fallos críticos (Fase 1) en todo el periodo |
| 11 | Frente al control | Supera al control aleatorio (§4.4) en expectativa R |

**Paso de demo a real (Etapa F):** expectativa demo ≥ 0 con ≥ 40 operaciones,
coincidencia de señales demo vs tester ≥ 90 %, deslizamiento medio dentro de lo
asumido en Fase 5, y decisión explícita de John. Nunca automático.

Los umbrales se podrán ajustar **antes** de la Fase 2 en función de la
cantidad y calidad de datos disponibles, dejando constancia del cambio.

### 4.4 Control aleatorio

Para cada variante, una ejecución "control" con el mismo contexto obligatorio
(p. ej. A.0 para el motor A, rango válido para B) pero dirección y momento de
entrada sin el disparador (entrada en la vela siguiente al contexto, misma
gestión de riesgo). Si la variante no supera al control, su disparador no
aporta información.

---

## 5. Informe por motor y variante

Generado por `PerformanceAnalyzer` (resumen en el diario y CSV) y por
`tools/analyze_logs.py` (completo) con todas las métricas del SPEC §13:
operaciones, % aciertos, beneficio y pérdida brutos, neto, PF, expectativa en
dinero y en R, DD monetario y %, duración media, ganancia/pérdida media, mayor
racha de pérdidas, por día de la semana, por franja horaria (30 min NY), por
régimen, compras vs ventas, MFE/MAE (distribución en R), costes (spread,
comisión, swap, deslizamiento) e histórico vs forward.

Incluye siempre la **tabla de concentración** (contribución del top 5 %/10 %
de operaciones y distribución de R) para detectar estrategias que ganan por
unas pocas operaciones extraordinarias con muchas pequeñas pérdidas, y el
**embudo de señales**: detectadas → rechazadas por cada filtro → ejecutadas.

## 6. Si una variante no funciona (SPEC §15)

1. Localizar el fallo con el CSV: ¿entrada (MAE alto inmediato), salida (MFE
   alto que acaba en pérdida), costes, horario, régimen, exceso de
   operaciones?
2. Conservar las estadísticas originales (no se sobrescribe ningún resultado).
3. Escribir la hipótesis en `docs/experimentos.md` antes de cambiar nada.
4. Cambiar una sola familia de parámetros.
5. Repetir IS y, si mejora, una sola vez OOS.
6. Comparar con la versión anterior en la misma tabla.

Hipótesis alternativas reservadas (no implementadas en v1): continuación de
tendencia tras retroceso, retroceso después de ruptura, contracción-expansión
de volatilidad, reversión tras barrido de extremos.
