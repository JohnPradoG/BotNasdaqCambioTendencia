//+------------------------------------------------------------------+
//| Logic.mqh                                                         |
//| Reglas puras (sin estado de mercado) usadas por el EA y por los   |
//| autotests: SL/TP, presupuesto diario, mejora del SL, dia de       |
//| trading y lista de senales vistas.                                |
//+------------------------------------------------------------------+
#ifndef NBRL_LOGIC_MQH
#define NBRL_LOGIC_MQH

#include "Types.mqh"

//--- SL a partir del nivel estructural. Devuelve false con 'why' si se
//--- rechaza. El SL se aleja hasta la distancia minima; nunca se acerca.
bool NBRL_CalcSL(const int dir, const double entry, const double slStruct, const double atrE, const double atrC,
                 const double spread, const double minStop, const double bufATR, const double minATR,
                 const double maxATR, double &sl, string &why)
  {
   if(dir == DIR_SELL) sl = slStruct + bufATR * atrE + spread;
   else                sl = slStruct - bufATR * atrE;
   double dist = (dir == DIR_SELL ? sl - entry : entry - sl);
   if(dist <= 0.0) { why = "sl_wrong_side"; return false; }
   double minD = MathMax(minATR * atrE, minStop + spread);
   if(dist < minD)
     {
      dist = minD;
      sl = (dir == DIR_SELL ? entry + dist : entry - dist);
     }
   if(dist > maxATR * atrC) { why = "sl_too_wide"; return false; }
   return true;
  }

//--- TP: el estructural si da al menos 1R; si no, tpR veces el riesgo
double NBRL_CalcTP(const int dir, const double entry, const double sl, const double tpStruct, const double tpR)
  {
   double dist = MathAbs(entry - sl);
   if(tpStruct > 0.0)
     {
      double reward = (dir == DIR_SELL ? entry - tpStruct : tpStruct - entry);
      if(reward >= 1.0 * dist) return tpStruct;
     }
   return (dir == DIR_SELL ? entry - tpR * dist : entry + tpR * dist);
  }

//--- presupuesto diario: perdida realizada + riesgo abierto + riesgo nuevo
bool NBRL_DailyBudgetOk(const double realized, const double openRisk, const double riskNew, const double limitMoney)
  {
   double used = MathMax(0.0, -realized) + openRisk;
   return (used + riskNew <= limitMoney + 1e-9);
  }

//--- true si el SL propuesto mejora el actual (compra: mas alto; venta: mas bajo)
bool NBRL_SLIsBetter(const bool isBuy, const double cur, const double newSL, const double pt)
  {
   if(cur <= 0.0) return true;
   if(isBuy) return (newSL > cur + pt / 2.0);
   return (newSL < cur - pt / 2.0);
  }

//--- clave del dia de trading a partir de la hora NY (empieza a dayStartMin)
datetime NBRL_TradingDayKeyNY(const datetime ny, const int dayStartMin)
  {
   long shifted = (long)ny + (long)(24 * 60 - dayStartMin) * 60;
   return (datetime)(shifted - shifted % 86400);
  }

//--- lista acotada de signal_id ya vistos
class CSeenList
  {
private:
   string   m_ids[];
public:
   void     Clear(void) { ArrayResize(m_ids, 0); }
   //--- true si ya estaba; si no, lo anade
   bool     Seen(const string id)
     {
      for(int i = ArraySize(m_ids) - 1; i >= 0; i--)
         if(m_ids[i] == id) return true;
      int n = ArraySize(m_ids);
      if(n >= 2000)
        {
         ArrayRemove(m_ids, 0, 500);
         n = ArraySize(m_ids);
        }
      ArrayResize(m_ids, n + 1);
      m_ids[n] = id;
      return false;
     }
  };

#endif
