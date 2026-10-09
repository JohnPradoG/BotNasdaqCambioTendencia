//+------------------------------------------------------------------+
//| PositionManager.mqh                                               |
//| Gestion de la posicion propia: MFE/MAE, salidas configurables y  |
//| registro del cierre. El SL nunca se aleja.                        |
//| Salidas: docs/etapa-a/02-reglas-motores.md §D                     |
//| v0.1: TP en R (en la orden), cierre por sesion, break-even,       |
//| trailing ATR y tiempo maximo. Trailing por estructura, cierre     |
//| parcial y salida por invalidacion quedan para una version         |
//| posterior (desactivados en la configuracion base de todos modos). |
//+------------------------------------------------------------------+
#ifndef NBRL_POSITION_MQH
#define NBRL_POSITION_MQH

#include "Inputs.mqh"
#include "SessionManager.mqh"
#include "SafetyController.mqh"
#include "RiskManager.mqh"
#include "TradeLogger.mqh"
#include "PerformanceAnalyzer.mqh"

struct SPosInfo
  {
   bool     active;
   ulong    ticket;
   long     pos_id;
   string   sid;
   int      variant;
   int      dir;
   string   type;
   string   structure;
   string   reasons;
   double   entry_ref;
   double   entry;
   double   slippage_pts;
   double   sl0;
   double   tp0;
   double   r_dist;
   double   risk_money;
   double   vol;
   double   spread_pts;
   double   atr_entry;
   int      regime;
   int      block;
   datetime open_time;
   datetime open_ny;
   double   mfe;          // excursion favorable maxima (precio)
   double   mae;          // excursion adversa maxima (precio)
   bool     be_done;
   int      mods;
  };

class CPositionManager
  {
private:
   SPosInfo m_p;
   string   m_sym;
   long     m_magic;
   string   m_gv;
   string   m_exitReason;    // motivo cuando cierra el propio EA

   string   Key(const string k) const { return m_gv + "pos" + IntegerToString(m_p.pos_id) + "_" + k; }

   void     SavePos(void) const
     {
      GlobalVariableSet(Key("sl0"), m_p.sl0);
      GlobalVariableSet(Key("r"), m_p.r_dist);
      GlobalVariableSet(Key("risk"), m_p.risk_money);
      GlobalVariableSet(Key("var"), m_p.variant);
      GlobalVariableSet(Key("ref"), m_p.entry_ref);
      GlobalVariableSet(Key("mfe"), m_p.mfe);
      GlobalVariableSet(Key("mae"), m_p.mae);
     }

   void     DeletePos(void) const
     {
      GlobalVariablesDeleteAll(m_gv + "pos" + IntegerToString(m_p.pos_id) + "_");
     }

public:
   string   last_event;

   void     Init(const string sym, const long magic)
     {
      m_sym   = sym;
      m_magic = magic;
      m_gv    = NBRL_NAME + "_" + IntegerToString(magic) + "_" + sym + "_";
      m_p.active = false;
     }

   bool     Active(void) const { return m_p.active; }
   int      ActiveVariant(void) const { return (m_p.active ? m_p.variant : -1); }

   void     OnOpened(const SSignal &s, const ulong ticket, const double reqPrice, const double fill,
                     const double sl, const double tp, const double vol, const double risk,
                     const double spreadPts, const int block, const datetime server, const datetime ny)
     {
      double pt = SymbolInfoDouble(m_sym, SYMBOL_POINT);
      m_p.active      = true;
      m_p.ticket      = ticket;
      m_p.pos_id      = (PositionSelectByTicket(ticket) ? PositionGetInteger(POSITION_IDENTIFIER) : (long)ticket);
      m_p.sid         = s.id;
      m_p.variant     = s.variant;
      m_p.dir         = s.dir;
      m_p.type        = s.type;
      m_p.structure   = s.structure_id;
      m_p.reasons     = s.reasons;
      m_p.entry_ref   = s.entry_ref;
      m_p.entry       = fill;
      m_p.slippage_pts= (pt > 0.0 ? (s.dir == DIR_BUY ? fill - reqPrice : reqPrice - fill) / pt : 0.0);
      m_p.sl0         = sl;
      m_p.tp0         = tp;
      m_p.r_dist      = MathAbs(fill - sl);
      m_p.risk_money  = risk;
      m_p.vol         = vol;
      m_p.spread_pts  = spreadPts;
      m_p.atr_entry   = s.atr_entry;
      m_p.regime      = s.regime;
      m_p.block       = block;
      m_p.open_time   = server;
      m_p.open_ny     = ny;
      m_p.mfe         = 0.0;
      m_p.mae         = 0.0;
      m_p.be_done     = false;
      m_p.mods        = 0;
      m_exitReason    = "";
      SavePos();
     }

   //--- readopta una posicion propia tras reiniciar (sin datos de la senal)
   void     Adopt(const ulong ticket)
     {
      if(!PositionSelectByTicket(ticket)) return;
      m_p.active     = true;
      m_p.ticket     = ticket;
      m_p.pos_id     = PositionGetInteger(POSITION_IDENTIFIER);
      m_p.dir        = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? DIR_BUY : DIR_SELL);
      m_p.entry      = PositionGetDouble(POSITION_PRICE_OPEN);
      m_p.vol        = PositionGetDouble(POSITION_VOLUME);
      m_p.tp0        = PositionGetDouble(POSITION_TP);
      m_p.open_time  = (datetime)PositionGetInteger(POSITION_TIME);
      m_p.open_ny    = 0;
      string cm      = PositionGetString(POSITION_COMMENT);
      m_p.sid        = cm;
      m_p.type       = "ADOPTED";
      m_p.structure  = "";
      m_p.reasons    = "restart";
      m_p.slippage_pts = 0.0;
      m_p.spread_pts = 0.0;
      m_p.atr_entry  = 0.0;
      m_p.regime     = REGIME_MIXED;
      m_p.block      = -1;
      m_p.be_done    = false;
      m_p.mods       = 0;
      double cur     = PositionGetDouble(POSITION_SL);
      m_p.sl0        = (GlobalVariableCheck(Key("sl0")) ? GlobalVariableGet(Key("sl0")) : cur);
      m_p.r_dist     = (GlobalVariableCheck(Key("r")) ? GlobalVariableGet(Key("r")) : MathAbs(m_p.entry - cur));
      m_p.risk_money = (GlobalVariableCheck(Key("risk")) ? GlobalVariableGet(Key("risk")) : 0.0);
      m_p.variant    = (GlobalVariableCheck(Key("var")) ? (int)GlobalVariableGet(Key("var")) : -1);
      m_p.entry_ref  = (GlobalVariableCheck(Key("ref")) ? GlobalVariableGet(Key("ref")) : m_p.entry);
      m_p.mfe        = (GlobalVariableCheck(Key("mfe")) ? GlobalVariableGet(Key("mfe")) : 0.0);
      m_p.mae        = (GlobalVariableCheck(Key("mae")) ? GlobalVariableGet(Key("mae")) : 0.0);
      m_exitReason   = "";
      last_event     = "adopted ticket=" + IntegerToString((long)ticket) + " comment=" + cm;
     }

   //--- en cada tick. atrE = ATR del TF de entrada de la ultima vela cerrada
   void     OnTick(CSessionManager &sess, CSafetyController &safety, CRiskManager &risk,
                   CTradeLogger &log, CPerformanceAnalyzer &perf, const double atrE,
                   const bool forceClose, const string forceWhy)
     {
      if(!m_p.active) return;
      datetime now = TimeCurrent();
      if(!PositionSelectByTicket(m_p.ticket))
        {
         Finalize(sess, risk, log, perf);
         return;
        }
      double bid = SymbolInfoDouble(m_sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_sym, SYMBOL_ASK);
      double fav = (m_p.dir == DIR_BUY ? bid - m_p.entry : m_p.entry - ask);
      double adv = -fav;
      if(fav > m_p.mfe) m_p.mfe = fav;
      if(adv > m_p.mae) m_p.mae = adv;

      //--- cierre forzado (politica de sesion o limite de riesgo)
      if(forceClose)
        {
         m_exitReason = forceWhy;
         if(!safety.Close(m_p.ticket))
            log.Event(now, sess.ServerToNY(now), m_sym, m_magic, "ERROR", "close_failed " + safety.last_error);
         return;
        }

      //--- tiempo maximo
      if(X_MaxBars && now - m_p.open_time >= (long)X_MaxBarsEntry * PeriodSeconds(InpTFEntry))
        {
         m_exitReason = "max_time";
         if(!safety.Close(m_p.ticket))
            log.Event(now, sess.ServerToNY(now), m_sym, m_magic, "ERROR", "close_failed " + safety.last_error);
         return;
        }

      if(m_p.r_dist <= 0.0) return;
      double curSL = PositionGetDouble(POSITION_SL);
      double newSL = 0.0;

      //--- break-even: entrada + spread de apertura como estimacion de costes
      if(X_BE && !m_p.be_done && m_p.mfe >= X_BETriggerR * m_p.r_dist)
        {
         double pt = SymbolInfoDouble(m_sym, SYMBOL_POINT);
         double cost = m_p.spread_pts * pt;
         newSL = (m_p.dir == DIR_BUY ? m_p.entry + cost : m_p.entry - cost);
         m_p.be_done = true;
        }
      //--- trailing ATR
      if(X_TrailATR && atrE > 0.0 && m_p.mfe >= X_TrailStartR * m_p.r_dist)
        {
         double best = (m_p.dir == DIR_BUY ? m_p.entry + m_p.mfe : m_p.entry - m_p.mfe);
         double tr = (m_p.dir == DIR_BUY ? best - X_TrailATRMult * atrE : best + X_TrailATRMult * atrE);
         if(newSL == 0.0 || (m_p.dir == DIR_BUY ? tr > newSL : tr < newSL)) newSL = tr;
        }
      if(newSL != 0.0)
        {
         newSL = NormalizePrice(m_sym, newSL);
         bool better = (curSL <= 0.0) || (m_p.dir == DIR_BUY ? newSL > curSL : newSL < curSL);
         if(better)
           {
            int dg = (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS);
            if(safety.ModifySL(m_p.ticket, newSL))
              {
               m_p.mods++;
               log.Event(now, sess.ServerToNY(now), m_sym, m_magic, "MODIFY",
                         StringFormat("%s ticket=%I64u sl %s -> %s mfe=%.2fR", m_p.sid, m_p.ticket,
                                      DoubleToString(curSL, dg), DoubleToString(newSL, dg),
                                      m_p.mfe / m_p.r_dist));
              }
            else if(safety.last_error != "sl_not_better" && safety.last_error != "stops_level")
               log.Event(now, sess.ServerToNY(now), m_sym, m_magic, "ERROR", "modify_failed " + safety.last_error);
           }
        }
     }

   //--- la posicion ya no existe: registrar el resultado real del servidor
   void     Finalize(CSessionManager &sess, CRiskManager &risk, CTradeLogger &log, CPerformanceAnalyzer &perf)
     {
      double profit = 0.0, comm = 0.0, swap = 0.0, exitPrice = 0.0;
      datetime exitTime = 0;
      long reason = -1;
      if(HistorySelectByPosition(m_p.pos_id))
        {
         int n = HistoryDealsTotal();
         for(int i = 0; i < n; i++)
           {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0) continue;
            profit += HistoryDealGetDouble(d, DEAL_PROFIT);
            comm   += HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
            swap   += HistoryDealGetDouble(d, DEAL_SWAP);
            long en = HistoryDealGetInteger(d, DEAL_ENTRY);
            if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY)
              {
               exitPrice = HistoryDealGetDouble(d, DEAL_PRICE);
               exitTime  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
               reason    = HistoryDealGetInteger(d, DEAL_REASON);
              }
           }
        }
      string why = m_exitReason;
      if(why == "")
        {
         if(reason == DEAL_REASON_SL)      why = (m_p.mods > 0 ? "SL_moved" : "SL");
         else if(reason == DEAL_REASON_TP) why = "TP";
         else if(reason == DEAL_REASON_SO) why = "stop_out";
         else if(reason == DEAL_REASON_CLIENT || reason == DEAL_REASON_MOBILE || reason == DEAL_REASON_WEB) why = "manual";
         else why = "other_" + IntegerToString(reason);
        }
      double net = profit + comm + swap;
      double rRes = (m_p.risk_money > 0.0 ? net / m_p.risk_money : 0.0);
      double pt = SymbolInfoDouble(m_sym, SYMBOL_POINT);
      double mfeR = (m_p.r_dist > 0.0 ? m_p.mfe / m_p.r_dist : 0.0);
      double maeR = (m_p.r_dist > 0.0 ? m_p.mae / m_p.r_dist : 0.0);
      int dg = (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS);
      if(exitTime == 0) exitTime = TimeCurrent();
      string v = (m_p.variant >= 0 ? VariantName(m_p.variant) : "?");
      string line = m_p.sid + ";" + IntegerToString(m_p.pos_id) + ";" + m_sym + ";" + IntegerToString(m_magic) + ";" +
                    (m_p.variant >= 0 ? EngineName(m_p.variant) : "?") + ";" + v + ";" + DirName(m_p.dir) + ";" +
                    EnumToString(InpTFContext) + ";" + EnumToString(InpTFEntry) + ";" + m_p.type + ";" +
                    CTradeLogger::Clean(m_p.structure) + ";" +
                    TimeToString(m_p.open_time, TIME_DATE | TIME_SECONDS) + ";" +
                    (m_p.open_ny > 0 ? TimeToString(m_p.open_ny, TIME_DATE | TIME_SECONDS) : "") + ";" +
                    DoubleToString(m_p.entry_ref, dg) + ";" + DoubleToString(m_p.entry, dg) + ";" +
                    DoubleToString(m_p.slippage_pts, 1) + ";" + DoubleToString(m_p.sl0, dg) + ";" +
                    DoubleToString(m_p.tp0, dg) + ";" + DoubleToString(m_p.vol, 2) + ";" +
                    DoubleToString(m_p.risk_money, 2) + ";" + DoubleToString(m_p.spread_pts, 1) + ";" +
                    DoubleToString(m_p.atr_entry, dg) + ";" + RegimeName(m_p.regime) + ";" +
                    (m_p.block >= 0 ? TimeBlockName(m_p.block) : "") + ";" + CTradeLogger::Clean(m_p.reasons) + ";" +
                    TimeToString(exitTime, TIME_DATE | TIME_SECONDS) + ";" +
                    TimeToString(sess.ServerToNY(exitTime), TIME_DATE | TIME_SECONDS) + ";" +
                    DoubleToString(exitPrice, dg) + ";" + why + ";" +
                    DoubleToString(comm, 2) + ";" + DoubleToString(swap, 2) + ";" + DoubleToString(profit, 2) + ";" +
                    DoubleToString(net, 2) + ";" + DoubleToString(rRes, 3) + ";" +
                    DoubleToString(mfeR, 3) + ";" + DoubleToString(maeR, 3) + ";" +
                    DoubleToString(pt > 0.0 ? m_p.mfe / pt : 0.0, 1) + ";" +
                    DoubleToString(pt > 0.0 ? m_p.mae / pt : 0.0, 1) + ";" +
                    IntegerToString((long)(exitTime - m_p.open_time) / 60) + ";" + IntegerToString(m_p.mods);
      log.Trade(line);
      log.Event(exitTime, sess.ServerToNY(exitTime), m_sym, m_magic, "EXIT",
                StringFormat("%s %s net=%.2f R=%.2f reason=%s", m_p.sid, DirName(m_p.dir), net, rRes, why));
      risk.OnClosed(net);
      risk.DayStats();
      perf.Add(m_p.variant, net, rRes);
      DeletePos();
      m_p.active = false;
     }
  };

#endif
