//+------------------------------------------------------------------+
//| MarketStructureDetector.mqh                                       |
//| Solo velas cerradas: ATR, swings confirmados, zonas, regimen.    |
//| Reglas: docs/etapa-a/01-documento-tecnico.md §4                   |
//+------------------------------------------------------------------+
#ifndef NBRL_MSD_MQH
#define NBRL_MSD_MQH

#include "Inputs.mqh"
#include "SessionManager.mqh"

#define NBRL_BARS_ENTRY 400
#define NBRL_BARS_CTX   300

//+------------------------------------------------------------------+
//| Marco de precios orientado a la VENTA.                            |
//| dir=DIR_SELL: precios reales. dir=DIR_BUY: precios invertidos     |
//| (h=-low, l=-high, o=-open, c=-close, rsi=100-rsi), de modo que    |
//| la misma logica "de venta" produce la compra espejo exacta.       |
//| Indice 0 = vela abierta (no se usa), 1 = ultima vela cerrada.     |
//+------------------------------------------------------------------+
class CFrame
  {
public:
   int      n;
   int      dir;
   double   o[], h[], l[], c[], rsi[], atr[];
   long     tv[];
   datetime t[];

   void     Build(const MqlRates &r[], const double &rsiSrc[], const double &atrSrc[], const int count, const int d)
     {
      n   = count;
      dir = d;
      ArrayResize(o, n);
      ArrayResize(h, n);
      ArrayResize(l, n);
      ArrayResize(c, n);
      ArrayResize(rsi, n);
      ArrayResize(atr, n);
      ArrayResize(tv, n);
      ArrayResize(t, n);
      for(int i = 0; i < n; i++)
        {
         t[i]   = r[i].time;
         tv[i]  = r[i].tick_volume;
         atr[i] = atrSrc[i];
         if(d == DIR_SELL)
           {
            o[i] = r[i].open;
            h[i] = r[i].high;
            l[i] = r[i].low;
            c[i] = r[i].close;
            rsi[i] = rsiSrc[i];
           }
         else
           {
            o[i] = -r[i].open;
            h[i] = -r[i].low;
            l[i] = -r[i].high;
            c[i] = -r[i].close;
            rsi[i] = 100.0 - rsiSrc[i];
           }
        }
     }

   //--- precio del marco -> precio real
   double   Real(const double x) const { return (dir == DIR_SELL ? x : -x); }
   //--- precio real -> precio del marco
   double   ToFrame(const double x) const { return (dir == DIR_SELL ? x : -x); }
   double   Range(const int i) const { return h[i] - l[i]; }
   double   Body(const int i) const { return MathAbs(c[i] - o[i]); }
  };

//+------------------------------------------------------------------+
//| Swings confirmados con filtro de amplitud (zigzag por ATR).       |
//| Resultado en orden cronologico (el ultimo es el mas reciente).    |
//+------------------------------------------------------------------+
void NBRL_AddSwing(SSwing &out[], const bool isHigh, const int shift, const datetime time,
                   const double price, const double minDist)
  {
   int k = ArraySize(out);
   if(k > 0 && out[k - 1].is_high == isHigh)
     {
      if((isHigh && price > out[k - 1].price) || (!isHigh && price < out[k - 1].price))
        {
         out[k - 1].shift = shift;
         out[k - 1].time  = time;
         out[k - 1].price = price;
        }
      return;
     }
   if(k > 0 && MathAbs(price - out[k - 1].price) < minDist) return;
   ArrayResize(out, k + 1);
   out[k].is_high = isHigh;
   out[k].shift   = shift;
   out[k].time    = time;
   out[k].price   = price;
  }

int NBRL_FindSwings(const double &hi[], const double &lo[], const datetime &t[], const int n,
                    const int strength, const double minDist, SSwing &out[])
  {
   ArrayResize(out, 0);
   //--- un swing en i necesita 'strength' velas cerradas a su derecha (i-k >= 1)
   for(int i = n - 1 - strength; i >= strength + 1; i--)
     {
      bool isH = true, isL = true;
      for(int k = 1; k <= strength; k++)
        {
         if(!(hi[i] > hi[i + k] && hi[i] >= hi[i - k])) isH = false;
         if(!(lo[i] < lo[i + k] && lo[i] <= lo[i - k])) isL = false;
        }
      if(isH) NBRL_AddSwing(out, true, i, t[i], hi[i], minDist);
      if(isL) NBRL_AddSwing(out, false, i, t[i], lo[i], minDist);
     }
   return ArraySize(out);
  }

//+------------------------------------------------------------------+
//| CMarketStructure                                                  |
//+------------------------------------------------------------------+
class CMarketStructure
  {
private:
   string   m_sym;
   int      m_hAtrE, m_hAtrC, m_hAtrC100, m_hRsi;

   void     AddZone(const double price, const datetime time, const string src)
     {
      int k = ArraySize(zones);
      ArrayResize(zones, k + 1);
      zones[k].price   = price;
      zones[k].touches = 1;
      zones[k].time    = time;
      zones[k].source  = src;
     }

   void     MergeZones(void)
     {
      int n = ArraySize(zones);
      //--- ordenar por precio (insercion; pocas zonas)
      for(int i = 1; i < n; i++)
        {
         SZone z = zones[i];
         int j = i - 1;
         while(j >= 0 && zones[j].price > z.price) { zones[j + 1] = zones[j]; j--; }
         zones[j + 1] = z;
        }
      SZone merged[];
      int m = 0;
      for(int i = 0; i < n; i++)
        {
         if(m > 0 && zones[i].price - merged[m - 1].price <= zone_w)
           {
            int t = merged[m - 1].touches;
            merged[m - 1].price   = (merged[m - 1].price * t + zones[i].price) / (t + 1);
            merged[m - 1].touches = t + 1;
            if(zones[i].time < merged[m - 1].time) merged[m - 1].time = zones[i].time;
            merged[m - 1].source += "+" + zones[i].source;
            continue;
           }
         ArrayResize(merged, m + 1);
         merged[m] = zones[i];
         m++;
        }
      ArrayResize(zones, m);
      for(int i = 0; i < m; i++) zones[i] = merged[i];
     }

public:
   MqlRates e[], c[];
   double   atrE[], atrC[], atrC100[], rsiE[];
   int      nE, nC;
   int      digits;
   double   atrE1, atrC1, vr, er, zone_w;
   int      regime;
   bool     high_vol;
   SSwing   swC[];
   SZone    zones[];

            CMarketStructure(void) : m_hAtrE(INVALID_HANDLE), m_hAtrC(INVALID_HANDLE),
                                     m_hAtrC100(INVALID_HANDLE), m_hRsi(INVALID_HANDLE),
                                     nE(0), nC(0), digits(2), atrE1(0.0), atrC1(0.0), vr(1.0), er(0.0),
                                     zone_w(0.0), regime(REGIME_MIXED), high_vol(false) {}

   bool     Init(const string sym)
     {
      m_sym      = sym;
      digits     = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_hAtrE    = iATR(sym, InpTFEntry, InpATRPeriod);
      m_hAtrC    = iATR(sym, InpTFContext, InpATRPeriod);
      m_hAtrC100 = iATR(sym, InpTFContext, 100);
      m_hRsi     = iRSI(sym, InpTFEntry, A_RSIPeriod, PRICE_CLOSE);
      if(m_hAtrE == INVALID_HANDLE || m_hAtrC == INVALID_HANDLE ||
         m_hAtrC100 == INVALID_HANDLE || m_hRsi == INVALID_HANDLE)
        {
         Print(NBRL_NAME, ": no se pudieron crear los indicadores, error ", GetLastError());
         return false;
        }
      ArraySetAsSeries(e, true);
      ArraySetAsSeries(c, true);
      ArraySetAsSeries(atrE, true);
      ArraySetAsSeries(atrC, true);
      ArraySetAsSeries(atrC100, true);
      ArraySetAsSeries(rsiE, true);
      return true;
     }

   void     Deinit(void)
     {
      if(m_hAtrE != INVALID_HANDLE)    IndicatorRelease(m_hAtrE);
      if(m_hAtrC != INVALID_HANDLE)    IndicatorRelease(m_hAtrC);
      if(m_hAtrC100 != INVALID_HANDLE) IndicatorRelease(m_hAtrC100);
      if(m_hRsi != INVALID_HANDLE)     IndicatorRelease(m_hRsi);
     }

   //--- recalcula la foto con velas cerradas; false si faltan datos
   bool     Update(CSessionManager &sess)
     {
      nE = CopyRates(m_sym, InpTFEntry, 0, NBRL_BARS_ENTRY, e);
      nC = CopyRates(m_sym, InpTFContext, 0, NBRL_BARS_CTX, c);
      if(nE < 200 || nC < 150) return false;
      if(CopyBuffer(m_hAtrE, 0, 0, nE, atrE) != nE)       return false;
      if(CopyBuffer(m_hRsi, 0, 0, nE, rsiE) != nE)        return false;
      if(CopyBuffer(m_hAtrC, 0, 0, nC, atrC) != nC)       return false;
      if(CopyBuffer(m_hAtrC100, 0, 0, nC, atrC100) != nC) return false;

      atrE1 = atrE[1];
      atrC1 = atrC[1];
      if(atrE1 <= 0.0 || atrC1 <= 0.0) return false;
      zone_w = ZoneWidthATR * atrC1;

      //--- regimen (etiqueta para metricas)
      vr = (atrC100[1] > 0.0 ? atrC1 / atrC100[1] : 1.0);
      high_vol = (vr >= RegimeHighVolRatio);
      double path = 0.0;
      int p = MathMin(RegimeERPeriod, nC - 3);
      for(int i = 1; i <= p; i++) path += MathAbs(c[i].close - c[i + 1].close);
      er = (path > 0.0 ? MathAbs(c[1].close - c[1 + p].close) / path : 0.0);
      regime = (er >= RegimeTrendER ? REGIME_TREND : (er <= RegimeRangeER ? REGIME_RANGE : REGIME_MIXED));

      //--- swings M15 (marco real)
      double hi[], lo[];
      datetime tt[];
      ArrayResize(hi, nC);
      ArrayResize(lo, nC);
      ArrayResize(tt, nC);
      for(int i = 0; i < nC; i++) { hi[i] = c[i].high; lo[i] = c[i].low; tt[i] = c[i].time; }
      NBRL_FindSwings(hi, lo, tt, nC, SwingStrengthCtx, SwingMinATR * atrC1, swC);

      //--- zonas relevantes
      ArrayResize(zones, 0);
      int lookback = MathMin(ZoneLookbackBars, nC - 1);
      for(int i = 0; i < ArraySize(swC); i++)
         if(swC[i].shift <= lookback)
            AddZone(swC[i].price, swC[i].time, (swC[i].is_high ? "SWH" : "SWL"));

      //--- maximo y minimo del dia de trading anterior
      datetime curKey = sess.TradingDayKey(c[1].time);
      datetime prevKey = 0;
      double pdh = -DBL_MAX, pdl = DBL_MAX;
      datetime pdhT = 0, pdlT = 0;
      for(int i = 1; i < nC; i++)
        {
         datetime k = sess.TradingDayKey(c[i].time);
         if(k >= curKey) continue;
         if(prevKey == 0) prevKey = k;
         if(k < prevKey) break;
         if(c[i].high > pdh) { pdh = c[i].high; pdhT = c[i].time; }
         if(c[i].low < pdl)  { pdl = c[i].low;  pdlT = c[i].time; }
        }
      if(prevKey != 0)
        {
         AddZone(pdh, pdhT, "PDH");
         AddZone(pdl, pdlT, "PDL");
        }

      //--- rango overnight del dia actual, solo desde las 09:30 NY
      int tb = sess.TimeBlock(e[0].time);
      if(tb == TB_NY || tb == TB_POST)
        {
         double onh = -DBL_MAX, onl = DBL_MAX;
         datetime onhT = 0, onlT = 0;
         for(int i = 1; i < nC; i++)
           {
            if(sess.TradingDayKey(c[i].time) != curKey) break;
            int m = sess.NYMinute(c[i].time);
            if(m >= 9 * 60 + 30 && m < 18 * 60) continue;
            if(c[i].high > onh) { onh = c[i].high; onhT = c[i].time; }
            if(c[i].low < onl)  { onl = c[i].low;  onlT = c[i].time; }
           }
         if(onhT > 0) AddZone(onh, onhT, "ONH");
         if(onlT > 0) AddZone(onl, onlT, "ONL");
        }
      MergeZones();
      return true;
     }

   //--- el precio esta en una zona formada antes de 'before'
   bool     InZone(const double price, const datetime before) const
     {
      for(int i = 0; i < ArraySize(zones); i++)
         if(zones[i].time < before && MathAbs(price - zones[i].price) <= zone_w) return true;
      return false;
     }

   //--- borde de la zona opuesta mas cercana en la direccion de la operacion (0 = ninguna)
   double   RoomLevel(const double entry, const int dir) const
     {
      double best = 0.0;
      for(int i = 0; i < ArraySize(zones); i++)
        {
         if(dir == DIR_SELL)
           {
            double edge = zones[i].price + zone_w;
            if(edge < entry && (best == 0.0 || edge > best)) best = edge;
           }
         else
           {
            double edge = zones[i].price - zone_w;
            if(edge > entry && (best == 0.0 || edge < best)) best = edge;
           }
        }
      return best;
     }

   //--- marco de entrada orientado a la direccion indicada
   void     BuildEntryFrame(CFrame &f, const int dir)
     {
      f.Build(e, rsiE, atrE, nE, dir);
     }
  };

#endif
