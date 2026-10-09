//+------------------------------------------------------------------+
//| ConsolidationBreakoutEngine.mqh                                   |
//| Motor B: rupturas de consolidacion (B1 directa, B2 retesteo).    |
//| Reglas exactas: docs/etapa-a/02-reglas-motores.md (Motor B)       |
//| La logica se escribe para la VENTA (ruptura bajista del suelo)   |
//| sobre un CFrame; la compra usa el marco espejo.                   |
//+------------------------------------------------------------------+
#ifndef NBRL_ENGINE_B_MQH
#define NBRL_ENGINE_B_MQH

#include "MarketStructureDetector.mqh"

struct SBPending
  {
   bool     active;
   string   rid;
   datetime created;     // vela de ruptura
   double   bot, top, w, m;   // marco
   int      bars_left;
   bool     retest;
   int      wait;
   double   r_high, r_low;
   string   reasons;
  };

class CBreakoutEngine
  {
private:
   SBPending m_p[2];
   datetime  m_lastBreak[2];
   CFrame    m_f;

   void     Event(const string txt)
     {
      int k = ArraySize(events);
      ArrayResize(events, k + 1);
      events[k] = txt;
     }

   void     Emit(SSignal &out[], CMarketStructure &msd, const int variant, const int dir, const string type,
                 const string rid, const double slF, const double tpF, const double levelF,
                 const string reasons, const bool rejected, const string why)
     {
      int k = ArraySize(out);
      ArrayResize(out, k + 1);
      out[k].id            = "";
      out[k].variant       = variant;
      out[k].dir           = dir;
      out[k].bar_time      = m_f.t[1];
      out[k].type          = type;
      out[k].structure_id  = rid;
      out[k].entry_ref     = m_f.Real(m_f.c[1]);
      out[k].sl_struct     = m_f.Real(slF);
      out[k].tp_struct     = (tpF == 0.0 ? 0.0 : m_f.Real(tpF));
      out[k].level         = m_f.Real(levelF);
      out[k].room_level    = msd.RoomLevel(out[k].entry_ref, dir);
      out[k].atr_ctx       = msd.atrC1;
      out[k].atr_entry     = msd.atrE1;
      out[k].regime        = msd.regime;
      out[k].vol_ratio     = msd.vr;
      out[k].reasons       = reasons;
      out[k].rejected      = rejected;
      out[k].reject_reason = why;
      out[k].inval_level   = m_f.Real(levelF);
     }

   //--- busca el rango mas largo valido en [2..N+1] (B.0)
   bool     FindRange(CMarketStructure &msd, int &nBars, double &top, double &bot)
     {
      double atrC = msd.atrC1;
      for(int N = B_RangeMaxBars; N >= B_RangeMinBars; N--)
        {
         if(N + 2 >= m_f.n) continue;
         double tp = -DBL_MAX, bt = DBL_MAX, sumRg = 0.0;
         for(int i = 2; i <= N + 1; i++)
           {
            if(m_f.h[i] > tp) tp = m_f.h[i];
            if(m_f.l[i] < bt) bt = m_f.l[i];
            sumRg += m_f.Range(i);
           }
         double w = tp - bt;
         if(w < B_RangeMinATR * atrC || w > B_RangeMaxATR * atrC) continue;
         double atrBefore = m_f.atr[N + 2];
         if(atrBefore <= 0.0 || sumRg / N > B_CompressionMax * atrBefore) continue;
         int tTop = 0, tBot = 0;
         for(int i = 2; i <= N + 1; i++)
           {
            if(m_f.h[i] >= tp - 0.15 * w) tTop++;
            if(m_f.l[i] <= bt + 0.15 * w) tBot++;
           }
         if(tTop < B_MinTouches || tBot < B_MinTouches) continue;
         nBars = N;
         top = tp;
         bot = bt;
         return true;
        }
      return false;
     }

   void     ProcessPending(CMarketStructure &msd, const int dir, SSignal &out[])
     {
      int idx = (dir == DIR_SELL ? 0 : 1);
      if(!m_p[idx].active || m_p[idx].created >= m_f.t[1]) return;
      double atrE = msd.atrE1;
      double bot = m_p[idx].bot;
      bool trigger = false;

      if(m_f.c[1] > bot + B_ReentryTolATR * atrE)
        {
         Event("B2|" + DirName(dir) + "|cancel|reentry|" + m_p[idx].rid);
         m_p[idx].active = false;
         return;
        }
      if(!m_p[idx].retest)
        {
         if(m_f.h[1] >= bot - B_RetestTolATR * atrE && m_f.c[1] <= bot)
           {
            m_p[idx].retest = true;
            m_p[idx].wait   = 0;
            m_p[idx].r_high = m_f.h[1];
            m_p[idx].r_low  = m_f.l[1];
            if(m_f.c[1] < m_f.o[1]) trigger = true;
           }
         else if(bot - m_f.c[1] > B_MaxChaseFrac * m_p[idx].m)
           {
            Event("B2|" + DirName(dir) + "|cancel|missed|" + m_p[idx].rid);
            m_p[idx].active = false;
            return;
           }
        }
      else
        {
         m_p[idx].wait++;
         if(m_f.h[1] > m_p[idx].r_high) m_p[idx].r_high = m_f.h[1];
         if(m_f.c[1] < m_p[idx].r_low) trigger = true;
         else if(m_p[idx].wait >= 2) m_p[idx].retest = false;   // vuelve a buscar retesteo
        }

      if(trigger)
        {
         double sl = MathMax(m_p[idx].r_high, bot);
         double tp = (B_TPMode == TPMODE_MEASURED ? bot - m_p[idx].m : 0.0);
         Emit(out, msd, VAR_B2, dir, "B2_RETEST", m_p[idx].rid, sl, tp, bot,
              m_p[idx].reasons + "retest;", false, "");
         m_p[idx].active = false;
         return;
        }
      m_p[idx].bars_left--;
      if(m_p[idx].bars_left <= 0)
        {
         Event("B2|" + DirName(dir) + "|cancel|expired|" + m_p[idx].rid);
         m_p[idx].active = false;
        }
     }

   void     EvalDir(CMarketStructure &msd, const int dir, SSignal &out[])
     {
      int idx = (dir == DIR_SELL ? 0 : 1);
      msd.BuildEntryFrame(m_f, dir);
      double atrE = msd.atrE1;

      if(InpEnableB2) ProcessPending(msd, dir, out);

      //--- enfriamiento tras una ruptura valida en esta direccion
      if(m_lastBreak[idx] > 0 &&
         m_f.t[1] - m_lastBreak[idx] < (long)B_CooldownBars * PeriodSeconds(InpTFEntry)) return;

      int N = 0;
      double top = 0.0, bot = 0.0;
      if(!FindRange(msd, N, top, bot)) return;
      if(dir == DIR_SELL)
        {
         range_ok   = true;
         range_top  = top;
         range_bot  = bot;
         range_time = m_f.t[N + 1];
        }
      double w = top - bot;
      double m = B_ExpectedMoveMult * w;

      //--- B.1 confirmacion de ruptura bajista (marco)
      if(!(m_f.c[1] < bot - B_BreakDistATR * atrE)) return;

      string rid = "B|" + TimeToString(m_f.t[N + 1]) + "|" + TimeToString(m_f.t[2]);
      string reasons = StringFormat("N=%d;W=%.2fATRc;body=%.2f;rng=%.2fATRe;", N, w / msd.atrC1,
                                    (m_f.Range(1) > 0.0 ? m_f.Body(1) / m_f.Range(1) : 0.0),
                                    m_f.Range(1) / atrE);
      string why = "";
      if(m_f.Range(1) <= 0.0 || m_f.Body(1) < B_BodyRatio * m_f.Range(1)) why = "weak_body";
      else if(m_f.Range(1) < B_ExpansionATR * atrE) why = "no_expansion";
      else if(F_UseTickVol)
        {
         double avg = 0.0;
         for(int i = 2; i <= N + 1; i++) avg += (double)m_f.tv[i];
         avg /= N;
         if((double)m_f.tv[1] < B_TickVolMult * avg) why = "tick_volume";
        }
      if(why == "" && bot - m_f.c[1] > B_MaxChaseFrac * m) why = "chase";

      if(why != "")
        {
         Emit(out, msd, (InpEnableB1 ? VAR_B1 : VAR_B2), dir, "B_BREAKOUT", rid, bot + w / 2.0, 0.0, bot,
              reasons, true, why);
         return;
        }

      m_lastBreak[idx] = m_f.t[1];
      Event("B|" + DirName(dir) + "|breakout|" + rid + "|" + reasons);

      if(InpEnableB1)
        {
         double sl = bot + w / 2.0;
         if(B_SLMode == BSL_BREAKBAR) sl = m_f.h[1];
         else if(B_SLMode == BSL_OPPOSITE) sl = top;
         double tp = (B_TPMode == TPMODE_MEASURED ? bot - m : 0.0);
         Emit(out, msd, VAR_B1, dir, "B1_BREAKOUT", rid, sl, tp, bot, reasons, false, "");
        }
      if(InpEnableB2)
        {
         if(m_p[idx].active) Event("B2|" + DirName(dir) + "|cancel|replaced|" + m_p[idx].rid);
         m_p[idx].active    = true;
         m_p[idx].rid       = rid;
         m_p[idx].created   = m_f.t[1];
         m_p[idx].bot       = bot;
         m_p[idx].top       = top;
         m_p[idx].w         = w;
         m_p[idx].m         = m;
         m_p[idx].bars_left = B_RetestMaxBars;
         m_p[idx].retest    = false;
         m_p[idx].wait      = 0;
         m_p[idx].reasons   = reasons;
        }
     }

public:
   string   events[];
   //--- ultimo rango valido detectado en esta vela (precios reales), para el motor C
   bool     range_ok;
   double   range_top, range_bot;
   datetime range_time;

   void     Reset(void)
     {
      range_ok = false;
      for(int i = 0; i < 2; i++)
        {
         m_p[i].active = false;
         m_lastBreak[i] = 0;
        }
     }

   void     Evaluate(CMarketStructure &msd, SSignal &out[])
     {
      ArrayResize(events, 0);
      range_ok = false;
      if(!InpEnableB1 && !InpEnableB2) return;
      EvalDir(msd, DIR_SELL, out);
      EvalDir(msd, DIR_BUY, out);
     }
  };

#endif
