//+------------------------------------------------------------------+
//| NBRL_RSI2_Daily.mq5                                               |
//| RSI-2 diario, SOLO COMPRAS, para prueba hacia adelante en DEMO.   |
//| Regla exacta validada en Python (docs/etapa-e/resultados-rsi2-*): |
//|   compra al cierre del dia si cierre > SMA200 y RSI(2) < 10;      |
//|   sale cuando el cierre supera la SMA5; stop 2 ATR(14) diario.    |
//| Sin cortos, sin martingala, una posicion por simbolo.             |
//| Desviacion respecto al estudio: usa las velas D1 del broker       |
//| (cierre 00:00 servidor), el estudio usaba el cierre del dia NY.   |
//| Un grafico por simbolo (US500m, US30m, JP225m, USTECm), D1.       |
//| Experimental, sin resultados validados con dinero real.           |
//+------------------------------------------------------------------+
#property copyright "NBRL"
#property version   "1.00"
#property description "RSI-2 diario solo compras (demo, experimental)"

#include <Trade\Trade.mqh>

input long   InpMagic      = 26101501;  // Magic (distinto del EA NBRL)
input double InpRiskPct    = 0.25;      // Riesgo por operacion (% del equity)
input int    InpSMALong    = 200;       // SMA de tendencia
input int    InpSMAExit    = 5;         // SMA de salida
input int    InpRSIPeriod  = 2;         // Periodo RSI
input double InpRSIBuy     = 10.0;      // Compra si RSI menor que
input int    InpATRPeriod  = 14;        // Periodo ATR
input double InpStopATR    = 2.0;       // Stop en multiplos de ATR
input bool   InpAllowReal  = false;     // Permitir cuenta real (NO activar sin validacion)
input int    InpSlippagePts = 0;        // Desviacion maxima en puntos (0 = 10 x spread)
input int    InpEntryWindowMin = 60;    // Solo entrar en los primeros N minutos de la vela diaria

CTrade   g_trade;
int      g_hSmaL = INVALID_HANDLE, g_hSmaE = INVALID_HANDLE, g_hRsi = INVALID_HANDLE, g_hAtr = INVALID_HANDLE;
datetime g_lastBar = 0;

//+------------------------------------------------------------------+
bool GetVal(const int handle, const int shift, double &v)
  {
   double b[];
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return false;
   v = b[0];
   return (v != EMPTY_VALUE && MathIsValidNumber(v));
  }

ulong OwnPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic) return t;
     }
   return 0;
  }

//--- volumen para arriesgar InpRiskPct del equity hasta el stop, siempre hacia abajo
double CalcVolume(const double entry, const double sl)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPct / 100.0;
   double profit = 0.0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, entry, sl, profit) || profit >= 0.0) return 0.0;
   double lossPerLot = -profit;
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lossPerLot <= 0.0 || vstep <= 0.0) return 0.0;
   double vol = MathFloor(riskMoney / lossPerLot / vstep + 1e-9) * vstep;
   if(vol < vmin) return 0.0;           // el minimo del simbolo supera el riesgo: no operar
   return MathMin(vol, vmax);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(Period() != PERIOD_D1)
     { Print("NBRL_RSI2_Daily: usar el grafico D1"); return INIT_PARAMETERS_INCORRECT; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpAllowReal)
     { Print("NBRL_RSI2_Daily: cuenta real bloqueada (InpAllowReal=false)"); return INIT_FAILED; }
   g_hSmaL = iMA(_Symbol, PERIOD_D1, InpSMALong, 0, MODE_SMA, PRICE_CLOSE);
   g_hSmaE = iMA(_Symbol, PERIOD_D1, InpSMAExit, 0, MODE_SMA, PRICE_CLOSE);
   g_hRsi  = iRSI(_Symbol, PERIOD_D1, InpRSIPeriod, PRICE_CLOSE);
   g_hAtr  = iATR(_Symbol, PERIOD_D1, InpATRPeriod);
   if(g_hSmaL == INVALID_HANDLE || g_hSmaE == INVALID_HANDLE || g_hRsi == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
     { Print("NBRL_RSI2_Daily: no se pudieron crear los indicadores"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   PrintFormat("NBRL_RSI2_Daily iniciado en %s: riesgo %.2f%%, SMA%d, RSI%d<%.0f, salida SMA%d, stop %.1f ATR",
               _Symbol, InpRiskPct, InpSMALong, InpRSIPeriod, InpRSIBuy, InpSMAExit, InpStopATR);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_hSmaL != INVALID_HANDLE) IndicatorRelease(g_hSmaL);
   if(g_hSmaE != INVALID_HANDLE) IndicatorRelease(g_hSmaE);
   if(g_hRsi  != INVALID_HANDLE) IndicatorRelease(g_hRsi);
   if(g_hAtr  != INVALID_HANDLE) IndicatorRelease(g_hAtr);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime bar = iTime(_Symbol, PERIOD_D1, 0);
   if(bar == 0) return;
   ulong pos = OwnPosition();
   //--- salida: se reintenta en cada tick mientras la posicion exista y el cierre diario supere la SMA5
   if(pos != 0)
     {
      if(!PositionSelectByTicket(pos) || (datetime)PositionGetInteger(POSITION_TIME) >= bar) return;   // abierta hoy: la salida se evalua desde manana
      double smaE1, close1e = iClose(_Symbol, PERIOD_D1, 1);
      if(!GetVal(g_hSmaE, 1, smaE1) || close1e <= 0.0) return;
      if(close1e > smaE1)
        {
         if(g_trade.PositionClose(pos))
            PrintFormat("RSI2 salida %s: cierre %.2f > SMA%d %.2f", _Symbol, close1e, InpSMAExit, smaE1);
         else
            PrintFormat("RSI2 error al cerrar %s: %d %s", _Symbol, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
        }
      g_lastBar = bar;
      return;
     }
   //--- entrada: una sola evaluacion por vela diaria
   if(bar == g_lastBar) return;
   g_lastBar = bar;
   if(TimeCurrent() - bar > (datetime)(InpEntryWindowMin * 60))
     { PrintFormat("RSI2 %s: fuera de la ventana de entrada, vela omitida", _Symbol); return; }
   double smaL, rsi, atr;
   if(!GetVal(g_hSmaL, 1, smaL) || !GetVal(g_hRsi, 1, rsi) || !GetVal(g_hAtr, 1, atr)) { g_lastBar = 0; return; }
   double close1 = iClose(_Symbol, PERIOD_D1, 1);
   if(close1 <= 0.0 || atr <= 0.0) { g_lastBar = 0; return; }

   if(!(close1 > smaL && rsi < InpRSIBuy)) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0) return;
   double sl = ask - InpStopATR * atr;
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(tick > 0.0) sl = MathFloor(sl / tick) * tick;            // stop redondeado hacia abajo (mas lejos)
   sl = NormalizeDouble(sl, digits);
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask - sl < minStop) { PrintFormat("RSI2 %s: stop demasiado cerca del minimo del broker", _Symbol); return; }
   double vol = CalcVolume(ask, sl);
   if(vol <= 0.0) { PrintFormat("RSI2 %s: senal omitida, el lote minimo supera el riesgo %.2f%%", _Symbol, InpRiskPct); return; }
   double spread = ask - bid;
   int dev = (InpSlippagePts > 0 ? InpSlippagePts : (int)MathMax(10.0, 10.0 * spread / SymbolInfoDouble(_Symbol, SYMBOL_POINT)));
   g_trade.SetDeviationInPoints(dev);
   if(g_trade.Buy(vol, _Symbol, 0.0, sl, 0.0, "NBRL_RSI2"))
      PrintFormat("RSI2 compra %s vol=%.2f sl=%.2f rsi=%.1f cierre=%.2f sma200=%.2f atr=%.2f spread=%.2f",
                  _Symbol, vol, sl, rsi, close1, smaL, atr, spread);
   else
      PrintFormat("RSI2 error al comprar %s: %d %s", _Symbol, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
  }
//+------------------------------------------------------------------+
