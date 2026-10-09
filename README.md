# BotNasdaqCambioTendencia · EA NASDAQ BREAKOUT & REVERSAL LAB

Expert Advisor MQL5 para MetaTrader 5 / Exness que opera solo Nasdaq 100.
La especificación maestra está en [`docs/SPEC.md`](docs/SPEC.md) y manda sobre
cualquier otro documento.

## Estado

| Etapa | Contenido | Estado |
|---|---|---|
| A | Arquitectura, hipótesis y reglas | Documentada (`docs/etapa-a/`) |
| B | Motores A y B + riesgo común (MQL5) | Código escrito, sin compilar (`docs/etapa-b/README.md`) |
| C | Motor C (falsas rupturas) + auditoría | Pendiente |
| D | Compilación, casos límite, correcciones | Pendiente (requiere MT5) |
| E | Backtest y A/B con datos reales | Pendiente (requiere MT5) |
| F | Revisión y paso a demo | Pendiente |

No hay código compilado ni backtests todavía. Instrucciones para compilar en `docs/etapa-b/README.md`.

## Documentación de la Etapa A

1. [Documento técnico](docs/etapa-a/01-documento-tecnico.md): arquitectura, hipótesis, definiciones comunes, sesión NY, plan de archivos.
2. [Reglas por motor](docs/etapa-a/02-reglas-motores.md): entradas, invalidación, SL y salidas de A1, A2, B1, B2 y C.
3. [Parámetros](docs/etapa-a/03-parametros.md): entradas del EA y valores iniciales.
4. [Riesgos y limitaciones](docs/etapa-a/04-riesgos-limitaciones.md): política de riesgo diario, lotaje, ejecución, datos.
5. [Plan de pruebas](docs/etapa-a/05-plan-pruebas.md): fases 1–6 y criterios de aprobación fijados de antemano.
6. [Registro de experimentos](docs/experimentos.md).
7. [Decisiones de John](docs/DECISIONES.md): 24/5, símbolo ustec100, datos desde 2021.
