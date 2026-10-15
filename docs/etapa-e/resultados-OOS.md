# Resultado OOS: A2 en M15 (configuración congelada)

Ejecución única, 2026-10-14, `ejecutar_oos_a2_m15.bat`, preset `NBRL_OOS_A2_M15_USTECm.set`, USTECm, 2025-01-01 → 2026-06-30. Compilación 0 errores / 0 avisos. Calidad del historial: 33 % ticks reales (2026 reales, 2025 generados desde M1). Carpeta en el PC de John: `results\2026-10-14_2227_OOS_A2_M15` (no subida al repositorio).

**Veredicto: no pasa.** El plan §4 exigía ≥60 operaciones y ≥+0,10 R; salieron 51 operaciones y −0,181 R.

| Métrica | OOS 2025-H1 2026 | IS 2021-2024 (E1) |
|---|---|---|
| Operaciones | 51 (17 TP / 34 SL) | 51 |
| Acierto | 33,3 % | — |
| Expectativa | −0,181 R, IC90 [−0,463; 0,099] | +0,22 R |
| Sin el 5 % mejor | −0,288 R | — |
| PF | 0,73 | 1,43 |
| Neto | −229,35 USD | — |
| DD máx. | 3,42 % | 1,7 % |
| Peor racha | 8 pérdidas | — |
| Spread medio entrada | ≈2 puntos de índice (1,8 en 2025, 2,3 en 2026) | ≈5 |

## Desgloses
- Año: 2025 → 30 ops, 23,3 % acierto, −0,418 R, −305 USD. 2026 → 21 ops, 47,6 %, +0,158 R, +76 USD.
- Dirección: compras 8 ops, −0,070 R; ventas 43 ops, −0,202 R. En 2021-2024 las compras aportaban casi todo el beneficio; aquí se vendió casi siempre mientras el Nasdaq pasó de ~21.500 a ~30.000.
- Sesión: Asia 26 ops −0,254 R; Europa 18 ops −0,169 R; NY 3 ops +1,479 R; Post 4 ops −1,005 R.
- Régimen: TREND 30 ops +0,062 R; MIXED 12 ops −0,377 R; RANGE 9 ops −0,731 R.
- Señales: 89 detectadas, 51 ejecutadas, 38 rechazadas (32 por `engine:chase`, 4 `symbol_closed`, 2 `position_open`). Kill switch sin activarse.
- Una pérdida de −1,63 R (2026-04-10, ticks reales), probable hueco de precio en el SL.

## Lectura
La ventaja de M15 A2 en 2021-2024 no se repite fuera de muestra. El +0,158 R de 2026 (21 ops) es demasiado poco para fiarse y no compensa 2025. El IC incluye cero, pero el punto central es negativo, así que no hay base para promover la variante. Según el protocolo, esta prueba no se repite ni se reajusta; cualquier cambio posterior a A2/M15 marca el OOS como contaminado.

Nota: el log del agente muestra dos arranques; solo el segundo terminó y es el que corresponde al resultado.
