<!--
Especificación maestra del proyecto, copiada literalmente del mensaje de John
en el proyecto "Bot Nasdaq Cambio de Tendencia" (2026-10-09).
No editar el contenido: cualquier cambio de requisitos se documenta aparte
(docs/etapa-a/ y siguientes) haciendo referencia a la sección afectada.
-->

# PROYECTO: EA NASDAQ BREAKOUT & REVERSAL LAB — MT5 / EXNESS

## 1. Rol y objetivo

Actúa como un desarrollador senior especializado en MQL5, trading algorítmico, microestructura de mercado, investigación cuantitativa y validación estadística de Expert Advisors.

Quiero desarrollar desde cero un Expert Advisor (EA) para MetaTrader 5, destinado a operar exclusivamente Nasdaq mediante mi cuenta de Exness.

El objetivo es investigar y desarrollar un sistema capaz de detectar:

1. Posibles giros bajistas antes de que el precio complete una caída importante.
2. Posibles giros alcistas antes de que el precio complete una subida importante.
3. Rupturas alcistas y bajistas después de consolidaciones.
4. Rupturas falsas que puedan convertirse en operaciones en la dirección contraria.

Quiero aprovechar movimientos de cierta amplitud y buscar varias oportunidades durante la sesión cuando existan señales válidas. No quiero un robot que opere constantemente por obligación ni uno que se quede inactivo por filtros excesivamente restrictivos.

IMPORTANTE: no prometas rentabilidad ni afirmes que una estrategia funciona sin pruebas verificables. Si la hipótesis inicial no demuestra resultados suficientes, analiza por qué falla, conserva los componentes útiles y desarrolla variantes alternativas que puedan probarse objetivamente.

No mezcles este proyecto con otros robots que ya existan en la cuenta. Es un EA independiente, con código, magic number, registros y estadísticas propios.

## 2. Reglas generales de desarrollo

* Lenguaje: MQL5 nativo.
* Plataforma: MetaTrader 5.
* Broker: Exness.
* Instrumento: símbolo Nasdaq disponible en el servidor concreto de Exness, que puede tener un nombre como USTEC_x100 u otro. No lo des por supuesto: detecta y valida el símbolo seleccionado.
* No dependas de indicadores comerciales de pago, DLL externas, APIs de pago ni servicios externos para tomar decisiones básicas.
* Usa las funciones oficiales de MQL5 para consultar precios, indicadores, posiciones, órdenes y especificaciones del símbolo.
* El EA debe funcionar tanto en el Strategy Tester como en una cuenta demo.
* Todos los parámetros importantes deben ser configurables desde las entradas del EA.
* Debe compilar sin errores y, preferiblemente, sin advertencias.
* No utilices datos futuros, repainting ni información que no estuviera disponible en el momento de la señal.
* No abras operaciones duplicadas por procesar repetidamente el mismo tick o la misma señal.
* Antes de enviar una orden, valida el volumen, los niveles mínimos de stop, el spread, el margen disponible y las reglas de ejecución del símbolo.
* No inventes resultados históricos ni afirmes haber ejecutado un backtest si no tienes acceso real a MT5 y sus datos.

## 3. Arquitectura modular

Desarrolla el EA mediante módulos claramente separados:

A. MarketStructureDetector
B. ReversalAnticipationEngine
C. ConsolidationBreakoutEngine
D. FalseBreakoutEngine
E. SignalQualityFilter
F. SessionManager
G. RiskManager
H. PositionManager
I. TradeLogger
J. PerformanceAnalyzer
K. SafetyController

Cada módulo debe tener una responsabilidad definida. Mantén el código organizado, documentado y fácil de modificar.

Los motores de estrategia deben generar señales independientes. El gestor de riesgo será compartido por todos.

## 4. MOTOR A: ANTICIPACIÓN DE GIROS

Diseña una estrategia experimental para detectar un posible cambio de dirección antes de una ruptura importante.

Debe investigar y combinar, mediante reglas explícitas:

* Agotamiento de un movimiento prolongado.
* Pérdida de aceleración del precio.
* Rechazo de máximos o mínimos mediante mechas.
* Fallos sucesivos al superar una zona.
* Divergencias de RSI como confirmación opcional.
* Cambios en la estructura de máximos y mínimos.
* Ruptura de una microestructura local que confirme el posible cambio de control.
* ATR y volatilidad para distinguir un movimiento significativo de ruido normal.

Para una posible venta después de una subida, identifica agotamiento o rechazo en una zona relevante y busca evidencia de que los vendedores comienzan a dominar.

Para una posible compra después de una caída, aplica la lógica inversa.

No abras una operación únicamente porque el RSI esté sobrecomprado o sobrevendido, porque aparezca una mecha o porque una vela cambie de color.

Desarrolla al menos dos variantes:

A1. Anticipación agresiva, con entrada temprana y mayor exposición a falsas señales.

A2. Anticipación con confirmación estructural, que exige un cambio local de estructura antes de entrar.

Documenta las condiciones exactas de entrada, invalidación, stop loss y salida. Las reglas deben ser reproducibles y no depender de apreciaciones visuales subjetivas.

## 5. MOTOR B: RUPTURAS DE CONSOLIDACIÓN

Diseña un motor para identificar consolidaciones y operar las rupturas alcistas o bajistas.

Debe:

1. Detectar rangos mediante máximos, mínimos, duración, ATR y compresión de volatilidad.
2. Calcular el techo y el suelo del rango.
3. Descartar rangos demasiado amplios, demasiado estrechos o de calidad insuficiente.
4. Detectar una salida del rango con impulso y distancia suficiente respecto al nivel.
5. Evaluar el cierre de la vela, la expansión de volatilidad y el volumen tick disponible.
6. Evitar entrar si el precio ya recorrió una parte excesiva del movimiento esperado.
7. Invalidar señales cuando el precio regrese al rango según reglas configurables.
8. Permitir compras por ruptura alcista y ventas por ruptura bajista.

Desarrolla dos variantes independientes:

B1. Entrada directa tras confirmación de ruptura.

B2. Entrada después del retesteo del nivel roto.

No exijas siempre un retesteo, porque algunos movimientos no regresan al nivel. Tampoco compres automáticamente cada ruptura.

## 6. MOTOR C: FALSAS RUPTURAS

Desarrolla un módulo independiente que detecte cuando el precio atraviesa un máximo, mínimo, soporte o resistencia, pero vuelve a situarse dentro del rango.

Distingue entre:

* Ruptura verdadera.
* Ruptura falsa con regreso al rango.
* Barrido de un extremo sin confirmación suficiente.
* Ruptura que se extiende y posteriormente revierte.

Una posible operación contraria solo puede abrirse si cumple reglas explícitas de confirmación y gestión de riesgo.

Evita atribuir intención institucional al movimiento del precio sin datos que la demuestren.

Este módulo debe poder activarse o desactivarse y evaluarse por separado.

## 7. TEMPORALIDADES Y FRECUENCIA

Utiliza inicialmente:

* M15 para analizar estructura y contexto.
* M5 para entradas.
* M1 como alternativa de mayor frecuencia.

M15 + M5 será la configuración inicial de referencia. Compara posteriormente M15 + M1.

No permitas que una señal utilice una vela superior todavía abierta como si su cierre ya estuviera confirmado.

Evalúa si la detección de agotamiento y las rupturas funcionan mejor con reglas de velas cerradas o con seguimiento intrabar. Si utilizas señales intrabar, documenta sus riesgos y evita modificar retroactivamente una señal registrada.

El EA debe permitir varias operaciones durante una sesión, pero establecer límites configurables de operaciones por día, operaciones por señal y operaciones consecutivas con pérdidas.

No existe una obligación de operar todos los días.

## 8. FILTROS DE CALIDAD

Investiga y prueba individualmente los siguientes filtros:

* Spread máximo, en puntos y relativo al ATR.
* Volatilidad mínima y máxima.
* Horario operativo configurable.
* Impulso de la ruptura.
* Calidad y duración de la consolidación.
* Distancia al soporte o resistencia más próximo.
* Relación entre recorrido esperado y stop loss.
* Rechazo mediante mechas.
* Divergencia de RSI.
* Noticias económicas de alto impacto, cuando exista una fuente de calendario disponible y fiable.

No añadas todos los filtros automáticamente. Evalúa si cada uno mejora los resultados fuera de muestra. Los filtros deben ser opcionales para permitir pruebas A/B.

Si no se dispone de un calendario económico fiable, no simules que el EA conoce las noticias. En ese caso, proporciona ventanas horarias de exclusión configurables y documenta la limitación.

## 9. GESTIÓN DEL RIESGO

Implementa un gestor de riesgo estricto.

Parámetros iniciales:

* Riesgo por operación: 0,25% del equity.
* Pérdida diaria máxima inicial del EA: 1% del equity de referencia del día.
* Operaciones simultáneas: una por símbolo y magic number.
* Número máximo diario de operaciones: configurable.
* Máximo de pérdidas consecutivas: configurable.
* Stop loss obligatorio en todas las operaciones.
* Sin martingala.
* Sin grid.
* Sin promediar posiciones perdedoras.
* Sin incrementar lotaje para recuperar pérdidas.
* Sin aumentar el stop loss para evitar cerrar una operación perdedora.
* Sin aumentar automáticamente el riesgo después de una ganancia.

El riesgo por operación se calculará mediante la distancia real entre el precio de entrada y el stop, utilizando las especificaciones del símbolo y las funciones de cálculo de beneficios y pérdidas de MQL5.

Calcula el volumen considerando tick size, tick value, tamaño de contrato, divisa de la cuenta, volumen mínimo, volumen máximo y step de volumen.

Redondea siempre el volumen hacia abajo al step válido. Si el volumen mínimo permitido supera el riesgo autorizado, no operes.

El stop se situará en una zona de invalidación estructural, con ATR como referencia complementaria. No fuerces un stop arbitrariamente pequeño para aumentar el lotaje.

La pérdida diaria debe calcularse sobre una referencia definida al comienzo del día de trading y contabilizar las pérdidas realizadas y el riesgo abierto conforme a una política explícita. Incluye comisiones y swaps cuando corresponda.

Al alcanzar el límite diario:

* Bloquea nuevas entradas.
* Registra el motivo.
* Gestiona las posiciones abiertas según una política de seguridad configurable.
* No abras nuevas operaciones hasta el siguiente período autorizado.

Incluye un límite de drawdown total configurable y un interruptor de emergencia.

El EA no debe cerrar operaciones de otros robots ni posiciones manuales que no le pertenezcan.

IMPORTANTE: los límites de pérdida no garantizan una pérdida máxima exacta en condiciones de gaps, deslizamiento o fallos de ejecución.

## 10. GESTIÓN DE SALIDAS

Implementa alternativas configurables:

* Objetivo por múltiplos de riesgo, por ejemplo 1R, 1,5R y 2R.
* Trailing stop basado en ATR.
* Trailing por estructura de máximos y mínimos.
* Cierre parcial opcional.
* Salida por invalidación de la señal.
* Salida por fin de sesión, si se configura.
* Tiempo máximo de permanencia opcional.

Evalúa cada salida de forma independiente. No combines todos los mecanismos en la primera versión sin poder medir su contribución.

El stop loss nunca debe alejarse de la posición para aumentar la pérdida potencial. Si se implementa break-even, solo debe activarse cuando se cumplan las condiciones configuradas.

## 11. SESIÓN DE NUEVA YORK

Crea un módulo horario configurable que utilice la hora de Nueva York, con tratamiento correcto de los cambios de horario de verano.

Permite configurar:

* Inicio de la ventana operativa.
* Fin de la ventana operativa.
* Ventana de exclusión antes o después de eventos programados.
* Hora límite para nuevas entradas.
* Política de cierre al finalizar la sesión.

No supongas que la hora del servidor de Exness siempre coincide con la hora de Nueva York.

Registra la hora del servidor y la hora operativa utilizada para tomar la decisión.

## 12. AUDITORÍA DE OPERACIONES

Cada señal, entrada, modificación y salida debe quedar registrada en CSV, o en un formato estructurado equivalente, con al menos:

* Fecha y hora.
* Símbolo.
* Magic number.
* Motor de estrategia y variante.
* Dirección de la operación.
* Temporalidades utilizadas.
* Tipo de señal.
* Precio de entrada.
* Stop loss inicial.
* Objetivo inicial.
* Volumen.
* Riesgo monetario previsto.
* Spread.
* ATR.
* Identificador del rango o estructura analizada.
* Motivos de entrada.
* Motivos de salida.
* Precio de salida.
* Comisión y swap, cuando existan.
* Beneficio o pérdida netos.
* Resultado expresado en R.
* Máxima excursión favorable (MFE).
* Máxima excursión adversa (MAE).
* Deslizamiento observado, cuando pueda medirse.
* Errores de ejecución.
* Motivo de cualquier señal rechazada.

Registra también las señales que no generan operaciones y el filtro que las descartó.

No registres únicamente operaciones ganadoras o perdedoras. Necesitamos conocer las oportunidades que el bot detectó, las que rechazó y las razones.

Los registros deben incluir una identificación única de cada señal para evitar duplicados.

## 13. MÉTRICAS DE EVALUACIÓN

Genera un informe independiente para cada motor y variante.

Incluye:

* Número total de operaciones.
* Porcentaje de operaciones ganadoras.
* Beneficio bruto.
* Pérdida bruta.
* Beneficio neto después de costes.
* Profit factor.
* Expectativa por operación.
* Expectativa en múltiplos de R.
* Drawdown máximo monetario y porcentual.
* Duración media de las operaciones.
* Ganancia media y pérdida media.
* Mayor racha de pérdidas.
* Resultados por día de la semana.
* Resultados por franja horaria.
* Resultados en tendencias, consolidaciones y alta volatilidad.
* Resultados de compras frente a ventas.
* MFE y MAE.
* Costes de spread, comisiones y deslizamiento.
* Comparación entre resultados históricos y forward.

No utilices el porcentaje de acierto como única medida de calidad.

El informe debe mostrar claramente si una estrategia gana por unas pocas operaciones extraordinarias mientras acumula muchas pérdidas pequeñas.

## 14. PLAN DE BACKTEST Y VALIDACIÓN

Diseña un protocolo de evaluación reproducible.

FASE 1 — Verificación técnica:

* Compilar el EA.
* Revisar errores y advertencias.
* Verificar el cálculo del volumen.
* Probar stops, objetivos y cierres.
* Verificar que no existen órdenes duplicadas.
* Simular spread elevado, rechazo de órdenes y desconexiones cuando sea posible.

FASE 2 — Backtest inicial:

* Utilizar la mayor cantidad de datos históricos fiables que esté disponible; objetivo inicial de 2–3 años o más si los datos son adecuados.
* Utilizar ticks reales en MT5 cuando estén disponibles.
* Incluir costes y condiciones de ejecución realistas.
* Analizar por separado cada motor y variante.
* Guardar los informes y parámetros utilizados.

FASE 3 — Optimización controlada:

* Optimizar pocos parámetros a la vez.
* Evitar buscar una combinación que solo funcione en un período.
* Preferir regiones de parámetros estables a un único valor excepcional.
* Registrar todos los experimentos, incluidos los fallidos.

FASE 4 — Validación fuera de muestra:

* Reservar un período que no se utilice para optimizar.
* Utilizar Forward Testing de MT5.
* Comparar estabilidad, expectativa neta y drawdown.
* No volver a utilizar repetidamente el período de prueba como si continuara siendo completamente independiente.

FASE 5 — Robustez:

* Probar variaciones razonables de spread y deslizamiento.
* Cambiar moderadamente los parámetros.
* Comparar distintos regímenes de mercado.
* Evaluar si el resultado depende excesivamente de un mes, un día o unas pocas operaciones.

FASE 6 — Demo:

* Ejecutar el EA en una cuenta demo de Exness durante varias semanas y hasta obtener una muestra de operaciones razonable.
* Comparar las señales reales con las del backtest.
* Revisar ejecución, spread, lotaje, stops y registros.
* No pasar a real automáticamente por cumplir una fecha o un número fijo de días.

Define criterios cuantitativos de aprobación antes de ejecutar las pruebas. Como referencia inicial, exigir una expectativa neta positiva fuera de muestra, drawdown dentro de los límites, suficientes operaciones y ausencia de fallos críticos. Ajusta los umbrales según la cantidad y calidad de los datos, sin declarar aprobado un sistema solo por presentar un beneficio positivo.

## 15. SI LA ESTRATEGIA NO FUNCIONA

Si el backtest no muestra una expectativa neta positiva o el resultado desaparece al introducir costes:

1. Identifica el motor que pierde y las condiciones en las que falla.
2. Determina si el problema es entrada, salida, spread, horario, falsas rupturas o exceso de operaciones.
3. Conserva las estadísticas originales.
4. Formula una hipótesis concreta de mejora.
5. Modifica una sola familia de parámetros por experimento.
6. Ejecuta nuevamente las pruebas históricas y fuera de muestra.
7. Compara la versión nueva con la anterior.

También puedes investigar variantes de continuación de tendencia, retroceso después de ruptura, contracción-expansión de volatilidad y reversión tras barrido de extremos, pero deben tratarse como hipótesis alternativas, no como soluciones garantizadas.

No añadas indicadores indiscriminadamente ni optimices hasta obtener una curva perfecta.

## 16. SEGURIDAD Y CONTROL DE OPERACIONES

Implementa:

* Magic number exclusivo.
* Identificación de las posiciones propias.
* Validación de los retcodes del servidor.
* Reintentos limitados y seguros.
* Protección contra solicitudes repetidas.
* Control de spread.
* Control de margen.
* Verificación de stops mínimos y freeze level.
* Recuperación segura tras reiniciar MT5.
* Persistencia de límites diarios y estado relevante.
* Registro de errores.
* Modo de solo análisis, sin abrir operaciones.
* Interruptor global para bloquear nuevas entradas.
* Panel visual sencillo que muestre motor activo, señales, riesgo, operaciones del día, drawdown y motivo del último rechazo.

No declares que una orden fue ejecutada hasta comprobar la respuesta correspondiente del servidor y el estado real de la posición.

## 17. ENTREGABLES

Entrega el trabajo por etapas.

Primero:

1. Documento técnico de la estrategia.
2. Reglas exactas de entrada y salida para cada motor.
3. Lista de parámetros y valores iniciales.
4. Riesgos técnicos y limitaciones.
5. Plan de pruebas.

Después desarrolla:

6. Código MQL5 completo y compilable.
7. Archivos auxiliares necesarios.
8. Instrucciones de instalación en MT5.
9. Configuración recomendada para el Strategy Tester.
10. Archivos de parámetros de ejemplo, si procede.
11. Plantilla de registro CSV.
12. Informe de métricas.
13. Lista de pruebas técnicas y casos límite.
14. Guía de ejecución en demo.

No entregues pseudocódigo como si fuera el EA terminado. Si el proyecto es demasiado extenso para una sola respuesta, divide el trabajo en etapas, mantén una lista de archivos y dependencias y proporciona el contenido completo de cada archivo.

## 18. ORDEN DE TRABAJO

No comiences intentando programar todos los módulos a la vez.

ETAPA A: diseña la arquitectura, define las hipótesis y establece las reglas de cada estrategia.

ETAPA B: desarrolla una primera versión funcional con el motor de anticipación, el motor de ruptura y el gestor de riesgo común.

ETAPA C: añade la detección de falsas rupturas y el sistema de auditoría.

ETAPA D: compila, prueba los casos límite y corrige errores.

ETAPA E: realiza el protocolo de backtest y comparación A/B con datos reales disponibles en MT5.

ETAPA F: revisa los resultados y decide qué variantes merecen pasar a demo.

Al finalizar cada etapa, informa qué está implementado, qué falta, qué pruebas se ejecutaron y cuáles fueron sus resultados reales. No inventes compilaciones, backtests ni operaciones.

Empieza ahora con la ETAPA A. No generes todavía cientos de líneas de código sin haber definido y justificado las reglas. Quiero un sistema medible, modular, auditable y diseñado para buscar movimientos relevantes del Nasdaq sin asumir riesgos innecesarios.
