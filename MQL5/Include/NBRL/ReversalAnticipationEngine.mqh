//+------------------------------------------------------------------+
//| ReversalAnticipationEngine.mqh                                    |
//| Motor A: anticipacion de giros (A1 agresiva, A2 estructural).    |
//| Reglas exactas: docs/etapa-a/02-reglas-motores.md (Motor A)       |
//| Toda la logica se escribe para la VENTA sobre un CFrame; la      |
//| compra usa el marco espejo (ver CFrame).                          |
//+------------------------------------------------------------------+
#ifndef NBRL_ENGINE_A_MQH
#define NBRL_ENGINE_A_MQH

#include "MarketStructureDetector.mqh"

struct SASetup
  {
   bool     armed;
   datetime leg_base_time;   // vela M15 del inicio del tramo
   double   ext;             // extremo H* (marco)
   datetime ext_time;
   double   arm_ext;         // H* en el momento de armar (para invalidar)
   int      bars;            // velas desde que se armo
   string   sid;
   string   comps;
   bool     fired_a1;
   bool     fired_a2;
  };

class CReversalEngine
  {
private:
   SASetup  m_set[2];        // 0 = venta, 1 = compra
   string   m_lastSid[2];
   CFrame   m_f;
   SSwing   m_sw[];

   //--- maximo/minimo M15 en el marco de la direccion
   double   CH(CMarketStructure &msd, const int i, const int dir) const
     { return (dir == DIR_SELL ? msd.c[i].high : -msd.c[i].low); }
   double   CL(CMarketStructure &msd, const int i, const int dir) const
     { return (dir == DIR_SELL ? msd.c[i].low : -msd.c[i].high); }

   void     Event(const string txt)
     {
      int k = ArraySize(events);
      ArrayResize(events, k + 1);
      events[k] = txt;
     }

   void     Emit(SSignal &out[], const int variant, const int dir, const string type,
                 const SASetup &s, CMarketStructure &msd, const bool rejected, const string why)
     {
      int k = ArraySize(out);
      ArrayResize(out, k + 1);
      out[k].id            = "";
      out[k].variant       = variant;
      out[k].dir           = dir;
      out[k].bar_time      = m_f.t[1];
      out[k].type          = type;
      out[k].structure_id  = s.sid;
      out[k].entry_ref     = m_f.Real(m_f.c[1]);
      out[k].sl_struct     = m_f.Real(s.ext);
      out[k].tp_struct     = 0.0;
      out[k].level         = m_f.Real(s.ext);
      out[k].room_level    = msd.RoomLevel(out[k].entry_ref, dir);
      out[k].atr_ctx       = msd.atrC1;
      out[k].atr_entry     = msd.atrE1;
      out[k].regime        = msd.regime;
      out[k].vol_ratio     = msd.vr;
      out[k].reasons       = s.comps;
      out[k].rejected      = rejected;
      out[k].reject_reason = why;
      out[k].inval_level   = 0.0;
     }

   //--- puntuacion de agotamiento (A.1); devuelve componentes cumplidos
   int      Score(CMarketStructure &msd, const double ext, const datetime legBaseTime, string &comps)
     {
      double atrE = msd.atrE1;
      int score = 0;
      comps = "";
      //--- DEC: perdida de aceleracion
      int k = A_DecelK;
      if(1 + 2 * k < m_f.n)
        {
         double impPrev = m_f.c[1 + k] - m_f.c[1 + 2 * k];
         double impRec  = m_f.c[1] - m_f.c[1 + k];
         if(impPrev > 0.5 * atrE && impRec < A_DecelRatio * impPrev) { score++; comps += "DEC;"; }
        }
      //--- WCK: rechazo por mecha en el extremo (ultimas 3 velas)
      for(int v = 1; v <= 3; v++)
        {
         double rg = m_f.Range(v);
         if(rg <= 0.0) continue;
         double upper = m_f.h[v] - MathMax(m_f.o[v], m_f.c[v]);
         if(m_f.h[v] >= ext - 0.1 * atrE && rg >= 0.8 * atrE &&
            upper >= A_WickMinRatio * rg && m_f.c[v] <= m_f.l[v] + 0.5 * rg)
           { score++; comps += "WCK;"; break; }
        }
      //--- FAIL: fallos sucesivos en la zona del extremo
      double tol = A_FailTolATR * atrE;
      int touches = 0, lastTouch = -100, firstTouch = -1;
      for(int i = MathMin(A_FailLookback, m_f.n - 2); i >= 1; i--)   // de antigua a reciente
        {
         if(m_f.h[i] >= ext - tol && m_f.c[i] < ext - tol)
           {
            if(lastTouch < 0 || lastTouch - i >= 3)
              {
               touches++;
               lastTouch = i;
               if(firstTouch < 0) firstTouch = i;
              }
           }
        }
      bool closedAbove = false;
      if(firstTouch > 0)
         for(int i = firstTouch; i >= 1; i--)
            if(m_f.c[i] > ext + tol) closedAbove = true;
      if(touches >= A_FailMinTouches && !closedAbove) { score++; comps += "FAIL;"; }
      //--- DIV: divergencia RSI entre los dos ultimos swing highs del tramo
      if(A_UseRSIDiv)
        {
         int h2 = -1, h1 = -1;
         for(int i = ArraySize(m_sw) - 1; i >= 0; i--)
           {
            if(!m_sw[i].is_high || m_sw[i].time < legBaseTime) continue;
            if(h2 < 0) h2 = i;
            else { h1 = i; break; }
           }
         if(h1 >= 0 && h2 >= 0)
           {
            double r1 = m_f.rsi[m_sw[h1].shift];
            double r2 = m_f.rsi[m_sw[h2].shift];
            if(m_sw[h2].price >= m_sw[h1].price && r2 <= r1 - A_RSIDivMin && r1 >= 60.0)
              { score++; comps += "DIV;"; }
           }
        }
      return score;
     }

   void     EvalDir(CMarketStructure &msd, const int dir, SSignal &out[])
     {
      int idx = (dir == DIR_SELL ? 0 : 1);
      msd.BuildEntryFrame(m_f, dir);
      NBRL_FindSwings(m_f.h, m_f.l, m_f.t, m_f.n, SwingStrengthEntry, SwingMinATR * msd.atrE1, m_sw);
      double atrE = msd.atrE1;
      double atrC = msd.atrC1;

      //--- 1) setup armado: actualizar, invalidar o expirar
      if(m_set[idx].armed)
        {
         m_set[idx].bars++;
         if(m_f.h[1] > m_set[idx].ext) { m_set[idx].ext = m_f.h[1]; m_set[idx].ext_time = m_f.t[1]; }
         if(m_f.c[1] > m_set[idx].arm_ext + A_InvalidBufATR * atrE)
           {
            Event("A|" + DirName(dir) + "|cancel|new_extreme|" + m_set[idx].sid);
            m_set[idx].armed = false;
           }
         else if(m_set[idx].bars > A_SetupExpiryBars)
           {
            Event("A|" + DirName(dir) + "|cancel|expired|" + m_set[idx].sid);
            m_set[idx].armed = false;
           }
        }

      //--- 2) sin setup: contexto (A.0) + agotamiento (A.1)
      if(!m_set[idx].armed)
        {
         int nC = msd.nC;
         int look = MathMin(A_LegLookback, nC - 2);
         int jLow = 1;
         for(int i = 1; i <= look; i++) if(CL(msd, i, dir) < CL(msd, jLow, dir)) jLow = i;
         if(jLow < 2) return;
         int jHigh = 1;
         for(int i = 1; i < jLow; i++) if(CH(msd, i, dir) > CH(msd, jHigh, dir)) jHigh = i;
         double legAmp = CH(msd, jHigh, dir) - CL(msd, jLow, dir);
         if(legAmp < A_LegMinATR * atrC || jLow - jHigh < A_LegMinBars) return;

         //--- extremo H* con detalle M5 desde la vela M15 del maximo
         datetime fromT = msd.c[jHigh].time;
         double ext = -DBL_MAX;
         datetime extT = 0;
         for(int i = 1; i < m_f.n && m_f.t[i] >= fromT; i++)
            if(m_f.h[i] > ext) { ext = m_f.h[i]; extT = m_f.t[i]; }
         if(extT == 0) return;
         if(ext - m_f.c[1] > A_MaxDistFromExtremeATR * atrC) return;

         //--- zona relevante
         datetime legBaseT = msd.c[jLow].time;
         bool inZone = msd.InZone(m_f.Real(ext), legBaseT);
         bool isMax96 = true;
         int z = MathMin(96, nC - 1);
         for(int i = 1; i <= z; i++) if(CH(msd, i, dir) > ext) { isMax96 = false; break; }
         if(A_RequireZone && !inZone && !isMax96) return;

         string comps;
         int score = Score(msd, ext, legBaseT, comps);
         if(score < A_MinScore) return;

         string sid = "A|" + DirName(dir) + "|" + TimeToString(legBaseT) + "|" + TimeToString(extT);
         if(sid == m_lastSid[idx]) return;   // ya se armo y termino este mismo setup
         m_set[idx].armed         = true;
         m_set[idx].leg_base_time = legBaseT;
         m_set[idx].ext           = ext;
         m_set[idx].ext_time      = extT;
         m_set[idx].arm_ext       = ext;
         m_set[idx].bars          = 0;
         m_set[idx].sid           = sid;
         m_set[idx].comps         = comps + StringFormat("score=%d;leg=%.1fATR;zone=%s;max96=%s;", score,
                                    legAmp / atrC, (inZone ? "Y" : "N"), (isMax96 ? "Y" : "N"));
         m_set[idx].fired_a1      = false;
         m_set[idx].fired_a2      = false;
         m_lastSid[idx]           = sid;
         Event("A|" + DirName(dir) + "|armed|" + sid + "|" + m_set[idx].comps);
        }

      //--- 3) disparos
      SASetup s = m_set[idx];
      if(InpEnableA1 && !s.fired_a1)
        {
         double rg = m_f.Range(1);
         if(m_f.c[1] < m_f.o[1] && m_f.c[1] < m_f.l[2] && rg > 0.0 && m_f.Body(1) >= 0.4 * rg)
           {
            Emit(out, VAR_A1, dir, "A1_REJECTION_BAR", s, msd, false, "");
            m_set[idx].fired_a1 = true;
           }
        }
      if(InpEnableA2 && !s.fired_a2)
        {
         //--- L_micro: ultimo swing low confirmado del tramo, anterior al extremo
         double lMicro = 0.0;
         bool found = false;
         for(int i = ArraySize(m_sw) - 1; i >= 0; i--)
           {
            if(m_sw[i].is_high) continue;
            if(m_sw[i].time > s.leg_base_time && m_sw[i].time < s.ext_time)
              { lMicro = m_sw[i].price; found = true; break; }
           }
         if(found && m_f.c[1] < lMicro - A_BreakBufATR * atrE)
           {
            SASetup s2 = s;
            s2.comps += StringFormat("Lmicro=%s;", DoubleToString(m_f.Real(lMicro), msd.digits));
            bool chase = (s.ext - m_f.c[1] > A2_MaxChaseATR * atrC);
            Emit(out, VAR_A2, dir, "A2_MICRO_BREAK", s2, msd, chase, (chase ? "chase" : ""));
            out[ArraySize(out) - 1].inval_level = m_f.Real(lMicro);
            m_set[idx].fired_a2 = true;
           }
        }
     }

public:
   string   events[];

   void     Reset(void)
     {
      for(int i = 0; i < 2; i++)
        {
         m_set[i].armed = false;
         m_lastSid[i] = "";
        }
     }

   //--- anade a 'out' las senales de la vela [1]
   void     Evaluate(CMarketStructure &msd, SSignal &out[])
     {
      ArrayResize(events, 0);
      if(!InpEnableA1 && !InpEnableA2) return;
      EvalDir(msd, DIR_SELL, out);
      EvalDir(msd, DIR_BUY, out);
     }
  };

#endif
