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
