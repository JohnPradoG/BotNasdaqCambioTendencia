//+------------------------------------------------------------------+
//| SignalQualityFilter.mqh                                           |
//| Filtros opcionales (SPEC §8). Cada uno tiene su interruptor para |
//| pruebas A/B. Devuelve el nombre del filtro que rechaza.           |
//| Los filtros de rechazo por mecha, divergencia RSI, calidad de    |
//| consolidacion e impulso viven en los propios motores.             |
//+------------------------------------------------------------------+
#ifndef NBRL_FILTER_MQH
#define NBRL_FILTER_MQH

#include "Inputs.mqh"

class CSignalQualityFilter
  {
public:
   //--- entry/sl/tp: precios finales; spread en precio; point del simbolo
   bool     Check(const SSignal &s, const double entry, const double sl, const double tp,
                  const double spread, const double point, string &why) const
     {
      why = "";
      double r = MathAbs(entry - sl);
      if(r <= 0.0) { why = "zero_r"; return false; }
      if(F_MaxSpreadPoints > 0 && point > 0.0 && spread / point > F_MaxSpreadPoints)
        { why = "spread_points"; return false; }
      if(F_MaxSpreadATRFrac > 0 && spread > F_MaxSpreadATRFrac * s.atr_entry)
        { why = "spread_atr"; return false; }
      if(F_SpreadRFrac > 0 && spread > F_SpreadRFrac * r)
        { why = "spread_r"; return false; }
      if(F_UseVolFilter && point > 0.0)
        {
         double atrPts = s.atr_ctx / point;
         if(F_MinATRcPoints > 0 && atrPts < F_MinATRcPoints) { why = "vol_low"; return false; }
         if(F_MaxATRcPoints > 0 && atrPts > F_MaxATRcPoints) { why = "vol_high"; return false; }
        }
      if(F_UseRoom && s.room_level > 0.0 && MathAbs(s.room_level - entry) < F_RoomMinR * r)
        { why = "room"; return false; }
      if(F_UseMinRR && tp > 0.0 && MathAbs(tp - entry) / r < F_MinRR)
        { why = "min_rr"; return false; }
      return true;
     }
  };

#endif
