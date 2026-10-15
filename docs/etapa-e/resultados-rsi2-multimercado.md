# RSI-2 diario en 9 índices no mirados (2026-10-15)

Probado por la sesión remota en el PC de John, en Python, con velas diarias de Yahoo Finance (índices al contado, 2000 a 2026; EuroStoxx desde 2007). Cifras no recalculadas aquí. Reglas idénticas a las del Nasdaq, sin tocar nada: compra al cierre si cierre > SMA200 y RSI(2) < 10; salida al cerrar sobre la SMA5; stop a 2 ATR (si el mercado abre bajo el stop, se sale a la apertura); solo compras. Coste fijado antes de mirar: 0,02 % del precio por operación. Se probaron 9 de 9 mercados, ninguno escondido.

| Mercado | Ops | R medio | IC90 | Acierto | Peor op |
|---|---|---|---|---|---|
| Dow | 225 | +0,177 | [+0,100; +0,253] | 73,3 % | −1,28 R |
| Russell 2000 | 199 | +0,112 | [+0,034; +0,189] | 69,8 % | −1,00 R |
| FTSE 100 | 182 | +0,102 | [+0,022; +0,181] | 70,9 % | −1,00 R |
| EuroStoxx 50 | 127 | +0,100 | [−0,005; +0,205] | 67,7 % | −1,05 R |
| Nikkei | 182 | +0,092 | [−0,016; +0,200] | 64,8 % | −1,61 R |
| Hang Seng | 190 | +0,081 | [−0,015; +0,178] | 65,3 % | −2,63 R |
| ASX 200 | 204 | +0,060 | [−0,023; +0,143] | 64,7 % | −1,13 R |
| CAC 40 | 183 | +0,058 | [−0,040; +0,157] | 67,2 % | −2,81 R |
| DAX | 198 | +0,030 | [−0,063; +0,123] | 63,6 % | −2,46 R |
| **Todos** | **1.690** | **+0,091** | **[+0,061; +0,121]** | **67,6 %** | **−2,81 R** |

Solo 2021-2026 (comparable con el Nasdaq): 446 ops, +0,093 R, IC90 [+0,033; +0,153]. Ganan Nikkei, Dow, EuroStoxx, DAX, Russell, ASX, CAC; pierden FTSE (−0,106) y Hang Seng (−0,061). FTSE fue negativo en 2022, 2023, 2024 y 2026; Dow solo tuvo 3 años negativos (2018 a 2020).

## Lectura
- Es la primera confirmación en mercados no mirados: los 9 tienen media positiva en el periodo completo y el conjunto queda claramente sobre 0. La ventaja del RSI-2 diario no parece casualidad del Nasdaq.
- Es pequeña: ~+0,09 R por operación. Con 0,25 % de riesgo por operación son ~+0,02 % de la cuenta por operación; con 9 mercados saldrían ~65 operaciones al año.
- Los mercados no son independientes entre sí (índices muy correlacionados), así que 9 mercados valen menos que 9 pruebas separadas. La regla es un patrón conocido (Connors), no un hallazgo nuevo.
- Limitaciones: índices al contado, no los CFD de Exness; sin swap nocturno (2 a 5 noches por operación); el 0,02 % puede quedarse corto; huecos de apertura llevan la peor operación a −2,5 / −2,8 R.
- El stop de 2 ATR se eligió tras mirar 2025-2026 del Nasdaq; aquí se usa sin cambios, lo que lo hace una prueba independiente de esa elección.

## Siguiente paso
Ver qué símbolos de esos índices ofrece Exness, su swap real y recalcular con esos costes; luego demo hacia adelante.

## Con datos y costes reales de Exness (2021-10 → 2026-10, mismas reglas, solo compras)
Calculado por la sesión remota en el PC de John a partir de los M1 exportados de la demo (`exportar_m1.bat`, `simbolos.tsv`). Cifras no recalculadas aquí. Spread: mediana de la columna spread de los M1 de los últimos 30 minutos antes del cierre del día NY. Swap largo por noche en posición (triple los miércoles), **supuesto: swap en puntos, coste = swap × point**; no se exportó el modo de swap, así que si Exness lo cobra de otra forma el resultado cambia.

| Símbolo | Ops | R sin swap | R con swap (IC90) | Acierto | Yahoo mismo periodo |
|---|---|---|---|---|---|
| US500m* | 45 | +0,328 | +0,280 [+0,141; +0,420] | 84 % | +0,326 |
| US30m | 49 | +0,188 | +0,140 [+0,002; +0,277] | 73 % | +0,185 |
| JP225m | 39 | +0,142 | +0,142 [+0,005; +0,279] | 67 % | +0,343 |
| USTECm* | 39 | +0,177 | +0,127 [−0,011; +0,264] | 69 % | +0,284 |
| STOXX50m | 40 | +0,068 | +0,040 [−0,106; +0,186] | 70 % | +0,072 |
| HK50m | 32 | +0,011 | +0,011 [−0,145; +0,166] | 62 % | −0,079 |
| DE30m | 43 | +0,041 | +0,006 [−0,156; +0,167] | 63 % | +0,114 |
| FR40m | 37 | −0,010 | −0,036 [−0,204; +0,132] | 62 % | +0,083 |
| AUS200m | 37 | −0,073 | −0,107 [−0,288; +0,075] | 59 % | +0,035 |
| UK100m | 37 | −0,119 | −0,165 [−0,329; −0,001] | 51 % | −0,134 |
| **Total 10** | **398** | **+0,085** | **+0,052 [+0,003; +0,101]** | | |

(*) S&P y Nasdaq ya se habían mirado antes: sesgados. Sin ellos, los 8 mercados nuevos dan ≈ +0,01 R por operación con swap (314 operaciones): prácticamente cero. Solo Dow (+0,140) y Nikkei (+0,142, swap 0) quedan con IC90 apenas sobre 0. El swap resta 0,03 a 0,05 R por operación (≈ 4 noches de media). No hay Russell 2000 en Exness; IN50m solo tiene 57 días y el oro no salió en la exportación (su ruta no contenía "Metals").

Lectura: la ventaja del RSI-2 diario existe a largo plazo (25 años en Yahoo) pero con los costes de Exness Standard queda muy justa; son solo 5 años y 32 a 49 operaciones por mercado. Sin base para dinero real; sí para una prueba en demo hacia adelante con S&P, Dow, Nikkei y Nasdaq y riesgo pequeño.

## Siete reglas diarias clásicas, 10 índices Exness con spread y swap reales (2021-11 → 2024-12)
Preregistradas por la sesión remota antes de mirar (sin optimizar parámetros). Criterio fijado antes: conjunto de los 10 índices con IC90 inferior > 0, t > 2,2 (corrección por probar 7) y al menos 6 de 10 positivos; solo las que pasaran se mirarían una vez en 2025-2026. Unidad: ganancia ÷ ATR diario con costes. Cifras no recalculadas aquí; el registro previo no está en el repositorio.

| Estrategia | Ops | Media | IC90 inferior | t | Índices + |
|---|---|---|---|---|---|
| RSI-2 solo compras | 220 | +0,145 | +0,016 | 1,85 | 8/10 |
| 3 días bajistas, compra sobre SMA200 | 243 | +0,091 | +0,005 | 1,74 | 9/10 |
| RSI-2 compras + ventas | 292 | +0,068 | −0,049 | 0,96 | 7/10 |
| IBS | 601 | −0,055 | −0,128 | −1,22 | 3/10 |
| Doble 7 | 279 | −0,099 | −0,261 | −1,00 | 3/10 |
| Cambio de mes | 290 | −0,118 | −0,266 | −1,31 | 3/10 |
| Donchian 20/10 | 218 | −0,604 | −0,848 | −4,08 | 1/10 |

Ninguna pasa el listón completo; 2025-2026 no se miró. Solo las dos de comprar retrocesos cortos en tendencia alcista (RSI-2 y 3 días bajistas) son positivas y consistentes, sin llegar a la significación exigida. Más de 70 ideas probadas en total: seguir buscando sobre los mismos datos aumenta el riesgo de un falso hallazgo. Camino: prueba hacia adelante en demo del EA `NBRL_RSI2_Daily` (2-3 meses, riesgo 0,25 %), sin dinero real hasta ver el resultado; la otra palanca es una cuenta con menos spread y swap.
