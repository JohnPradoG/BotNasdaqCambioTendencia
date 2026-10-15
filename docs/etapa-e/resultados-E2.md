# Resultados E2: 10 variantes sin kill switch

Ejecución 2026-10-14 22:41 → 00:04 (PC de John), `ejecutar_etapa_e.bat`, carpeta local `results\2026-10-14_2241_E_IS_diag_nokill` (no subida al repositorio). USTECm, 2021-11-01 → 2024-12-31, ticks generados desde M1, spread diagnóstico cobrado completo, `MaxTotalDDPct=100`. Las 10 terminaron; ninguna activó el kill switch. Cifras leídas por la sesión remota de la PC, no recalculadas aquí.

| Prueba | Ops | Acierto | Expect. R | IC 90 % | PF | Neto USD | DD máx |
|---|---|---|---|---|---|---|---|
| M5 A1 | 1.052 | 33,8 % | −0,177 | [−0,239; −0,114] | 0,74 | −3.733,94 | 38,01 % |
| M5 A2 | 162 | 27,8 % | −0,338 | [−0,475; −0,195] | 0,55 | −1.269,94 | 13,02 % |
| M5 B1 | 1.172 | 35,9 % | −0,129 | [−0,186; −0,070] | 0,80 | −3.149,91 | 32,46 % |
| M5 B2 | 555 | 30,1 % | −0,254 | [−0,338; −0,169] | 0,63 | −2.974,55 | 30,57 % |
| M5 C1 | 2.179 | 34,5 % | −0,152 | [−0,192; −0,109] | 0,78 | −5.635,09 | 58,64 % |
| M15 A1 | 421 | 33,0 % | −0,198 | [−0,294; −0,105] | 0,72 | −1.884,38 | 19,29 % |
| M15 A2 | 51 | 49,0 % | +0,224 | [−0,072; 0,520] | 1,43 | +283,35 | 1,66 % |
| M15 B1 | 667 | 37,0 % | −0,100 | [−0,175; −0,021] | 0,84 | −1.540,49 | 16,97 % |
| M15 B2 | 315 | 33,7 % | −0,167 | [−0,277; −0,056] | 0,75 | −1.226,14 | 13,54 % |
| M15 C1 | 1.299 | 37,0 % | −0,092 | [−0,147; −0,036] | 0,85 | −2.598,04 | 31,99 % |

Suma en R por año (2022 / 2023 / 2024):
- M5: A1 −80/−50/−51; A2 −16/−17/−15; B1 −94/−21/−31; B2 −85/−30/−13; C1 −99/−140/−89.
- M15: A1 −12/−33/−35; A2 +6,4/+5,5/−0,5; B1 −11/−31/−17; B2 −25/−13/−13; C1 −40/−56/−23.

## Lectura
1. 9 de las 10 pierden de forma estable, con el IC entero bajo cero y en todos los años: sin el freno del 6 % no era solo un 2022 malo. Con estas reglas y costes no hay ventaja.
2. M15 pierde cerca de la mitad que M5 en las mismas reglas; el coste (spread ≈5 puntos) pesa menos en velas más grandes.
3. M15 A2 repite la E1 (nunca llegó al 6 %), pero falló en el OOS (−0,181 R, ver `resultados-OOS.md`). Descartada.
4. Más cercanas a cero: M15 C1 (−0,092 R) y M15 B1 (−0,100 R), aún negativas.
5. El M5 A1 repetido da −0,177 R frente a −0,174 R del 10-10: mismo nº de operaciones, ligera diferencia de neto, no verificada su causa.

Conclusión: ninguna de las 10 combinaciones tiene ventaja demostrable; no pasar a demo. Siguientes ideas: motor D impulso + order block (`propuesta-D-impulso-ob.md`), marcos más altos, operar a favor de la tendencia de fondo, cuenta con menos spread. Cada una probada primero en 2021-2024.
