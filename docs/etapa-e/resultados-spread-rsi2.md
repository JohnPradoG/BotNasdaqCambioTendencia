# Dos pistas tras el impulso + order block (2026-10-15)

Cifras leídas por la sesión remota en el PC de John (Python, sin MT5); no recalculadas aquí.

## 1. Impulso + OB con menos spread (IS 2021-2024, mismas 18 combinaciones)
Ninguna fila pasa el criterio (n ≥ 60, R ≥ +0,10, IC90 inferior > −0,05, positiva 2022/23/24, mejor que el azar) a ningún spread, ni con 1 punto.
Mejor fila siempre: k=1,5, P80, D0 (1.145 operaciones).

| Spread | R con spread | 2022 / 2023 / 2024 |
|---|---|---|
| 1 pto | +0,083 (IC90 inferior +0,023) | +0,07 / +0,09 / +0,06 |
| 2 ptos | +0,059 (inferior −0,001) | +0,04 / +0,08 / +0,02 |
| 3 ptos | +0,048 (inferior −0,012) | +0,04 / +0,06 / +0,01 |
| 5 ptos | +0,004 | +0,02 / +0,02 / −0,04 |

Con 1 punto cumple todo salvo el mínimo de +0,10 R. Las cuentas Raw/Zero cobran además comisión por lote (importe para USTEC sin consultar), que se suma al spread y aleja aún más del +0,10. Todas las D1 son negativas a cualquier spread. Es la mejor de 18 combinaciones: ventaja bruta con riesgo de selección.

## 2. RSI-2 diario, solo compras (SMA200, RSI2 < 10, salida cierre > SMA5, stop 2 ATR)
39 operaciones, datos 2021-10-27 → 2026-10-07 (SMA200 disponible desde 2022-08-04), spread mediano del día pagado.

| Año | Ops | Puntos | Suma R | R medio | Spread medio |
|---|---|---|---|---|---|
| 2023 | 10 | +631 | +1,33 | +0,13 | 4,62 |
| 2024 | 12 | +1.149 | +1,33 | +0,11 | 4,95 |
| 2025 | 10 | +1.052 | +1,54 | +0,15 | 1,88 |
| 2026 | 7 | +2.678 | +2,69 | +0,38 | 2,31 |

- 2023-2024: 22 ops, 63,6 % acierto, +0,121 R, t = 1,23 (no significativo). 2025-2026: 17 ops, 88,2 %, +0,249 R, t = 1,82. Total: +0,177 R, t = 2,18.
- Medido en R es mucho más modesto que el PF 3,09 en puntos citado antes: el stop está a 2 ATR, la ganancia típica es ~0,4 R y un stop cuesta −1 R. Cuatro stops (−1 R cada uno) en 39 operaciones.
- **Sesgo de selección:** salió de decenas de combinaciones (ORB, noise area, RSI-2 en D1/H1, rangos, tendencias, en USTECm, oro y S&P) más las 10 variantes de MT5 y 4 ideas en Python; RSI-2 D1 se eligió por ser la que mejor salía mirando todo el periodo incluido 2025-2026. Los parámetros SMA200/RSI2<10/SMA5 son los estándar de Connors; el stop de 2 ATR se eligió tras ver el peor trade de la versión sin stop en 2025-2026. Por tanto 2025-2026 no es un periodo fuera de muestra limpio para esta estrategia.
- La única validación limpia posible: datos nuevos (demo hacia adelante) u otro mercado no mirado.

## Conclusión
No hay estrategia validada. Lo más cercano es el RSI-2 diario, con evidencia débil (t = 2,18 total, 39 operaciones, contaminado por selección). El impulso con volumen alto tiene ventaja bruta pequeña que solo se acerca a rentable con spread ≤ 1 punto más comisión desconocida.

## 3. Estrategias de más operaciones (divergencias y otras), 2021-11 → 2024-12
Probadas por la sesión remota en el PC de John, Python sobre M1 de USTECm, spread real por minuto, con control de azar. Las reglas las fijó esa sesión antes de ver resultados; no hay registro escrito previo en el repositorio, así que la garantía de "sin ajuste" descansa en su palabra. Cifras no recalculadas aquí.

| Idea | Ops | Resultado | Lectura |
|---|---|---|---|
| Divergencia RSI H1 | 302 (~95/año) | −0,044 R, IC90 [−0,153; +0,065], 40 % acierto; 2022 −0,01, 2023 +0,05, 2024 −0,19; azar −0,015 | No aporta sobre el azar |
| Divergencia RSI M15 | 841 (~265/año) | −0,112 R, IC90 [−0,174; −0,050]; pierde 3 años; azar −0,089 | Peor que el azar |
| Momentum intradía (Gao y otros 2018) | 619 | −6,1 puntos/op, IC90 negativo, pierde 3 años | No funciona con este coste |
| Compras nocturnas 15:55 → 09:35 NY | 627 | +3,1 puntos/op, IC90 [−4,9; +11,2]; 2022 −12,3, 2023 +7,1, 2024 +13,4 | No significativo; swap de 627 noches sin calcular |

Ya van más de 60 combinaciones probadas en total (contando scalping_research, las 10 variantes de MT5 y las ideas de Python), así que cualquier hallazgo nuevo tiene alto riesgo de ser azar.

Siguientes pasos con base: aplicar el RSI-2 diario a más mercados no mirados (S&P 500, Dow, DAX, oro) para sumar operaciones, o repetir el impulso en una cuenta de menor coste.
