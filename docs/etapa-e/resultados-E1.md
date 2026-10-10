# Etapa E · Resultados E1-diag (2026-10-09)

Ejecutado por John con `tools/mt5/ejecutar_etapa_e.bat` (10 pruebas, 20:18–21:45
hora del PC). Los archivos siguen en el PC (`results\2026-10-09_2018_E_IS_diag`);
las cifras están copiadas de ellos, sin cambios. Sin errores en los logs.

## Condiciones

- USTECm, 2021-11-01 → 2024-12-31, depósito 10 000 USD, riesgo 0,25 % por operación.
- Ticks **generados desde velas de 1 minuto**: Exness solo tiene ticks reales de
  USTECm desde 2026-01-01. Menos preciso que ticks reales.
- Modo diagnóstico: `F_MaxSpreadATRFrac` 0,50 y `F_SpreadRFrac` 0,30. El spread
  (≈5 puntos) se cobra completo en cada operación.
- Entradas M5 con contexto M15, y entradas M15 con contexto H1.

## Resultados

| Prueba | Ops | Aciertos | Exp. R | IC 90 % | PF | Neto USD | DD máx | Kill switch (6 %) |
|---|---|---|---|---|---|---|---|---|
| M5 A1 | 123 | 33,3 % | -0,181 | [-0,350; -0,007] | 0,74 | -540,76 | 6,00 % | 2022-03-07 |
| M5 A2 | 71 | 26,8 % | -0,351 | [-0,553; -0,137] | 0,52 | -600,10 | 6,00 % | 2022-10-25 |
| M5 B1 | 215 | 36,7 % | -0,094 | [-0,235; 0,047] | 0,85 | -503,28 | 6,00 % | 2022-04-26 |
| M5 B2 | 60 | 25,0 % | -0,414 | [-0,649; -0,173] | 0,47 | -600,46 | 6,00 % | 2022-03-04 |
| M5 C1 | 198 | 37,4 % | -0,079 | [-0,226; 0,073] | 0,88 | -387,20 | 6,01 % | 2022-02-16 |
| M15 A1 | 104 | 30,8 % | -0,257 | [-0,445; -0,054] | 0,65 | -642,71 | 6,57 % | 2022-07-29 |
| **M15 A2** | 51 | 49,0 % | **+0,224** | [-0,072; 0,520] | 1,43 | +283,35 | 1,66 % | nunca |
| M15 B1 | 158 | 35,4 % | -0,138 | [-0,296; 0,020] | 0,79 | -524,81 | 6,00 % | 2022-06-29 |
| M15 B2 | 57 | 22,8 % | -0,421 | [-0,649; -0,187] | 0,46 | -576,62 | 6,00 % | 2022-05-24 |
| M15 C1 | 342 | 38,3 % | -0,049 | [-0,156; 0,059] | 0,92 | -415,00 | 6,00 % | 2022-09-02 |

Saldo final / `OnTester` / duración: M5 A1 9459,24 / -2,0098 / 22:03 ·
M5 A2 9399,90 / -2,9559 / 19:34 · M5 B1 9496,72 / -1,3774 / 10:10 ·
M5 B2 9399,54 / -3,2066 / 10:19 · M5 C1 9612,80 / -1,1094 / 6:59 ·
M15 A1 9357,29 / -2,6197 / 2:57 · M15 A2 10283,35 / +1,6032 / 2:50 ·
M15 B1 9475,19 / -1,7323 / 3:21 · M15 B2 9423,38 / -3,1778 / 3:33 ·
M15 C1 9585,00 / -0,9135 / 2:32.

## Lectura

1. **Nueve de las diez pruebas pararon por el kill switch** (DD total 6 %,
   `MaxTotalDDPct`) entre febrero y octubre de 2022. Después de esa fecha solo
   registran rechazos `kill_switch`. Esas cifras cubren pocos meses (por
   ejemplo, M5 A1: 4 meses de 38), no el periodo completo.
2. **Solo M15 A2 recorrió todo el periodo**: +0,224 R por operación, PF 1,43,
   DD 1,66 %. Son 51 operaciones y el intervalo de confianza incluye el 0.
   **No aprueba** los criterios de `docs/etapa-a/05-plan-pruebas.md` §4 (mínimo 60
   operaciones, límite inferior del IC > -0,05, y esto es IS, no OOS).
3. Se miraron 10 combinaciones y se destaca la mejor: parte del resultado puede ser
   azar de selección. Hay que confirmarlo en datos nuevos antes de creerlo.
4. M15 mejora a M5 en A2, B1 y C1. B1 y C1 quedan cerca del equilibrio
   (-0,05 a -0,14 R) pagando el spread completo. B2 es el peor en ambos marcos.
5. Con el spread de esta cuenta (≈5 puntos), M5 pierde en las cinco variantes.

## Siguiente paso propuesto (E2)

Repetir las 10 pruebas **sin el kill switch** (`MaxTotalDDPct=100`, solo en el
probador) para que cada variante recorra el periodo completo y tenga más
operaciones. Se registra como experimento antes de ejecutarlo. No se toca 2025.

## Verificación con el informe del Strategy Tester (M15 A2)

John subió `NBRL_E_M15_A2.htm`. Coincide con las cifras de la tabla.

- Calidad del historial: **0 % ticks reales** (51 221 910 ticks generados, 71 981 barras).
- 51 operaciones: 25 ganadoras (49,02 %) y 26 perdedoras. Ventas 30 (43,33 % ganadas), compras 21 (57,14 %).
- Ganancia media 37,89 USD y pérdida media -25,53 USD (≈ 1,5 R y 1 R con riesgo de 25 USD).
- Neto +283,35 USD, PF 1,43, pago esperado 5,56 USD por operación, DD de saldo 1,60 %, DD de equidad 1,80 %.
- Máximo de 4 ganadas seguidas y 5 perdidas seguidas. Duración media de posición 6 h 15 min.
- Con objetivo de 1,5 R, el acierto de equilibrio es 40 %; con 51 operaciones el
  margen de error del 49 % es de unos ±14 puntos, por eso el resultado sigue sin estar probado.

### Desglose de M15 A2 (de `trades.csv`, 1 R = 0,25 % de la cuenta)

- Por año: 2022 21 ops +6,45 R · 2023 17 ops +5,53 R · 2024 13 ops -0,53 R (se apaga).
- Por sesión: Asia 26 ops +6,49 R · Europa 22 ops +5,45 R · Nueva York 2 ops -2,00 R.
- Por dirección: compras 21 ops +9,03 R · ventas 30 ops +2,42 R (el Nasdaq subió mucho en 2023-2024).
- Las 51 cerraron por TP (25) o por SL (26). Sharpe 21,47 del informe: no fiable con tan pocas operaciones.

## E2 · intento 1 (2026-10-09 22:48): solo terminó la primera prueba

La ventana del `.bat` se cerró entre las 22:49 y las 22:58 y las pruebas siguientes
no se lanzaron. Sin errores en los logs ni eventos de suspensión. Resultado de la
primera (M5 A1, sin kill switch, nov-2021 a dic-2024, leído en MT5; el informe no
se copió a `results`):

- 1052 operaciones, 33,9 % de aciertos, -0,174 R por operación, IC 90 % [-0,237; -0,112].
- PF 0,74, neto -3693 USD, DD máximo 37,6 %, saldo final 6306,69 USD, 8 min 59 s.
- M5 A1 pierde de forma clara, no por mala suerte: el IC queda entero por debajo de cero.
- Las otras 9 pruebas de E2 se repiten. No cerrar la ventana negra hasta que ponga "Listo".
