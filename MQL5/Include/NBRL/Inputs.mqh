//+------------------------------------------------------------------+
//| Inputs.mqh                                                        |
//| Parametros del EA. Valores iniciales y significado:              |
//| docs/etapa-a/03-parametros.md                                     |
//+------------------------------------------------------------------+
#ifndef NBRL_INPUTS_MQH
#define NBRL_INPUTS_MQH

#include "Types.mqh"

input group "=== General ==="
input string          InpSymbol                = "";        // Simbolo (vacio = grafico; cuenta de John: ustec100)
input string          InpSymbolKeywords        = "USTEC,NAS100,NAS,NDX,US100,Nasdaq,US Tech"; // Palabras para validar Nasdaq 100
input bool            InpAllowUnverifiedSymbol = false;     // Permitir simbolo no reconocido (solo pruebas)
input long            InpMagic                 = 26100901;  // Magic number exclusivo
input ENUM_TIMEFRAMES InpTFContext             = PERIOD_M15; // TF de contexto
input ENUM_TIMEFRAMES InpTFEntry               = PERIOD_M5;  // TF de entradas (M5; alternativa M1)
input bool            InpAnalysisOnly          = false;     // Solo analisis (registra senales, no opera)
input bool            InpBlockNewEntries       = false;     // Interruptor global de nuevas entradas
input bool            InpEnableA1              = true;      // Activar A1 (giro agresivo)
input bool            InpEnableA2              = true;      // Activar A2 (giro con estructura)
input bool            InpEnableB1              = true;      // Activar B1 (ruptura directa)
input bool            InpEnableB2              = true;      // Activar B2 (ruptura con retesteo)
input string          InpPriority              = "C1,B2,B1,A2,A1"; // Prioridad si coinciden senales
input int             InpATRPeriod             = 14;        // Periodo ATR

input group "=== Estructura y zonas ==="
input int             SwingStrengthCtx         = 3;     // Velas a cada lado (swing M15)
input int             SwingStrengthEntry       = 2;     // Velas a cada lado (swing M5)
input double          SwingMinATR              = 0.5;   // Amplitud minima entre swings (ATR)
input int             ZoneLookbackBars         = 96;    // Velas M15 para zonas
input double          ZoneWidthATR             = 0.25;  // Semi-anchura de zona (ATR M15)
input int             RegimeERPeriod           = 20;    // Periodo de eficiencia (regimen)
input double          RegimeTrendER            = 0.35;  // ER >= -> tendencia
input double          RegimeRangeER            = 0.20;  // ER <= -> consolidacion
input double          RegimeHighVolRatio       = 1.5;   // ATR14/ATR100 >= -> alta volatilidad

input group "=== Motor A: anticipacion de giros ==="
input int             A_LegLookback            = 24;    // Velas M15 para buscar el tramo
input double          A_LegMinATR              = 3.0;   // Amplitud minima del tramo (ATR M15)
input int             A_LegMinBars             = 6;     // Duracion minima del tramo (velas M15)
input double          A_MaxDistFromExtremeATR  = 1.0;   // Distancia maxima al extremo (ATR M15)
input bool            A_RequireZone            = true;  // Exigir extremo en zona relevante
input int             A_DecelK                 = 3;     // Velas por bloque de impulso
input double          A_DecelRatio             = 0.5;   // Umbral de desaceleracion
input double          A_WickMinRatio           = 0.5;   // Mecha minima / rango
input int             A_FailLookback           = 12;    // Ventana de fallos sucesivos
input int             A_FailMinTouches         = 2;     // Toques minimos
input double          A_FailTolATR             = 0.15;  // Tolerancia de toque (ATR M5)
input bool            A_UseRSIDiv              = true;  // Usar divergencia RSI
input int             A_RSIPeriod              = 14;    // Periodo RSI
input double          A_RSIDivMin              = 3.0;   // Diferencia minima de RSI
input int             A_MinScore               = 2;     // Puntuacion minima de agotamiento
input double          A_InvalidBufATR          = 0.2;   // Margen que invalida el setup (ATR M5)
input int             A_SetupExpiryBars        = 12;    // Vida del setup (velas M5)
input double          A_BreakBufATR            = 0.05;  // Margen de ruptura de microestructura
input double          A2_MaxChaseATR           = 1.5;   // Distancia maxima extremo-disparo A2 (ATR M15)

input group "=== Motor B: rupturas de consolidacion ==="
input int             B_RangeMinBars           = 12;    // Duracion minima del rango (velas)
input int             B_RangeMaxBars           = 48;    // Duracion maxima del rango (velas)
input double          B_RangeMinATR            = 0.8;   // Anchura minima (ATR M15)
input double          B_RangeMaxATR            = 3.0;   // Anchura maxima (ATR M15)
input double          B_CompressionMax         = 0.8;   // Rango medio interior / ATR previo
input int             B_MinTouches             = 2;     // Toques minimos por lado
input double          B_BreakDistATR           = 0.1;   // Distancia del cierre al nivel (ATR M5)
input double          B_BodyRatio              = 0.5;   // Cuerpo minimo de la vela de ruptura
input double          B_ExpansionATR           = 1.0;   // Rango minimo de la vela de ruptura (ATR M5)
input double          B_ExpectedMoveMult       = 1.0;   // Movimiento esperado = mult x anchura
input double          B_MaxChaseFrac           = 0.4;   // Fraccion maxima ya recorrida
input ENUM_NBRL_B_SLMODE B_SLMode              = BSL_MID; // SL estructural
input ENUM_NBRL_TPMODE B_TPMode                = TPMODE_FIXED_R; // Objetivo
input int             B_RetestMaxBars          = 12;    // Espera maxima de retesteo (B2)
input double          B_RetestTolATR           = 0.2;   // Tolerancia de retesteo (ATR M5)
input double          B_ReentryTolATR          = 0.2;   // Margen de vuelta al rango (ATR M5)
input int             B_CooldownBars           = 12;    // Velas sin nueva ruptura en la misma direccion

input group "=== Filtros de calidad (opcionales) ==="
input double          F_MaxSpreadPoints        = 0;     // Spread maximo en puntos (0 = no usar)
input double          F_MaxSpreadATRFrac       = 0.10;  // Spread maximo / ATR M5 (0 = no usar)
input double          F_SpreadRFrac            = 0.15;  // Spread maximo / R (0 = no usar)
input bool            F_UseVolFilter           = false; // Filtro de volatilidad
input double          F_MinATRcPoints          = 0;     // ATR M15 minimo (puntos)
input double          F_MaxATRcPoints          = 0;     // ATR M15 maximo (puntos, 0 = sin limite)
input bool            F_UseRoom                = false; // Exigir espacio hasta la zona opuesta
input double          F_RoomMinR               = 1.0;   // Espacio minimo (R)
input bool            F_UseTickVol             = false; // Volumen tick en rupturas (B)
input double          B_TickVolMult            = 1.2;   // Volumen tick relativo minimo
input bool            F_UseMinRR               = true;  // Relacion recorrido/SL minima
input double          F_MinRR                  = 1.0;   // Recorrido esperado / SL minimo

input group "=== Sesion (hora de Nueva York) ==="
input ENUM_NBRL_SERVER_TIME ServerTimeMode     = SRVTIME_MANUAL; // Hora del servidor
input double          ServerUTCOffsetHours     = 0;     // Offset del servidor respecto a UTC (verificar)
input ENUM_NBRL_SERVER_DST ServerDSTMode       = SRVDST_NONE;    // Horario de verano del servidor
input ENUM_NBRL_SESSION_MODE SessionMode       = SESSION_H24_5;  // Modo de sesion
input string          RolloverBlockNY          = "16:50-17:20"; // Sin entradas en el rollover diario
input ENUM_NBRL_CLOSE_POLICY DailyRolloverPolicy = POLICY_KEEP_WITH_SL; // Posiciones en el rollover
input int             ReopenBlockMin           = 30;    // Minutos sin entradas tras una reapertura
input int             ReopenGapMin             = 45;    // Hueco sin ticks que se considera cierre de mercado
input string          FridayLastEntryNY        = "15:30"; // Ultima entrada del viernes
input string          FridayCloseNY            = "16:30"; // Cierre de posiciones el viernes
input ENUM_NBRL_CLOSE_POLICY WeekendClosePolicy = POLICY_CLOSE_ALL; // Politica de fin de semana
input bool            AllowAsia                = true;  // Bloque Asia (18:00-03:00 NY)
input bool            AllowEurope              = true;  // Bloque Europa (03:00-09:30 NY)
input bool            AllowNY                  = true;  // Bloque NY (09:30-16:00 NY)
input bool            AllowPost                = true;  // Bloque post (16:00-18:00 NY)
input string          TradeStartNY             = "09:35"; // WINDOW: inicio de entradas
input string          LastEntryNY              = "15:30"; // WINDOW: ultima entrada
input string          SessionEndNY             = "15:55"; // WINDOW: fin de ventana
input ENUM_NBRL_CLOSE_POLICY SessionClosePolicy = POLICY_CLOSE_ALL; // WINDOW: politica al final
input string          ExcludeWindowsNY         = "";    // Exclusiones diarias "HH:MM-HH:MM;..."
input string          EventTimesNY             = "";    // Eventos "YYYY.MM.DD HH:MM;..."
input int             EventMarginBeforeMin     = 15;    // Exclusion antes de cada evento
input int             EventMarginAfterMin      = 15;    // Exclusion despues de cada evento
input string          TradingDayStartNY        = "17:00"; // Inicio del dia de trading
input string          TradeWeekdays            = "1,2,3,4,5"; // Dias de trading permitidos (1=lunes)

input group "=== Riesgo ==="
input ENUM_NBRL_RISK_BASE RiskBase             = RISKBASE_EQUITY; // Base de riesgo
input double          RiskFixedCapital         = 0;     // Capital asignado (RiskBase=FIXED)
input double          RiskPerTradePct          = 0.25;  // Riesgo por operacion (%)
input double          DailyLossLimitPct        = 1.0;   // Perdida diaria maxima (%)
input ENUM_NBRL_DAILY_ACTION DailyLimitAction  = DAILY_BLOCK_KEEP_SL; // Accion al tocar el limite
input int             MaxTradesPerDay          = 8;     // Operaciones por dia de trading
input int             MaxTradesPerEnginePerDay = 3;     // Operaciones por motor y dia
input int             MaxConsecLosses          = 3;     // Perdidas seguidas que bloquean el dia
input double          MaxTotalDDPct            = 6.0;   // DD total del EA -> kill switch (%)
input bool            ResetKillSwitch          = false; // Rearmar kill switch
input double          CommissionPerLotRT       = 0;     // Comision ida y vuelta por lote
input double          SLBufferATR              = 0.1;   // Margen sobre el nivel estructural (ATR M5)
input double          SLMinATR                 = 0.5;   // Distancia minima del SL (ATR M5)
input double          SLMaxATR                 = 2.0;   // Distancia maxima del SL (ATR M15)
input double          MaxMarginUsePct          = 30;    // Margen maximo / margen libre (%)
input int             MaxSlippagePoints        = 0;     // Desviacion maxima (puntos, 0 = 10 x spread)

input group "=== Salidas ==="
input double          TP_R                     = 1.5;   // Objetivo (multiplos de R)
input bool            X_BE                     = false; // Break-even
input double          X_BETriggerR             = 1.0;   // MFE para break-even (R)
input bool            X_TrailATR               = false; // Trailing ATR
input double          X_TrailStartR            = 1.0;   // MFE para activar trailing (R)
input double          X_TrailATRMult           = 2.0;   // Distancia del trailing (ATR M5)
input bool            X_MaxBars                = false; // Tiempo maximo
input int             X_MaxBarsEntry           = 24;    // Velas del TF de entrada

input group "=== Seguridad y registros ==="
input int             MaxOrderRetries          = 2;     // Reintentos (solo retcodes recuperables)
input int             RetryDelayMs             = 300;   // Espera entre reintentos (solo en vivo)
input string          LogFolder                = "NBRL"; // Carpeta en MQL5/Files
input bool            LogToCommon              = false; // Usar carpeta comun
input bool            ShowPanel                = true;  // Panel en el grafico
input bool            VerboseLog               = false; // Registro ampliado en el diario

#endif
