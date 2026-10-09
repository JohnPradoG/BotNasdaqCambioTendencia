# 02 · Reglas exactas de entrada y salida por motor (Etapa A)

Definiciones (velas cerradas, swings, zonas, ATR, R, reglas comunes de SL)
en `01-documento-tecnico.md` §4. Nombres de parámetros entre `` ` `` y con su
valor inicial entre paréntesis; tabla completa en `03-parametros.md`.

Se describen las reglas **de venta**; las de compra son el espejo exacto
(máximo ↔ mínimo, arriba ↔ abajo, `>` ↔ `<`). Toda señal pasa después por
`SignalQualityFilter` (filtros opcionales) y `RiskManager`; aquí solo se
definen las condiciones propias del motor.

Notación: `C, O, H, L` = cierre, apertura, máximo, mínimo de M5; `[1]` = última
vela cerrada. `ATRe` = ATR14 M5, `ATRc` = ATR14 M15. `rango(v) = H − L`,
`cuerpo(v) = |C − O|`.

---

## MOTOR A · Anticipación de giros

### A.0 Contexto obligatorio (A1 y A2), evaluado en M15 cerrado

1. **Tramo previo amplio.** En las últimas `A_LegLookback` (24) velas M15:
   `LegLow` = mínimo más bajo, `LegHigh` = máximo más alto **posterior** a
   `LegLow`. Se exige
   - `LegHigh − LegLow >= A_LegMinATR (3,0) × ATRc`, y
   - al menos `A_LegMinBars` (6) velas M15 entre `LegLow` y `LegHigh`.
2. **Extremo vigente.** `H* = LegHigh` (puede actualizarse con M5: si un M5
   cerrado hace un máximo mayor, `H*` pasa a ser ese máximo). El precio actual
   `C[1]` está a menos de `A_MaxDistFromExtremeATR (1,0) × ATRc` de `H*`.
3. **Zona relevante (opcional, `A_RequireZone` = true).** `H*` está dentro de
   una zona de resistencia (§4.4 del documento técnico) **o** `H*` es el máximo
   de las últimas 96 velas M15. Si `A_RequireZone=false`, se registra igualmente
   si estaba en zona, para poder medir su efecto.

Si no se cumple el contexto, el motor A no evalúa nada más en esa vela.

### A.1 Evidencias de agotamiento (M5), puntuación 0–4

Cada componente vale 1 punto si se cumple en la vela `[1]` (o la ventana
indicada). El registro guarda qué componentes se cumplieron.

| Código | Componente | Regla exacta |
|---|---|---|
| `DEC` | Pérdida de aceleración | `k = A_DecelK (3)`. `imp_prev = C[1+k] − C[1+2k]`, `imp_rec = C[1] − C[1+k]`. Se cumple si `imp_prev > 0,5×ATRe` y `imp_rec < A_DecelRatio (0,5) × imp_prev`. |
| `WCK` | Rechazo por mecha en el extremo | En alguna de las últimas 3 velas `v`: `H[v] >= H* − 0,1×ATRe`, `rango(v) >= 0,8×ATRe`, mecha superior `H[v] − max(O[v],C[v]) >= A_WickMinRatio (0,5) × rango(v)` y `C[v]` en la mitad inferior del rango. |
| `FAIL` | Fallos sucesivos en la zona | En las últimas `A_FailLookback` (12) velas M5 hay al menos `A_FailMinTouches` (2) **toques** del extremo: vela con `H >= H* − A_FailTolATR (0,15)×ATRe` y `C < H* − A_FailTolATR×ATRe`, separados por al menos 2 velas, y ningún cierre por encima de `H* + A_FailTolATR×ATRe` desde el primer toque. |
| `DIV` | Divergencia RSI (opcional, `A_UseRSIDiv` = true) | Dos últimos swing highs M5 confirmados `SH1` (anterior) y `SH2` (reciente), ambos dentro del tramo: `H(SH2) >= H(SH1)` y `RSI14(SH2) <= RSI14(SH1) − A_RSIDivMin (3)` con `RSI14(SH1) >= 60`. |

**Condición de agotamiento:** puntuación `>= A_MinScore` (2). Como la
puntuación exige al menos dos componentes, ninguna señal puede producirse solo
por RSI, solo por una mecha o solo por el color de una vela (SPEC §4). El
momento en que se cumple por primera vez define `t_setup`. El setup queda
**armado** hasta que se dispare, se invalide o expire.

### A.2 Invalidación del setup (antes de entrar)

- Un cierre M5 por encima de `H* + A_InvalidBufATR (0,2) × ATRe` (nuevo
  máximo aceptado): el setup se cancela; si el contexto sigue vigente, puede
  armarse uno nuevo con el nuevo `H*` (nuevo `structure_id`).
- Expiración: `A_SetupExpiryBars` (12) velas M5 sin disparo.
- Fin de la ventana de nuevas entradas (SessionManager).

### A.3 Disparo · variante A1 (agresiva)

Con el setup armado, en la vela `[1]`:

- `C[1] < O[1]` **y** `C[1] < L[2]` (vela bajista que cierra bajo el mínimo de
  la anterior), **y**
- `cuerpo[1] >= 0,4 × rango[1]`.

Entrada a mercado en la apertura de la vela siguiente. El disparo puede
coincidir con la misma vela que completa el agotamiento.

### A.4 Disparo · variante A2 (confirmación estructural)

- `L_micro` = último swing low M5 confirmado anterior a `H*` y posterior a
  `LegLow` (último mínimo más alto del tramo).
- Disparo: `C[1] < L_micro − A_BreakBufATR (0,05) × ATRe`.
- **Anti-persecución:** se rechaza si `H* − C[1] > A2_MaxChaseATR (1,5) × ATRc`
  (la confirmación llegó demasiado tarde; `reject: chase`).
- Si no existe `L_micro` confirmado, A2 no puede dispararse en ese setup.

### A.5 Stop loss, objetivo y salidas (A1 y A2)

- **SL estructural:** `H* + SLBufferATR (0,1) × ATRe` + spread, con las reglas
  comunes de mínimo/máximo (documento técnico §4.7).
- **TP:** `entrada − TP_R (1,5) × R`.
- **Espacio disponible (filtro opcional `F_Room`):** la zona de soporte más
  cercana por debajo debe estar a `>= F_RoomMinR (1,0) × R`.
- **Salida por invalidación (opcional, `X_Invalidation`=false):**
  - A1: como un cierre por encima de `H*` ya lo cubre el SL, la invalidación es
    temporal: si tras `X_InvalidBars` (6) velas el MFE es `< 0,5R` y
    `C[1] > entrada`, se cierra.
  - A2: un cierre M5 de nuevo por encima de `L_micro + 0,5×ATRe` cierra la
    posición.
- Resto de salidas: comunes (§D).

`structure_id` de A = `A|LegLowTime|H*Time`.

---

## MOTOR B · Rupturas de consolidación

### B.0 Detección del rango (M5 por defecto, `B_RangeTF`)

Evaluada en cada vela cerrada, sobre las velas `[2 .. N+1]` (la vela `[1]` es
la candidata a ruptura y no forma parte del rango):

1. Para `N` desde `B_RangeMaxBars` (48) hasta `B_RangeMinBars` (12), se toma el
   **mayor** `N` que cumple todas las condiciones siguientes:
   - `Top = max(H[2..N+1])`, `Bot = min(L[2..N+1])`, `W = Top − Bot`.
   - **Anchura:** `B_RangeMinATR (0,8) × ATRc <= W <= B_RangeMaxATR (3,0) × ATRc`.
   - **Compresión:** media de `rango(v)` dentro del rango
     `<= B_CompressionMax (0,8) × ATR14(M5)` medido justo antes del inicio del
     rango (vela `N+2`).
   - **Toques (calidad):** al menos `B_MinTouches` (2) velas con
     `H >= Top − 0,15×W` y al menos 2 con `L <= Bot + 0,15×W`.
   - **Cierres dentro:** como mucho `B_MaxOutsideCloses` (0) cierres fuera de
     `[Bot, Top]` (por construcción con máximos/mínimos es 0; se deja el
     parámetro por si se pasa a rango por cierres).
2. Si ningún `N` cumple, no hay rango activo.
3. `range_id = B|TF|time(N+1)|time(2)`. Un mismo `range_id` puede producir
   como máximo **una** señal por dirección y variante.
4. Tras una ruptura válida en una dirección, no se evalúan nuevas rupturas en
   esa misma dirección durante `B_CooldownBars` (12) velas: la ventana del
   rango se desplaza con cada vela y, sin esta regla, el mismo movimiento
   podría volver a generar señal con otro `range_id`.

### B.1 Confirmación de ruptura (común a B1 y B2), venta = ruptura bajista

En la vela `[1]` con rango activo:

- **Distancia:** `C[1] < Bot − B_BreakDistATR (0,1) × ATRe`.
- **Impulso:** `cuerpo[1] >= B_BodyRatio (0,5) × rango[1]`.
- **Expansión:** `rango[1] >= B_ExpansionATR (1,0) × ATRe`.
- **Volumen tick (opcional, `F_TickVol`):** `TickVolume[1] >= B_TickVolMult
  (1,2) × media(TickVolume del rango)`. El volumen tick de un CFD no es volumen
  real; se trata como hipótesis.
- **No persecución:** movimiento esperado `M = B_ExpectedMoveMult (1,0) × W`.
  Se rechaza si `Bot − C[1] > B_MaxChaseFrac (0,4) × M`.

### B.2 Variante B1 · entrada directa

- Entrada a mercado en la apertura de la vela siguiente a la ruptura.
- **SL estructural** según `B_SLMode`:
  - `0` (por defecto): punto medio del rango `Bot + W/2`.
  - `1`: máximo de la vela de ruptura `H[1]`.
  - `2`: lado opuesto del rango `Top`.
  Más `SLBufferATR × ATRe` + spread y reglas comunes.
- **TP:** `TP_R` (1,5) × R; alternativa `B_TPMode=1`: objetivo de movimiento
  medido `Bot − M` (solo si `>= 1R`).

### B.3 Variante B2 · entrada tras retesteo

Tras una ruptura confirmada (B.1), se abre una espera de `B_RetestMaxBars` (12)
velas M5:

- **Vela de retesteo `r`:** `H[r] >= Bot − B_RetestTolATR (0,2) × ATRe` y
  `C[r] <= Bot` (el nivel roto aguanta como resistencia).
- **Disparo:** la propia `r` es bajista (`C[r] < O[r]`) **o** una de las 2
  velas siguientes cierra por debajo de `L[r]`. Entrada a mercado en la
  apertura siguiente.
- **SL estructural:** `max(H[r], Bot) + SLBufferATR × ATRe` + spread, reglas
  comunes.
- **TP:** igual que B1.
- **Cancelación de la espera:** (a) cierre M5 `> Bot + B_ReentryTolATR (0,2)
  × ATRe` (vuelta al rango); (b) se agotan las `B_RetestMaxBars` velas sin
  retesteo; (c) el precio se aleja más de `B_MaxChaseFrac × M` sin retestear
  (ya no hay R:R aceptable). La cancelación se registra con su motivo.

### B.4 Invalidación con posición abierta (opcional, `X_Invalidation`)

Si en las `B_ReentryBars` (3) velas siguientes a la entrada una vela cierra de
nuevo dentro del rango (`C > Bot + B_ReentryTolATR × ATRe`), se cierra a
mercado (`exit: reentry`). Desactivado por defecto en la configuración base.

### B.5 Independencia B1/B2

Ambas variantes usan la misma ruptura pero son señales distintas
(`variant` distinto en `signal_id`). Como solo se permite una posición por
símbolo y magic, las pruebas de la Etapa E evalúan **B1 y B2 por separado**.
En modo combinado gana la primera en dispararse y la otra se registra como
`reject: position_open`.

---

## MOTOR C · Falsas rupturas

### C.0 Niveles vigilados

Techo y suelo del rango activo del motor B, swings M15 confirmados, máximo y
mínimo del día anterior y del overnight (zonas del documento técnico §4.4).
Un nivel solo se vigila si se formó al menos `C_MinLevelAgeBars` (6) velas M5
antes del evento.

### C.1 Evento de sobrepaso (caso nivel superior `Lv`)

Ocurre en la vela `j` si `H[j] > Lv + C_SweepMinATR (0,1) × ATRe`. Se abre una
ventana de clasificación de `C_WindowBars` (6) velas M5 y se calcula la
excursión `E = máximo H desde j`.

### C.2 Clasificación (cada evento recibe exactamente una etiqueta)

Evaluada vela a vela, la primera que se cumple fija la etiqueta:

| Etiqueta | Regla |
|---|---|
| `TRUE_BREAK` (ruptura verdadera) | Al menos `C_HoldBars` (2) cierres consecutivos `> Lv + B_BreakDistATR×ATRe` y ningún cierre de vuelta `< Lv` dentro de la ventana. |
| `FALSE_RETURN` (falsa con regreso) | Dentro de `C_WindowBars`, un cierre `< Lv − C_ReentryDepthATR (0,1) × ATRe`, habiendo tenido como mucho 1 cierre por encima de `Lv`. |
| `EXTEND_REVERT` (se extiende y revierte) | Hubo `TRUE_BREAK` o al menos 2 cierres por encima de `Lv`, la excursión alcanzó `E − Lv >= 0,5 × ATRc`, y dentro de `C_LateWindowBars` (12) hay un cierre `< Lv − C_ReentryDepthATR × ATRe`. Reetiqueta un `TRUE_BREAK` previo (se registra como evento nuevo, la señal original no se modifica). |
| `SWEEP_UNCONFIRMED` (barrido sin confirmación) | Solo mechas por encima de `Lv` (ningún cierre por encima) y al cerrar la ventana no hubo cierre `< Lv − C_ReentryDepthATR × ATRe`. **Nunca opera.** |

Todos los eventos se registran (también los que no generan operación), con su
etiqueta, para medir la frecuencia de cada tipo.

### C.3 Señal de venta (solo `FALSE_RETURN` o `EXTEND_REVERT`)

En la vela `[1]` que produce la etiqueta, además:

- **Confirmación:** `cuerpo[1] >= C_BodyRatio (0,5) × rango[1]` y `C[1] < O[1]`,
  **o** cierre por debajo del último swing low M5 formado durante la excursión.
- **Excursión acotada:** `E − Lv <= C_MaxExcursionATR (1,5) × ATRc` (si es
  mayor, el SL sería demasiado amplio → `reject: excursion_too_big`).
- Entrada a mercado en la apertura siguiente.
- **SL estructural:** `E + SLBufferATR × ATRe` + spread, reglas comunes.
- **TP:** `TP_R` (1,5) × R; alternativa `C_TPMode=1`: punto medio del rango (si
  el nivel es de un rango B y está a `>= 1R`).
- Máximo una señal C por nivel y dirección (`structure_id = C|Lv|tiempo_j`).

No se utiliza ningún lenguaje ni regla basada en "manipulación" o "liquidez
institucional": el motor describe y mide un patrón de precio.

---

## D · Salidas comunes (PositionManager)

Cada mecanismo tiene su interruptor y se evalúa **por separado** frente a la
salida base (SL + TP en R + fin de sesión).

| Código | Mecanismo | Regla | Por defecto |
|---|---|---|---|
| `X_TP` | Objetivo en R | `TP_R` ∈ {1,0; 1,5; 2,0} | ON, 1,5 |
| `X_Session` | Fin de sesión | Modo 24/5: cierre del viernes 16:30 NY (`WeekendClosePolicy`). Modo `WINDOW`: a las 15:55 NY. `CLOSE_ALL` o `KEEP_WITH_SL` | ON, CLOSE_ALL |
| `X_BE` | Break-even | Cuando MFE `>= X_BETriggerR (1,0)` R, SL a entrada + costes estimados | OFF |
| `X_TrailATR` | Trailing ATR | Activo desde MFE `>= X_TrailStartR (1,0)` R; SL = máximo favorable − `X_TrailATRMult (2,0) × ATRe`, solo si mejora el SL | OFF |
| `X_TrailStruct` | Trailing por estructura | SL al último swing M5 confirmado a favor + buffer, solo si mejora | OFF |
| `X_Partial` | Cierre parcial | `X_PartialFrac (50%)` a `X_PartialR (1,0)` R; el resto sigue con su salida | OFF |
| `X_Invalidation` | Invalidación de la señal | Reglas por motor (A.5, B.4) | OFF |
| `X_MaxBars` | Tiempo máximo | Cierre tras `X_MaxBarsM5 (24)` velas M5 | OFF |

Garantías:

- **El SL nunca se aleja** (comprobación previa a cada modificación; si el
  nuevo SL es peor, la modificación se descarta y se registra el intento).
- Las modificaciones respetan stops level y freeze level; si no se puede
  modificar por freeze level, se reintenta en el siguiente tick, no en bucle.
- MFE y MAE se actualizan en cada tick con Bid/Ask según dirección y se
  registran en R y en precio al cerrar.

## E · Prioridad y conflictos entre motores

- Una sola posición por símbolo y magic (SPEC §9).
- Si varias señales aparecen en la misma vela: orden `Priority` configurable
  (por defecto C > B2 > B1 > A2 > A1, de más a menos confirmada). Las no
  ejecutadas se registran como `reject: conflict`.
- Una señal y su opuesta en la misma vela se anulan ambas
  (`reject: opposite_conflict`) para no depender del orden de evaluación.
- `MaxTradesPerSignal` = 1: un `signal_id` produce como máximo una operación.
