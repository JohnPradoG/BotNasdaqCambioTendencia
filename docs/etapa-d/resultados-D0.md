# Etapa D · Resultados reales de la ejecución D0 (2026-10-09)

Ejecutado por John con `tools/mt5/ejecutar_etapa_d.bat` en su PC (carpeta
local `results/2026-10-09_1448_D0_smoke`). Los archivos no están en el repo:
el filtro de permisos del PC bloqueó el commit de logs del terminal. Las cifras
de abajo están copiadas de esos archivos.

## Compilación

- EA: `Result: 0 errors, 0 warnings`
- Autotests: `Result: 0 errors, 0 warnings`

## Autotests (USTEC_x100m, M5)

`NBRL autotests: 50 OK, 0 FAIL`. Pasan todos los casos de
`docs/etapa-a/05-plan-pruebas.md` §1.2: T-DST-1..4, T-SW-1..2, T-VOL-1..4,
T-SL-1..3, T-TP, T-DAY-1..2 y T-ID-1.

## Prueba corta en el Strategy Tester

- Configuración: USTECm M5, 2024-01-01 → 2024-03-31, OHLC de 1 minuto (ticks
  **generados**), solo análisis, todas las variantes, depósito 10 000 USD.
- Historial sincronizado: 2021-10-27 → 2026-10-07.
- Log del agente: sin errores ni avisos. "Test passed in 0:00:57".
  Saldo final 10 000 USD, `OnTester result 0` (menos de 30 operaciones).
- Hora NY verificada en enero: servidor 00:30 → NY 19:30 (UTC−5).
- Símbolo (INIT): digits 2, point 0,01, contrato 1, tick_value 0,01,
  **vol_min 0,05**, vol_step 0,01, stops_level 0, spread al inicio 497 puntos.

### Señales

1768 señales, **todas REJECTED**; 0 operaciones (no hay `trades.csv`).

| Variante | Detectadas | Principal motivo de rechazo |
|---|---|---|
| A1 | 146 | spread_atr 97 |
| A2 | 57 | engine:chase 36 |
| B1 | 428 | spread_atr 173, sl_too_wide 87 |
| B2 | 96 | spread_atr 88 |
| C1 | 1041 | spread_atr 709, sl_too_wide 112 |

Motivos totales: spread_atr 1081, sl_too_wide 219, conflict 136,
engine:excursion_too_big 93, engine:no_expansion 70, engine:weak_body 63,
engine:chase 54, session:reopen_block 25, session:symbol_closed 20,
session:friday_cutoff 7.

### Hallazgo principal: el spread

- Spread en las señales: mediana 513 puntos (≈ 5,1 puntos del índice),
  máximo 634.
- ATR M5 en las señales: mediana 9,18 puntos del índice.
- Spread / ATR M5: mediana **0,43**, frente al límite `F_MaxSpreadATRFrac = 0,10`.
- En algunas señales el spread supera la distancia al SL (p. ej. C1 con SL a
  4,18 puntos y spread de 4,87).

Con el spread que registra el probador para esta cuenta (Standard), el filtro
de calidad rechaza casi todo. Pendiente de verificar: si ese spread es el
típico de la cuenta en horario de NY o está inflado por el historial del
probador (la muestra empieza en sesión asiática).

## Qué no se probó

- Ticks reales (modelo 4), modo visual, spread ×3, fin de semana y readopción
  (§1.3 del plan).
- `PrintSummary` no imprimió nada al no haber operaciones.
