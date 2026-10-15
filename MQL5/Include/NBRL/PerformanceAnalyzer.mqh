//+------------------------------------------------------------------+
//| PerformanceAnalyzer.mqh                                           |
//| Resumen por variante dentro del EA (diario + criterio OnTester). |
//| El informe completo del SPEC §13 se genera fuera del EA a partir |
//| de trades.csv / signals.csv (Etapa C: tools/analyze_logs.py).     |
//+------------------------------------------------------------------+
#ifndef NBRL_PERF_MQH
#define NBRL_PERF_MQH

#include "Types.mqh"

class CPerformanceAnalyzer
  {
private:
   int      m_n[NBRL_VARIANTS];
   int      m_wins[NBRL_VARIANTS];
   double   m_sumR[NBRL_VARIANTS];
   double   m_gp[NBRL_VARIANTS];
   double   m_gl[NBRL_VARIANTS];
   int      m_streak[NBRL_VARIANTS];
   int      m_maxStreak[NBRL_VARIANTS];

public:
   void     Reset(void)
     {
      for(int i = 0; i < NBRL_VARIANTS; i++)
        {
         m_n[i] = 0; m_wins[i] = 0; m_sumR[i] = 0.0; m_gp[i] = 0.0; m_gl[i] = 0.0;
         m_streak[i] = 0; m_maxStreak[i] = 0;
        }
     }

   void     Add(const int variant, const double net, const double r)
     {
      if(variant < 0 || variant >= NBRL_VARIANTS) return;
      m_n[variant]++;
      m_sumR[variant] += r;
      if(net > 0.0) { m_wins[variant]++; m_gp[variant] += net; m_streak[variant] = 0; }
      else
        {
         m_gl[variant] += -net;
         m_streak[variant]++;
         if(m_streak[variant] > m_maxStreak[variant]) m_maxStreak[variant] = m_streak[variant];
        }
     }

   void     PrintSummary(void) const
     {
      for(int v = 0; v < NBRL_VARIANTS; v++)
        {
         if(m_n[v] == 0) continue;
         double pf = (m_gl[v] > 0.0 ? m_gp[v] / m_gl[v] : 0.0);
         PrintFormat("%s %s: ops=%d aciertos=%.1f%% neto=%.2f PF=%.2f expectativa=%.3fR racha_perdidas=%d",
                     NBRL_NAME, VariantName(v), m_n[v], 100.0 * m_wins[v] / m_n[v],
                     m_gp[v] - m_gl[v], pf, m_sumR[v] / m_n[v], m_maxStreak[v]);
        }
     }

   //--- criterio para la optimizacion: expectativa(R) x sqrt(N); 0 si N < 30
   double   TesterCriterion(void) const
     {
      int n = 0;
      double sr = 0.0;
      for(int v = 0; v < NBRL_VARIANTS; v++) { n += m_n[v]; sr += m_sumR[v]; }
      if(n < 30) return 0.0;
      return (sr / n) * MathSqrt((double)n);
     }
  };

#endif
