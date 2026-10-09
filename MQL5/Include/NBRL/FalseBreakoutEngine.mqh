//+------------------------------------------------------------------+
//| FalseBreakoutEngine.mqh                                           |
//| Motor C: falsas rupturas (C1). Clasifica cada sobrepaso de un    |
//| nivel en TRUE_BREAK, FALSE_RETURN, EXTEND_REVERT o                |
//| SWEEP_UNCONFIRMED y solo opera en contra tras FALSE_RETURN o      |
//| EXTEND_REVERT con confirmacion. Describe el precio; no atribuye   |
//| intencion a ningun participante.                                  |
//| Reglas exactas: docs/etapa-a/02-reglas-motores.md (Motor C)       |
//| Logica escrita para la VENTA (sobrepaso de un nivel superior)    |
//| sobre un CFrame; la compra usa el marco espejo.                   |
//+------------------------------------------------------------------+
#ifndef NBRL_ENGINE_C_MQH
#define NBRL_ENGINE_C_MQH

#include "MarketStructureDetector.mqh"

#define NBRL_C_MAX_EVENTS 12
#define NBRL_C_MAX_TRADED 200

struct SCEvent
  {
   bool     active;
   double   lv;          // nivel (marco)
   string   src;
   bool     range_level; // nivel procedente del rango del motor B
   double   range_mid;   // punto medio del rango (marco), si range_level
   datetime start;       // vela del sobrepaso
   int      bars;        // velas desde el sobrepaso (0 = la propia vela)
   double   ext;         // maximo desde el sobrepaso (marco)
   int      closes_above;
   int      consec_above;
   bool     true_break;
  };

class CFalseBreakoutEngine
  {
private:
   SCEvent  m_ev[2][NBRL_C_MAX_EVENTS];
   string   m_traded[];       // niveles ya operados: "<idx>|<precio>"
   CFrame   m_f;
   SSwing   m_sw[];

   void     Event(const string txt)
     {
      int k = ArraySize(events);
      ArrayResize(events, k + 1);
      events[k] = txt;
     }

   string   LevelKey(const double lvReal, const int digits) const { return DoubleToString(lvReal, digits); }

   bool     WasTraded(const int idx, const string key) const
     {
      string k = IntegerToString(idx) + "|" + key;
      for(int i = ArraySize(m_traded) - 1; i >= 0; i--)
         if(m_traded[i] == k) return true;
      return false;
     }

   void     MarkTraded(const int idx, const string key)
     {
      int n = ArraySize(m_traded);
      if(n >= NBRL_C_MAX_TRADED) { ArrayRemove(m_traded, 0, 50); n = ArraySize(m_traded); }
      ArrayResize(m_traded, n + 1);
      m_traded[n] = IntegerToString(idx) + "|" + key;
     }

   bool     HasEvent(const int idx, const double lv, const double tol) const
     {
      for(int i = 0; i < NBRL_C_MAX_EVENTS; i++)
         if(m_ev[idx][i].active && MathAbs(m_ev[idx][i].lv - lv) <= tol) return true;
      return false;
     }

   int      FreeSlot(const int idx) const
     {
      for(int i = 0; i < NBRL_C_MAX_EVENTS; i++) if(!m_ev[idx][i].active) return i;
      return -1;
     }

   string   Sid(const int idx, const int i, const int dir, const int digits)
     {
      return "C|" + DirName(dir) + "|" + m_ev[idx][i].src + "|" +
             DoubleToString(m_f.Real(m_ev[idx][i].lv), digits) + "|" + TimeToString(m_ev[idx][i].start);
     }

   void     Emit(SSignal &out[], CMarketStructure &msd, const int dir, const int idx, const int i,
                 const string label, const string reasons, const bool rejected, const string why)
     {
      SCEvent e = m_ev[idx][i];
      int k = ArraySize(out);
      ArrayResize(out, k + 1);
      out[k].id            = "";
      out[k].variant       = VAR_C1;
      out[k].dir           = dir;
      out[k].bar_time      = m_f.t[1];
      out[k].type          = "C1_" + label;
      out[k].structure_id  = Sid(idx, i, dir, msd.digits);
      out[k].entry_ref     = m_f.Real(m_f.c[1]);
      out[k].sl_struct     = m_f.Real(e.ext);
      out[k].tp_struct     = (C_TPMode == TPMODE_MEASURED && e.range_level ? m_f.Real(e.range_mid) : 0.0);
      out[k].level         = m_f.Real(e.lv);
      out[k].room_level    = msd.RoomLevel(out[k].entry_ref, dir);
      out[k].inval_level   = m_f.Real(e.lv);
      out[k].atr_ctx       = msd.atrC1;
      out[k].atr_entry     = msd.atrE1;
      out[k].regime        = msd.regime;
      out[k].vol_ratio     = msd.vr;
      out[k].reasons       = reasons;
      out[k].rejected      = rejected;
      out[k].reject_reason = why;
     }

   //--- clasifica el evento i con la vela [1]; devuelve true si el evento termina
   bool     Classify(CMarketStructure &msd, const int dir, const int idx, const int i, SSignal &out[])
     {
      double atrE = msd.atrE1, atrC = msd.atrC1;
      double lv = m_ev[idx][i].lv;
      if(m_f.h[1] > m_ev[idx][i].ext) m_ev[idx][i].ext = m_f.h[1];
      if(m_f.c[1] > lv)
        {
         m_ev[idx][i].closes_above++;
         if(m_f.c[1] > lv + B_BreakDistATR * atrE) m_ev[idx][i].consec_above++;
         else m_ev[idx][i].consec_above = 0;
        }
      else m_ev[idx][i].consec_above = 0;

      string tag = DirName(dir) + "|" + m_ev[idx][i].src + "|" + DoubleToString(m_f.Real(lv), msd.digits);
      if(!m_ev[idx][i].true_break && m_ev[idx][i].consec_above >= C_HoldBars)
        {
         m_ev[idx][i].true_break = true;
         Event("C|" + tag + "|TRUE_BREAK");
        }

      //--- regreso al rango
      if(m_f.c[1] < lv - C_ReentryDepthATR * atrE)
        {
         string label = "";
         if(!m_ev[idx][i].true_break && m_ev[idx][i].closes_above <= 1 && m_ev[idx][i].bars <= C_WindowBars)
            label = "FALSE_RETURN";
         else if((m_ev[idx][i].true_break || m_ev[idx][i].closes_above >= 2) &&
                 m_ev[idx][i].ext - lv >= 0.5 * atrC && m_ev[idx][i].bars <= C_LateWindowBars)
            label = "EXTEND_REVERT";
         if(label == "")
           {
            Event("C|" + tag + "|RETURN_UNCLASSIFIED");
            return true;
           }
         Event("C|" + tag + "|" + label);
         if(!InpEnableC1) return true;

         //--- confirmacion: vela bajista con cuerpo, o cierre bajo el ultimo swing low de la excursion
         double rg = m_f.Range(1);
         bool bodyOk = (rg > 0.0 && m_f.c[1] < m_f.o[1] && m_f.Body(1) >= C_BodyRatio * rg);
         bool microOk = false;
         for(int s = ArraySize(m_sw) - 1; s >= 0; s--)
           {
            if(m_sw[s].is_high || m_sw[s].time < m_ev[idx][i].start) continue;
            microOk = (m_f.c[1] < m_sw[s].price);
            break;
           }
         string reasons = StringFormat("label=%s;exc=%.2fATRc;closes_above=%d;bars=%d;%s%s", label,
                                       (m_ev[idx][i].ext - lv) / atrC, m_ev[idx][i].closes_above,
                                       m_ev[idx][i].bars, (bodyOk ? "BODY;" : ""), (microOk ? "MICRO;" : ""));
         if(!bodyOk && !microOk)
           {
            Event("C|" + tag + "|no_confirmation");
            return true;
           }
         string key = LevelKey(m_f.Real(lv), msd.digits);
         if(WasTraded(idx, key))
           {
            Event("C|" + tag + "|level_already_traded");
            return true;
           }
         bool tooBig = (m_ev[idx][i].ext - lv > C_MaxExcursionATR * atrC);
         Emit(out, msd, dir, idx, i, label, reasons, tooBig, (tooBig ? "excursion_too_big" : ""));
         if(!tooBig) MarkTraded(idx, key);
         return true;
        }

      //--- fin de ventana sin regreso
      int window = (m_ev[idx][i].true_break || m_ev[idx][i].closes_above >= 2 ? C_LateWindowBars : C_WindowBars);
      if(m_ev[idx][i].bars >= window)
        {
         string label = (m_ev[idx][i].true_break ? "TRUE_BREAK_HELD" :
                        (m_ev[idx][i].closes_above == 0 ? "SWEEP_UNCONFIRMED" : "UNRESOLVED"));
         Event("C|" + tag + "|" + label);
         return true;
        }
      return false;
     }

   void     EvalDir(CMarketStructure &msd, const int dir, const SRange &rng, SSignal &out[])
     {
      int idx = (dir == DIR_SELL ? 0 : 1);
      msd.BuildEntryFrame(m_f, dir);
      NBRL_FindSwings(m_f.h, m_f.l, m_f.t, m_f.n, SwingStrengthEntry, SwingMinATR * msd.atrE1, m_sw);
      double atrE = msd.atrE1;

      //--- 1) eventos abiertos en velas anteriores
      for(int i = 0; i < NBRL_C_MAX_EVENTS; i++)
        {
         if(!m_ev[idx][i].active || m_ev[idx][i].start >= m_f.t[1]) continue;
         m_ev[idx][i].bars++;
         if(Classify(msd, dir, idx, i, out)) m_ev[idx][i].active = false;
        }

      //--- 2) nuevos sobrepasos en la vela [1]
      double lvls[];
      string srcs[];
      datetime times[];
      bool isRange[];
      int n = 0;
      for(int z = 0; z < ArraySize(msd.zones); z++)
        {
         ArrayResize(lvls, n + 1); ArrayResize(srcs, n + 1); ArrayResize(times, n + 1); ArrayResize(isRange, n + 1);
         lvls[n] = m_f.ToFrame(msd.zones[z].price);
         srcs[n] = msd.zones[z].source;
         times[n] = msd.zones[z].time;
         isRange[n] = false;
         n++;
        }
      double rangeMid = 0.0;
      if(rng.ok)
        {
         double a = m_f.ToFrame(rng.top), b = m_f.ToFrame(rng.bot);
         double upper = MathMax(a, b);
         rangeMid = (a + b) / 2.0;
         ArrayResize(lvls, n + 1); ArrayResize(srcs, n + 1); ArrayResize(times, n + 1); ArrayResize(isRange, n + 1);
         lvls[n] = upper;
         srcs[n] = "RANGE";
         times[n] = rng.time;
         isRange[n] = true;
         n++;
        }
      long minAge = (long)C_MinLevelAgeBars * PeriodSeconds(InpTFEntry);
      for(int j = 0; j < n; j++)
        {
         double lv = lvls[j];
         if((long)m_f.t[1] - (long)times[j] < minAge) continue;
         if(!(m_f.h[1] > lv + C_SweepMinATR * atrE)) continue;
         if(m_f.c[2] >= lv || m_f.h[2] > lv + C_SweepMinATR * atrE) continue;   // sobrepaso nuevo
         if(HasEvent(idx, lv, 0.1 * atrE)) continue;
         if(WasTraded(idx, LevelKey(m_f.Real(lv), msd.digits))) continue;
         int slot = FreeSlot(idx);
         if(slot < 0) break;
         m_ev[idx][slot].active       = true;
         m_ev[idx][slot].lv           = lv;
         m_ev[idx][slot].src          = srcs[j];
         m_ev[idx][slot].range_level  = isRange[j];
         m_ev[idx][slot].range_mid    = rangeMid;
         m_ev[idx][slot].start        = m_f.t[1];
         m_ev[idx][slot].bars         = 0;
         m_ev[idx][slot].ext          = m_f.h[1];
         m_ev[idx][slot].closes_above = 0;
         m_ev[idx][slot].consec_above = 0;
         m_ev[idx][slot].true_break   = false;
         if(Classify(msd, dir, idx, slot, out)) m_ev[idx][slot].active = false;
        }
     }

public:
   string   events[];

   void     Reset(void)
     {
      for(int d = 0; d < 2; d++)
        {
         for(int i = 0; i < NBRL_C_MAX_EVENTS; i++) m_ev[d][i].active = false;
        }
      ArrayResize(m_traded, 0);
     }

   //--- el clasificador corre siempre (registra la frecuencia de cada tipo);
   //--- solo emite senales si InpEnableC1
   void     Evaluate(CMarketStructure &msd, const SRange &rng, SSignal &out[])
     {
      ArrayResize(events, 0);
      EvalDir(msd, DIR_SELL, rng, out);
      EvalDir(msd, DIR_BUY, rng, out);
     }
  };

#endif
