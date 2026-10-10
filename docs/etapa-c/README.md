# Etapa C · Falsas rupturas, salidas y auditoría (v0.2)

> **Estado real (2026-10-09):** el commit 88006db compila en el MetaEditor de
> John con 0 errores y 0 avisos (EA: `Result: 0 errors, 0 warnings`;
> NBRL_SelfTests: `Result: 0 errors, 0 warnings`). Ni el EA ni los autotests
> se han ejecutado todavía; no hay backtests ni resultados.

## Qué se añadió

| Pieza | Archivo | Contenido |
|---|---|---|
| Motor C | `MQL5/Include/NBRL/FalseBreakoutEngine.mqh` | Vigila zonas (swings M15, día anterior, overnight) y el rango activo del motor B. Clasifica cada sobrepaso en `TRUE_BREAK`, `FALSE_RETURN`, `EXTEND_REVERT` o `SWEEP_UNCONFIRMED` (más `TRUE_BREAK_HELD`, `UNRESOLVED`, `RETURN_UNCLASSIFIED`) y registra todos los eventos en `events.csv`. Solo emite C1 tras `FALSE_RETURN` o `EXTEND_REVERT` con vela de confirmación o ruptura del último mínimo/máximo de la excursión, con excursión acotada y una sola señal por nivel y dirección. |
| Salidas | `PositionManager.mqh` | Trailing por estructura (último swing M5 a favor desde la entrada + margen), cierre parcial único (si el volumen se puede dividir respetando mínimo y step) y salida por invalidación por variante (A1 temporal, A2 vuelta sobre `L_micro`, B1/B2 vuelta al rango en `B_ReentryBars`, C1 vuelta al otro lado del nivel). Todas en OFF por defecto. |
| Auditoría | `TradeLogger.mqh` (Etapa B) | Ya registraba todas las señales (también rechazadas, con motivo), operaciones y eventos. La Etapa C añade los eventos del motor C y de salidas parciales. |
| Informe | `tools/analyze_logs.py` | Informe Markdown por variante con las métricas del SPEC §13: aciertos, bruto, neto, PF, expectativa en dinero y en R, IC 90 % bootstrap, DD, duración, medias, racha, MFE/MAE, costes, concentración (peso del 5 %/10 % mejor y expectativa sin ellos), desgloses por día, franja de 30 min, bloque horario, régimen, compra/venta, motivo de salida, histórico vs forward, y embudo de señales con motivos de rechazo. Solo biblioteca estándar de Python. |
| Presets | `presets/*.set` | Una configuración por variante en solitario (A1, A2, B1, B2, C1) y una de solo análisis con todo activo. Símbolo `USTEC_x100m`, servidor UTC+0, registros en la carpeta común. |

El informe se probó aquí solo con CSV sintéticos para comprobar que el
script funciona; esos números no son resultados del EA.

## Plantilla de registro CSV (SPEC §17.11)

Separador `;`, una cabecera por archivo (definidas en `TradeLogger.mqh`):

- `signals.csv`: una fila por señal detectada con su estado final
  (`EXECUTED`, `REJECTED`, `ANALYSIS_ONLY`, `ERROR`) y el motivo de rechazo
  (`engine:…`, `session:…`, `risk:…`, filtro, `conflict`, `opposite_conflict`,
  `position_open`, `sl_too_wide`, `sl_wrong_side`).
- `trades.csv`: una fila por posición cerrada, con entrada, SL/TP iniciales,
  volumen, riesgo previsto, spread y deslizamiento, salida, motivo, comisión,
  swap, neto, resultado en R, MFE/MAE, duración y número de modificaciones.
- `events.csv`: inicio, cambio de día, setups armados y cancelados, eventos
  del motor C, entradas, modificaciones, parciales, salidas, límites de riesgo
  y errores.

## Cómo generar el informe

```
python3 tools/analyze_logs.py --dir "<Common>/Files/NBRL/USTEC_x100m_26100901" \
    --capital 10000 --split 2025-01-01 --out informe.md
```

`--capital` es el capital de referencia del DD %; `--split` separa el periodo
histórico (in-sample) del forward/out-of-sample.

## Qué falta

- Ejecutar los autotests en MT5 (Etapa D).
- Casos límite de la Fase 1 del plan de pruebas (Etapa D).
- Backtests y comparación A/B (Etapa E).
