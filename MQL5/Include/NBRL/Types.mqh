//+------------------------------------------------------------------+
//| Types.mqh                                                         |
//| NASDAQ BREAKOUT & REVERSAL LAB - tipos y utilidades comunes       |
//| Reglas: docs/etapa-a/01-documento-tecnico.md                      |
//+------------------------------------------------------------------+
#ifndef NBRL_TYPES_MQH
#define NBRL_TYPES_MQH

#define NBRL_NAME    "NBRL"
#define NBRL_VERSION "0.1.0"

//--- direccion de la operacion
#define DIR_BUY   1
#define DIR_SELL -1

//--- motores y variantes
enum ENUM_NBRL_VARIANT
  {
   VAR_A1 = 0,
   VAR_A2 = 1,
   VAR_B1 = 2,
   VAR_B2 = 3,
   VAR_C1 = 4
  };
#define NBRL_VARIANTS 5

enum ENUM_NBRL_SESSION_MODE
  {
   SESSION_H24_5  = 0,   // 24/5 con bloqueos (por defecto)
   SESSION_WINDOW = 1    // ventana unica configurable
  };

enum ENUM_NBRL_CLOSE_POLICY
  {
   POLICY_CLOSE_ALL    = 0, // cerrar posiciones del EA
   POLICY_KEEP_WITH_SL = 1  // mantener con su SL
  };

enum ENUM_NBRL_SERVER_TIME
  {
   SRVTIME_MANUAL = 0,   // offset manual (obligatorio en tester)
   SRVTIME_AUTO   = 1    // TimeTradeServer()-TimeGMT() (solo en vivo)
  };

enum ENUM_NBRL_SERVER_DST
  {
   SRVDST_NONE = 0,      // offset fijo todo el anio
   SRVDST_US   = 1       // +1 h cuando EE. UU. esta en horario de verano
  };

enum ENUM_NBRL_RISK_BASE
  {
   RISKBASE_EQUITY  = 0,
   RISKBASE_BALANCE = 1,
   RISKBASE_FIXED   = 2
  };

enum ENUM_NBRL_DAILY_ACTION
  {
   DAILY_BLOCK_KEEP_SL   = 0,
   DAILY_BLOCK_CLOSE_ALL = 1
  };

enum ENUM_NBRL_B_SLMODE
  {
   BSL_MID      = 0,     // punto medio del rango
   BSL_BREAKBAR = 1,     // extremo de la vela de ruptura
   BSL_OPPOSITE = 2      // lado opuesto del rango
  };

enum ENUM_NBRL_TPMODE
  {
   TPMODE_FIXED_R  = 0,  // objetivo en multiplos de R
   TPMODE_MEASURED = 1   // movimiento medido / objetivo estructural
  };

enum ENUM_NBRL_TIME_BLOCK
  {
   TB_ASIA   = 0,        // 18:00-03:00 NY
   TB_EUROPE = 1,        // 03:00-09:30 NY
   TB_NY     = 2,        // 09:30-16:00 NY
   TB_POST   = 3         // 16:00-18:00 NY
  };

enum ENUM_NBRL_REGIME
  {
   REGIME_MIXED = 0,
   REGIME_TREND = 1,
   REGIME_RANGE = 2
  };

//+------------------------------------------------------------------+
//| Swing confirmado                                                 |
//+------------------------------------------------------------------+
struct SSwing
  {
   bool     is_high;
   int      shift;       // indice en la serie (1 = ultima vela cerrada)
   datetime time;
   double   price;
  };

//+------------------------------------------------------------------+
//| Zona relevante                                                   |
//+------------------------------------------------------------------+
struct SZone
  {
   double   price;
   int      touches;
   datetime time;        // momento en que se formo el nivel
   string   source;      // SW (swing M15), PDH, PDL, ONH, ONL
  };

//+------------------------------------------------------------------+
//| Senal generada por un motor. Inmutable una vez registrada.       |
//| Los precios estan en precios reales (no en el marco espejo).     |
//+------------------------------------------------------------------+
struct SSignal
  {
   string   id;              // identificador unico (hash)
   int      variant;         // ENUM_NBRL_VARIANT
   int      dir;             // DIR_BUY / DIR_SELL
   datetime bar_time;        // apertura de la vela de senal (vela [1])
   string   type;            // tipo de senal (texto corto)
   string   structure_id;    // rango / estructura analizada
   double   entry_ref;       // cierre de la vela de senal
   double   sl_struct;       // SL estructural (sin buffer comun ni spread)
   double   tp_struct;       // objetivo estructural (0 = usar R fijo)
   double   level;           // nivel clave (H*, techo/suelo del rango)
   double   room_level;      // zona opuesta mas cercana (0 = ninguna)
   double   atr_ctx;
   double   atr_entry;
   int      regime;
   double   vol_ratio;
   string   reasons;         // componentes cumplidos
   bool     rejected;        // rechazada ya por el propio motor
   string   reject_reason;
  };

//+------------------------------------------------------------------+
//| Utilidades                                                       |
//+------------------------------------------------------------------+
string VariantName(const int v)
  {
   switch(v)
     {
      case VAR_A1: return "A1";
      case VAR_A2: return "A2";
      case VAR_B1: return "B1";
      case VAR_B2: return "B2";
      case VAR_C1: return "C1";
     }
   return "??";
  }

string EngineName(const int v)
  {
   if(v == VAR_A1 || v == VAR_A2) return "A";
   if(v == VAR_B1 || v == VAR_B2) return "B";
   return "C";
  }

int EngineIndex(const int v)
  {
   if(v == VAR_A1 || v == VAR_A2) return 0;
   if(v == VAR_B1 || v == VAR_B2) return 1;
   return 2;
  }

string DirName(const int d) { return (d == DIR_BUY ? "BUY" : "SELL"); }

string TimeBlockName(const int b)
  {
   switch(b)
     {
      case TB_ASIA:   return "ASIA";
      case TB_EUROPE: return "EUROPE";
      case TB_NY:     return "NY";
      case TB_POST:   return "POST";
     }
   return "?";
  }

string RegimeName(const int r)
  {
   switch(r)
     {
      case REGIME_TREND: return "TREND";
      case REGIME_RANGE: return "RANGE";
     }
   return "MIXED";
  }

//--- FNV-1a de 32 bits para identificadores estables de senal
string HashString(const string s)
  {
   uint h = (uint)2166136261;
   int  n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      h ^= (uint)StringGetCharacter(s, i);
      h *= (uint)16777619;
     }
   return StringFormat("%08X", h);
  }

//--- "HH:MM" -> minutos del dia (-1 si no es valido)
int ParseHHMM(const string s)
  {
   string t = s;
   StringTrimLeft(t);
   StringTrimRight(t);
   string parts[];
   if(StringSplit(t, ':', parts) != 2) return -1;
   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);
   if(h < 0 || h > 23 || m < 0 || m > 59) return -1;
   return h * 60 + m;
  }

//--- minuto m dentro de [from,to) admitiendo cruce de medianoche
bool MinuteInRange(const int m, const int from, const int to)
  {
   if(from < 0 || to < 0) return false;
   if(from <= to) return (m >= from && m < to);
   return (m >= from || m < to);
  }

double NormalizePrice(const string sym, const double price)
  {
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   int digits  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(tick > 0.0) return NormalizeDouble(MathRound(price / tick) * tick, digits);
   return NormalizeDouble(price, digits);
  }

#endif
