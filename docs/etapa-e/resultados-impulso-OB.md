# Resultado: estudio rápido impulso + order block (IS 2021-11 → 2024-12)

Ejecutado el 2026-10-15 en el PC de John con `tools/estudio_impulso.py` (Python sobre M1 de USTECm, M15, spread fijo 5 puntos, TP 1,5R, SL estructural, 18 combinaciones fijadas antes en `propuesta-D-impulso-ob.md`). 2025-2026 no se tocó. Tabla completa en el PC: `results\estudio_impulso_IS.md`. Cifras leídas por la sesión remota, no recalculadas aquí.

**Veredicto: ninguna fila cumple el criterio** (n ≥ 60, R con spread ≥ +0,10, IC90 inferior > −0,05, positiva en 2022/2023/2024 y mejor que el azar).

| k | vol | modo | n | R sin spread (IC90) | R con spread (IC90) | azar con spread | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|---|---|---|---|
| 1,5 | - | D0 | 1803 | +0,054 [+0,006; +0,102] | −0,072 [−0,119; −0,026] | −0,126 | −0,09 | −0,08 | −0,07 |
| 1,5 | - | D1 | 434 | −0,009 | −0,263 | −0,247 | −0,40 | −0,24 | −0,15 |
| 1,5 | P70 | D0 | 1440 | +0,069 [+0,016; +0,123] | −0,042 [−0,094; +0,011] | −0,096 | −0,02 | −0,06 | −0,06 |
| 1,5 | P70 | D1 | 349 | −0,019 | −0,241 | −0,121 | −0,35 | −0,27 | −0,14 |
| 1,5 | P80 | D0 | 1145 | +0,114 [+0,053; +0,174] | +0,004 [−0,055; +0,064] | −0,086 | +0,02 | +0,02 | −0,04 |
| 1,5 | P80 | D1 | 277 | −0,025 | −0,251 | −0,224 | −0,33 | −0,26 | −0,20 |
| 1,8 | - | D0 | 1190 | +0,027 | −0,101 | −0,160 | −0,09 | −0,11 | −0,14 |
| 1,8 | - | D1 | 291 | −0,072 | −0,321 | −0,175 | −0,43 | −0,29 | −0,26 |
| 1,8 | P70 | D0 | 1004 | +0,048 | −0,071 | −0,137 | −0,06 | −0,07 | −0,12 |
| 1,8 | P70 | D1 | 243 | −0,033 | −0,270 | −0,126 | −0,36 | −0,27 | −0,25 |
| 1,8 | P80 | D0 | 841 | +0,094 [+0,024; +0,164] | −0,028 [−0,097; +0,041] | −0,109 | −0,03 | +0,01 | −0,10 |
| 1,8 | P80 | D1 | 204 | +0,005 | −0,240 | −0,154 | −0,34 | −0,25 | −0,20 |
| 2,2 | - | D0 | 623 | −0,017 | −0,105 | −0,131 | −0,04 | −0,15 | −0,17 |
| 2,2 | - | D1 | 165 | +0,000 | −0,288 | −0,409 | −0,38 | −0,29 | −0,20 |
| 2,2 | P70 | D0 | 554 | +0,002 | −0,084 | −0,101 | +0,00 | −0,12 | −0,15 |
| 2,2 | P70 | D1 | 146 | +0,045 | −0,212 | −0,298 | −0,21 | −0,25 | −0,17 |
| 2,2 | P80 | D0 | 475 | +0,032 | −0,063 | −0,088 | −0,02 | −0,08 | −0,14 |
| 2,2 | P80 | D1 | 132 | +0,061 | −0,205 | −0,110 | −0,19 | −0,26 | −0,15 |

## Lectura
- La mejor fila (k=1,5, P80, D0) da +0,004 R con spread (IC90 [−0,055; +0,064]), lejos del +0,10 exigido y negativa en 2024.
- D0 (entrar al cierre del impulso) tiene una pequeña ventaja bruta (+0,09 a +0,11 R con volumen alto), pero los 5 puntos de spread la consumen. Es la mejor de 18, así que parte de esa ventaja bruta puede ser azar de selección.
- D1 (retroceso al order block) es claramente peor que D0 y varias salen peor que su control de azar. La hipótesis H1 de order blocks no se sostiene.
- El filtro de volumen de ticks mejora D0 de forma consistente (sin filtro −0,07 → P80 +0,004 con k=1,5), pero sigue sin pasar.
- Con un spread menor (cuenta Raw/Zero) D0 P80 podría acercarse a rentable, pero es una hipótesis sin probar: habría que repetir con el spread real de esa cuenta y confirmar en datos que no se hayan usado.

Decisión: no programar el motor D en MQL5 con el spread actual.
