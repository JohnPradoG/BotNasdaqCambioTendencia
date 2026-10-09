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
