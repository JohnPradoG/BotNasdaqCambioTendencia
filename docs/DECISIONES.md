# Decisiones de John

Decisiones que concretan o modifican valores por defecto de `docs/SPEC.md`.
La especificación no se edita; las decisiones se registran aquí.

| Fecha | Decisión | Efecto en el diseño |
|---|---|---|
| 2026-10-09 | Operar con Exness en MetaTrader 5. | Confirma la plataforma y el broker del SPEC §2. |
| 2026-10-09 | El símbolo del Nasdaq en su cuenta es `ustec100` (escritura exacta a confirmar en Market Watch). | Valor por defecto de `InpSymbol`; la validación del símbolo sigue activa. |
| 2026-10-09 | Operar **24/5**, no solo la sesión de Nueva York. | `SessionMode=H24_5` por defecto, con bloqueos de rollover diario, reapertura del domingo y cierre del viernes. La sesión de NY (SPEC §11) se mantiene para la conversión horaria, el día de trading, las exclusiones y el modo alternativo `WINDOW`. Métricas por bloque horario. |
| 2026-10-09 | Tiene datos históricos en su PC desde 2021. | Partición IS 2021-01-01 → 2024-12-31, OOS 2025-01-01 → 2026-06-30 (pendiente de comprobar que son ticks reales completos). |
| 2026-10-09 | Quiere conectar el trabajo con MT5 en su PC. | Etapas D y E: compilación y Strategy Tester ejecutados en su equipo mediante una sesión remota en su PC. |
| 2026-10-09 | Verificado en el PC de John (cuenta demo Exness-MT5Trial11): el Nasdaq es `USTECm` (contrato 1, point 0,01); también existe `USTEC_x100m` (contrato 100). No aparece `ustec100`. | Pendiente de que John confirme qué símbolo usar. La validación por palabra clave `USTEC` acepta ambos. |
| 2026-10-09 | Hora del servidor de Exness: **UTC+0** (pausa diaria 20:59–22:00 servidor = 17:00–18:00 NY en EDT). Verificado solo con datos de horario de verano de EE. UU. | `ServerUTCOffsetHours=0`, `ServerDSTMode=NONE`. Reconfirmar con datos de invierno. |
| 2026-10-09 | Probar con **`USTEC_x100m`** (contrato 100), elegido por John. | Valor de `InpSymbol` en los presets. Si con el capital de la cuenta el lote mínimo supera el 0,25 % de riesgo, el EA no opera y registra `min_volume_exceeds_risk` (no se fuerza el riesgo). |
| 2026-10-09 | Hallazgo en el PC de John: en el probador, `USTEC_x100m` solo tiene historial de 2025 y 2026; `USTECm` lo tiene desde 2021. | La prueba técnica D0 usa `USTECm` en ene–mar 2024 (preset `NBRL_D0_smoke_USTECm.set`). **Pendiente para la Etapa E:** el IS 2021–2024 solo es posible con `USTECm`; John debe decidir si el backtest se hace en `USTECm` y la demo en `USTEC_x100m`. |
| 2026-10-09 | Backtests IS 2021–2024 con **`USTECm`**, elegido por John. | Presets `NBRL_E_*_USTECm.set` y `tools/mt5/ejecutar_etapa_e.bat`. La demo puede seguir en `USTEC_x100m`. |
| 2026-10-09 | El historial de USTECm en el PC empieza el 2021-10-27; los ticks reales en caché solo cubren 2026. | IS efectivo: **2021-11-01 → 2024-12-31**. Si Exness no da ticks reales de 2021–2024, el tester usa ticks generados: se revisará en los logs antes de concluir nada. |
| 2026-10-09 | John quiere probar entradas en **M5 y en M15**. | Etapa E corre las dos: M5 con contexto M15 y M15 con contexto H1 (presets `*_diag_m15.set`). Por defecto, los parámetros contados en velas (cooldown, edad de niveles, tiempo máximo, etc.) se dejan igual: en M15 cubren el triple de tiempo, en proporción a la escala. |
| 2026-10-09 | Limitación conocida de M15/H1: con contexto H1, la vela de las 09:00 NY entra en el rango overnight (ONH/ONL) aunque incluye 09:30–10:00, y `ZoneLookbackBars=96` cubre 4 días en vez de 1. | Se acepta para el diagnóstico y se tendrá en cuenta al comparar M5 y M15. |
| 2026-10-09 | Exness solo tiene ticks reales de USTECm desde 2026-01-01 ("real ticks begin from 2026.01.01, every tick generation used"). | Los backtests IS 2021–2024 usan ticks **generados** desde velas M1, con el spread de esas velas. Valen como diagnóstico; no son "ticks reales" como pedía el plan. Se indicará en cada informe. |
