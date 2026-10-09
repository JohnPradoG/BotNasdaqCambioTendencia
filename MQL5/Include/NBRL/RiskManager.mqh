//+------------------------------------------------------------------+
//| RiskManager.mqh                                                   |
//| Volumen por riesgo, limites diarios, perdidas consecutivas,      |
//| drawdown total y kill switch. Politica exacta:                    |
//| docs/etapa-a/04-riesgos-limitaciones.md §4 y §5                   |
//| Sin martingala, sin grid, sin promediar, sin aumentar riesgo.     |
//+------------------------------------------------------------------+
#ifndef NBRL_RISK_MQH
#define NBRL_RISK_MQH

#include "Inputs.mqh"

class CRiskManager
  {
private:
   string   m_sym;
   long     m_magic;
   string   m_gv;            // prefijo de variables globales
   datetime m_dayKey;
   datetime m_dayStart;      // hora del servidor en que empezo el dia
   double   m_dayRef;
   double   m_cum;           // P/L neto acumulado del EA (cerrado)
   double   m_peak;
   double   m_base0;         // base de referencia para el DD total
   bool     m_kill;
   bool     m_dayBlocked;

   double   GVGet(const string k, const double def) const
     {
      string n = m_gv + k;
      if(GlobalVariableCheck(n)) return GlobalVariableGet(n);
      return def;
     }
   void     GVSet(const string k, const double v) const { GlobalVariableSet(m_gv + k, v); }

   void     Save(void)
     {
      GVSet("dayKey", (double)m_dayKey);
      GVSet("dayStart", (double)m_dayStart);
      GVSet("dayRef", m_dayRef);
      GVSet("cum", m_cum);
      GVSet("peak", m_peak);
      GVSet("base0", m_base0);
      GVSet("kill", m_kill ? 1.0 : 0.0);
      GVSet("dayBlocked", m_dayBlocked ? 1.0 : 0.0);
     }

   bool     OwnDeal(const ulong deal) const
     {
      return (HistoryDealGetInteger(deal, DEAL_MAGIC) == m_magic &&
              HistoryDealGetString(deal, DEAL_SYMBOL) == m_sym);
     }

public:
   string   last_reason;
   string   block_reason;
   //--- estadisticas del dia (DayStats)
   double   realized;
   int      trades_today;
   int      trades_engine[3];
   int      consec_losses;

   bool     Init(const string sym, const long magic)
     {
      m_sym   = sym;
      m_magic = magic;
      m_gv    = NBRL_NAME + "_" + IntegerToString(magic) + "_" + sym + "_";
      m_dayKey     = (datetime)(long)GVGet("dayKey", 0);
      m_dayStart   = (datetime)(long)GVGet("dayStart", 0);
      m_dayRef     = GVGet("dayRef", 0);
      m_cum        = GVGet("cum", 0);
      m_peak       = GVGet("peak", 0);
      m_base0      = GVGet("base0", 0);
      m_kill       = (GVGet("kill", 0) > 0.5);
      m_dayBlocked = (GVGet("dayBlocked", 0) > 0.5);
      if(m_base0 <= 0.0) m_base0 = Base();
      if(ResetKillSwitch && m_kill)
        {
         m_kill = false;
         m_peak = m_cum;
         Print(NBRL_NAME, ": kill switch rearmado manualmente");
        }
      Save();
      return (RiskPerTradePct > 0.0 && RiskPerTradePct <= 2.0 && DailyLossLimitPct > 0.0);
     }

   double   Base(void) const
     {
      if(RiskBase == RISKBASE_FIXED && RiskFixedCapital > 0.0) return RiskFixedCapital;
      if(RiskBase == RISKBASE_BALANCE) return AccountInfoDouble(ACCOUNT_BALANCE);
      return AccountInfoDouble(ACCOUNT_EQUITY);
     }

   bool     KillSwitch(void) const { return m_kill; }
   bool     DayBlocked(void) const { return m_dayBlocked; }
   double   DayRef(void) const { return m_dayRef; }
   double   DayLimitMoney(void) const { return DailyLossLimitPct / 100.0 * m_dayRef; }

   //--- cambio de dia de trading; devuelve true si empezo un dia nuevo
   bool     OnDayCheck(const datetime key, const datetime server)
     {
      if(key == m_dayKey) return false;
      m_dayKey     = key;
      m_dayStart   = server;
      m_dayRef     = Base();
      m_dayBlocked = false;
      block_reason = "";
      Save();
      return true;
     }

   //--- reconstruye el dia desde el historial del magic (fuente de verdad)
   void     DayStats(void)
     {
      realized = 0.0;
      trades_today = 0;
      consec_losses = 0;
      for(int i = 0; i < 3; i++) trades_engine[i] = 0;
      if(m_dayStart <= 0) return;
      if(!HistorySelect(m_dayStart, TimeCurrent() + 60)) return;
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || !OwnDeal(d)) continue;
         double net = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
                      HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_FEE);
         realized += net;
         long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_IN)
           {
            trades_today++;
            string cm = HistoryDealGetString(d, DEAL_COMMENT);
            if(StringFind(cm, "|A") >= 0) trades_engine[0]++;
            else if(StringFind(cm, "|B") >= 0) trades_engine[1]++;
            else if(StringFind(cm, "|C") >= 0) trades_engine[2]++;
           }
         else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
           {
            if(net < 0.0) consec_losses++;
            else consec_losses = 0;
           }
        }
     }

   //--- perdida si todas las posiciones del EA llegan a su SL actual
   double   OpenRisk(void) const
     {
      double risk = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic || PositionGetString(POSITION_SYMBOL) != m_sym) continue;
         double sl = PositionGetDouble(POSITION_SL);
         double vol = PositionGetDouble(POSITION_VOLUME);
         if(sl <= 0.0) { risk += DailyLossLimitPct / 100.0 * m_dayRef; continue; } // sin SL: riesgo maximo
         ENUM_ORDER_TYPE ot = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
         double pl = 0.0;
         if(OrderCalcProfit(ot, m_sym, vol, PositionGetDouble(POSITION_PRICE_OPEN), sl, pl) && pl < 0.0)
            risk += -pl;
         risk += CommissionPerLotRT * vol;
        }
      return risk;
     }

   double   Floating(void) const
     {
      double f = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic || PositionGetString(POSITION_SYMBOL) != m_sym) continue;
         f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      return f;
     }

   //--- volumen redondeado hacia abajo; 0 si no se puede operar
   double   CalcVolume(const int dir, const double entry, const double sl, double &riskMoney)
     {
      last_reason = "";
      riskMoney = RiskPerTradePct / 100.0 * Base();
      ENUM_ORDER_TYPE ot = (dir == DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double pl = 0.0;
      if(!OrderCalcProfit(ot, m_sym, 1.0, entry, sl, pl) || pl >= 0.0)
        { last_reason = "calc_profit_failed"; return 0.0; }
      double loss1 = -pl + CommissionPerLotRT;
      double vmin  = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN);
      double vmax  = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MAX);
      double step  = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_STEP);
      if(step <= 0.0 || loss1 <= 0.0) { last_reason = "bad_symbol_spec"; return 0.0; }
      double vol = MathFloor(riskMoney / loss1 / step + 1e-9) * step;
      if(vol > vmax) vol = MathFloor(vmax / step + 1e-9) * step;
      if(vol < vmin - 1e-12) { last_reason = "min_volume_exceeds_risk"; return 0.0; }
      //--- margen
      double freeM = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double price = (dir == DIR_BUY ? SymbolInfoDouble(m_sym, SYMBOL_ASK) : SymbolInfoDouble(m_sym, SYMBOL_BID));
      while(vol >= vmin - 1e-12)
        {
         double margin = 0.0;
         if(!OrderCalcMargin(ot, m_sym, vol, price, margin)) { last_reason = "calc_margin_failed"; return 0.0; }
         if(margin <= MaxMarginUsePct / 100.0 * freeM) break;
         vol -= step;
        }
      if(vol < vmin - 1e-12) { last_reason = "margin"; return 0.0; }
      int volDigits = (int)MathMax(0, MathCeil(-MathLog10(step)));
      vol = NormalizeDouble(vol, volDigits);
      riskMoney = vol * loss1;   // riesgo real previsto con el volumen final
      return vol;
     }

   //--- puertas de riesgo para una nueva entrada (variant = ENUM_NBRL_VARIANT)
   bool     AllowEntry(const double riskNew, const int variant)
     {
      last_reason = "";
      if(m_kill)       { last_reason = "kill_switch"; return false; }
      if(m_dayBlocked) { last_reason = "day_blocked:" + block_reason; return false; }
      DayStats();
      if(trades_today >= MaxTradesPerDay) { last_reason = "max_trades_day"; return false; }
      if(trades_engine[EngineIndex(variant)] >= MaxTradesPerEnginePerDay) { last_reason = "max_trades_engine"; return false; }
      if(consec_losses >= MaxConsecLosses) { last_reason = "max_consec_losses"; return false; }
      double used = MathMax(0.0, -realized) + OpenRisk();
      if(used + riskNew > DayLimitMoney() + 1e-9) { last_reason = "daily_loss_budget"; return false; }
      return true;
     }

   //--- registra un cierre (P/L neto) para el DD total
   void     OnClosed(const double net)
     {
      m_cum += net;
      if(m_cum > m_peak) m_peak = m_cum;
      Save();
     }

   //--- comprobaciones en cada tick. Devuelve true si hay que cerrar todo.
   bool     CheckLimits(string &why)
     {
      why = "";
      double fl = Floating();
      //--- drawdown total del EA
      double dd = m_peak - (m_cum + fl);
      if(!m_kill && m_base0 > 0.0 && dd >= MaxTotalDDPct / 100.0 * m_base0)
        {
         m_kill = true;
         Save();
         why = StringFormat("kill_switch: DD %.2f >= %.2f%%", dd, MaxTotalDDPct);
         return true;
        }
      //--- corte duro diario
      //--- 'realized' y 'consec_losses' se refrescan con DayStats() en cada
      //--- vela nueva y tras cada cierre (no en cada tick, por rendimiento)
      if(!m_dayBlocked && m_dayRef > 0.0)
        {
         if(realized + fl <= -DayLimitMoney())
           {
            m_dayBlocked = true;
            block_reason = "daily_loss_limit";
            Save();
            why = StringFormat("daily_loss_limit: %.2f", realized + fl);
            return (DailyLimitAction == DAILY_BLOCK_CLOSE_ALL);
           }
         if(consec_losses >= MaxConsecLosses)
           {
            m_dayBlocked = true;
            block_reason = "max_consec_losses";
            Save();
            why = "max_consec_losses";
            return false;
           }
        }
      return false;
     }

   double   DDPct(void) const
     {
      if(m_base0 <= 0.0) return 0.0;
      return (m_peak - (m_cum + Floating())) / m_base0 * 100.0;
     }
  };

#endif
