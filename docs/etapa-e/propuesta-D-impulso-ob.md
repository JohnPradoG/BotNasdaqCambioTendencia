# Propuesta: motor D "Impulso + Order Block" (borrador, sin código aún)

Idea de John (2026-10-15): entrar en los picos fuertes (rupturas y caídas muy fuertes), probando volumen y order blocks.

## Hipótesis (fijadas antes de probar)
- **H1 (continuación):** tras una vela de impulso (rango ≥ k·ATR y cierre en el 20 % extremo de su rango) con volumen de ticks alto, el precio vuelve a tocar el order block (última vela contraria antes del impulso) y continúa en la dirección del impulso con expectativa > 0 neta de costes.
- **H2 (filtro de volumen):** el subconjunto con volumen de ticks ≥ percentil 80 de las últimas 50 velas rinde mejor que el conjunto sin filtro. Si no mejora, el volumen se descarta.
- Nulo a batir: el mismo motor sin filtro de volumen y con entrada a mercado al cierre del impulso.

## Definiciones
- Impulso: vela cerrada M15 con rango ≥ 1,8·ATR(14) y cuerpo ≥ 60 % del rango, o secuencia de 2 velas con desplazamiento ≥ 2,5·ATR.
- Order block (OB): rango de la última vela contraria previa al impulso. Válido solo si el impulso rompe un máximo/mínimo de estructura reciente (confirma desplazamiento, no ruido).
- Volumen: `tick_volume` de MT5. En CFD de índices de Exness NO es volumen real, solo nº de cambios de precio; es una aproximación de actividad. Se declara así en todos los informes.
- Entrada: límite en el 50 % del OB (variante D1) o al cierre del impulso a mercado (variante D0, control). Cancelación si pasan 8 velas sin tocar o si el precio cierra más allá del OB opuesto.
- SL: más allá del extremo del OB + buffer ATR. TP: 1,5R como el resto. Mismo RiskManager (0,25 %/op, 1 % diario, sin martingala). Mismos bloqueos de sesión.

## Plan de prueba
1. Desarrollo solo con **2021-11-01 → 2024-12-31**. Sin tocar 2025-2026.
2. Cuadrícula pequeña y declarada de antemano: k ∈ {1,5; 1,8; 2,2} × volumen {sin filtro, P70, P80} × entrada {mercado, 50 % OB} = 18 corridas M15. M5 solo si M15 muestra algo.
3. Se informa el número de combinaciones probadas para corregir sesgo de selección. Criterio de paso a OOS: ≥60 operaciones IS, ≥+0,10 R, PF ≥ 1,15, IC90 inferior > −0,05 R, y que el resultado no dependa de un solo año ni de un solo lado (compras/ventas).
4. OOS 2025-01-01 → 2026-06-30: una sola ejecución con configuración congelada. Aviso: el periodo es conocido de A2/M15 y el mercado fue muy alcista; se verifica el desglose compras/ventas.

## Riesgos conocidos
- Los picos fuertes suelen tener spread alto y deslizamiento; el tester no los modela bien (ticks generados antes de 2026).
- Entrar tras el impulso es perseguir el precio: A2 ya rechazó muchas señales por `engine:chase`.
- Pocas operaciones por filtro estricto: puede no alcanzar 60 en IS.

## Siguiente paso
Implementar D0/D1 como motor nuevo (Engine_D.mqh) con autotests de detección de impulso/OB sobre datos sintéticos, compilar, y correr la cuadrícula IS cuando termine la E2 (no se pueden solapar corridas en el mismo MT5).
