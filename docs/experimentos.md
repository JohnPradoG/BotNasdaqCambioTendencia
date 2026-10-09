# Registro de experimentos

Todo experimento se apunta aquí **antes** de ejecutarlo (hipótesis y cambio) y
se completa después con el resultado real, incluidos los fallidos (SPEC §14 y
§15). Ningún resultado se escribe sin el informe o CSV de MT5 correspondiente
en `results/`.

| ID | Fecha | Variante | Hipótesis | Cambio (una familia) | Periodo | Resultado (archivo) | Decisión |
|---|---|---|---|---|---|---|---|
| D0 | 2026-10-09 | Todas (solo análisis) | Prueba técnica: el EA corre sin errores y registra señales | — | USTECm 2024-01→03, OHLC 1 min | `docs/etapa-d/resultados-D0.md` | 0 errores; 1768 señales, todas rechazadas, 61 % por spread/ATR |
| E1-diag | 2026-10-09 (pendiente) | A1, A2, B1, B2, C1 por separado | Diagnóstico: ¿hay ventaja neta de spread en M5? | Filtros de spread: `F_MaxSpreadATRFrac` 0,10 → 0,50 y `F_SpreadRFrac` 0,15 → 0,30 (el spread se cobra igual) | USTECm IS 2021-11-01 → 2024-12-31, ticks reales | — | — |
| E1-diag-M15 | 2026-10-09 (pendiente) | A1, A2, B1, B2, C1 por separado | Con entradas M15 (contexto H1) el spread pesa menos que en M5 | Igual que E1-diag + `InpTFEntry` M5 → M15, `InpTFContext` M15 → H1; parámetros en velas sin cambiar | USTECm IS 2021-11-01 → 2024-12-31, ticks reales | — | — |
