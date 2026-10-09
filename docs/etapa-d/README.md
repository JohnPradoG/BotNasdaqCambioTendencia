# Etapa D · Verificación técnica

> **Estado real (2026-10-09):** ejecutado en el PC de John: autotests 50 OK, 0 FAIL;
> prueba corta sin errores (ver `resultados-D0.md`). El commit
> c09cccc compila con 0 errores y 0 avisos. Lo lanzó John a mano: abrir MT5
> desde la sesión remota está bloqueado por los permisos de su PC. Sin backtests.

## Qué se añadió

- `MQL5/Include/NBRL/Logic.mqh`: reglas puras compartidas por el EA y los
  autotests (cálculo de SL/TP, presupuesto diario, mejora del SL, clave del día
  de trading, lista de señales vistas). El EA usa exactamente estas funciones,
  así que los autotests prueban el código real y no una copia.
- `NBRL_SelfTests.mq5` v1.10 cubre ahora todos los casos de
  `docs/etapa-a/05-plan-pruebas.md` §1.2:
  T-DST-1..4, T-SW-1..2, T-VOL-1..4, **T-SL-1..3, T-DAY-1..2, T-ID-1** (nuevos).
- `tools/mt5/ejecutar_etapa_d.bat`: copia, compila, ejecuta los autotests y
  una prueba corta en el Strategy Tester (USTECm, ene–mar 2024, solo análisis)
  y guarda todo en `results/<fecha>_D0_smoke/`. Ver `tools/mt5/README.md`.

## Hallazgos

- En el probador de Exness-MT5Trial11, `USTEC_x100m` solo tiene historial de
  2025–2026; `USTECm` lo tiene desde 2021. Ver `docs/DECISIONES.md`.

## Qué falta

- Pruebas de §1.3 (visual, spread alto, fin de semana, readopción).
