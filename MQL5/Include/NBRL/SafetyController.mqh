//+------------------------------------------------------------------+
//| SafetyController.mqh                                              |
//| Validacion del simbolo, validacion previa a la orden, envio con  |
//| reintentos limitados, verificacion de la posicion real y         |
//| proteccion contra solicitudes repetidas.                         |
//| Politica: docs/etapa-a/04-riesgos-limitaciones.md §6              |
//+------------------------------------------------------------------+
#ifndef NBRL_SAFETY_MQH
#define NBRL_SAFETY_MQH

#include <Trade\Trade.mqh>
#include "Inputs.mqh"
#include "Logic.mqh"

class CSafetyController
  {
private:
   CTrade   m_trade;
   string   m_sym;
   long     m_magic;
   bool     m_busy;
   bool     m_tester;

   bool     Recoverable(const uint rc) const
     {
      return (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
              rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_CONNECTION ||
              rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_TOO_MANY_REQUESTS);
     }

   void     Pause(const int ms) const { if(!m_tester && ms > 0) Sleep(ms); }

public:
   string   last_error;

            CSafetyController(void) : m_busy(false), m_tester(false) {}

   //--- detecta y valida el simbolo (doc. tecnico §6)
   bool     ValidateSymbol(const string sym, string &info)
     {
      m_sym = sym;
      m_tester = (bool)MQLInfoInteger(MQL_TESTER);
      if(!SymbolSelect(sym, true)) { info = "simbolo no disponible: " + sym; return false; }
      string desc = SymbolInfoString(sym, SYMBOL_DESCRIPTION);
      string path = SymbolInfoString(sym, SYMBOL_PATH);
      string hay = sym + " " + desc + " " + path;
      StringToUpper(hay);
      bool match = false;
      string kw[];
      int n = StringSplit(InpSymbolKeywords, ',', kw);
      for(int i = 0; i < n && !match; i++)
        {
         string k = kw[i];
         StringTrimLeft(k);
         StringTrimRight(k);
         StringToUpper(k);
         if(k != "" && StringFind(hay, k) >= 0) match = true;
        }
      long tm = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
      info = StringFormat("symbol=%s desc='%s' path='%s' digits=%d point=%s tick_size=%s tick_value=%s "
                          "contract=%s vol_min=%s vol_max=%s vol_step=%s stops_level=%d freeze_level=%d "
                          "filling=%d exec=%d trade_mode=%d profit_ccy=%s spread=%d",
                          sym, desc, path, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_POINT), 8),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE), 8),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE), 6),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE), 4),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN), 4),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX), 4),
                          DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP), 4),
                          (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL),
                          (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL),
                          (int)SymbolInfoInteger(sym, SYMBOL_FILLING_MODE),
                          (int)SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE), (int)tm,
                          SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT),
                          (int)SymbolInfoInteger(sym, SYMBOL_SPREAD));
      if(!match && !InpAllowUnverifiedSymbol) { info = "no parece Nasdaq 100: " + info; return false; }
      if(tm != SYMBOL_TRADE_MODE_FULL && !InpAnalysisOnly) { info = "el simbolo no permite operar en ambas direcciones: " + info; return false; }
      return true;
     }

   void     Init(const long magic)
     {
      m_magic = magic;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetTypeFillingBySymbol(m_sym);
      m_trade.SetMarginMode();
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
     }

   //--- hay posicion u orden propia en el simbolo
   bool     HasOwnExposure(void) const
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t != 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == m_sym)
            return true;
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t != 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == m_sym)
            return true;
        }
      return false;
     }

   ulong    FindOwnPosition(void) const
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t != 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == m_sym)
            return t;
        }
      return 0;
     }

   //--- distancia minima permitida por el broker para SL/TP (precio)
   double   MinStopDistance(void) const
     {
      double pt = SymbolInfoDouble(m_sym, SYMBOL_POINT);
      long a = SymbolInfoInteger(m_sym, SYMBOL_TRADE_STOPS_LEVEL);
      long b = SymbolInfoInteger(m_sym, SYMBOL_TRADE_FREEZE_LEVEL);
      long lvl = (a > b ? a : b);
      return (double)lvl * pt;
     }

   //--- abre a mercado con SL y TP en la misma solicitud
   bool     Open(const int dir, const double vol, const double sl, const double tp, const string comment,
                 ulong &ticket, double &fillPrice)
     {
      last_error = "";
      ticket = 0;
      fillPrice = 0.0;
      if(m_busy)            { last_error = "request_in_progress"; return false; }
      if(HasOwnExposure())  { last_error = "position_open"; return false; }
      double bid = SymbolInfoDouble(m_sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_sym, SYMBOL_ASK);
      double price = (dir == DIR_BUY ? ask : bid);
      double minD = MinStopDistance();
      if(sl <= 0.0)                              { last_error = "no_stop_loss"; return false; }
      if(MathAbs(price - sl) < minD)             { last_error = "invalid_stops_level"; return false; }
      if(tp > 0.0 && MathAbs(tp - price) < minD) { last_error = "invalid_tp_level"; return false; }
      if((dir == DIR_BUY && sl >= bid) || (dir == DIR_SELL && sl <= ask)) { last_error = "sl_wrong_side"; return false; }

      int dev = MaxSlippagePoints;
      if(dev <= 0) dev = (int)MathMax(10, 10 * SymbolInfoInteger(m_sym, SYMBOL_SPREAD));
      m_trade.SetDeviationInPoints((ulong)dev);

      m_busy = true;
      uint rc = 0;
      for(int attempt = 0; attempt <= MaxOrderRetries; attempt++)
        {
         if(attempt > 0)
           {
            if(HasOwnExposure()) break;          // la orden anterior si se ejecuto
            Pause(RetryDelayMs);
           }
         bool sent;
         if(dir == DIR_BUY) sent = m_trade.Buy(vol, m_sym, 0.0, sl, tp, comment);
         else               sent = m_trade.Sell(vol, m_sym, 0.0, sl, tp, comment);
         rc = m_trade.ResultRetcode();
         if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED)) break;
         last_error = StringFormat("retcode=%u %s", rc, m_trade.ResultRetcodeDescription());
         if(!Recoverable(rc)) break;
        }
      //--- verificar la posicion real (no se da por ejecutada sin verla)
      for(int k = 0; k < 10 && ticket == 0; k++)
        {
         ticket = FindOwnPosition();
         if(ticket == 0) Pause(100);
        }
      m_busy = false;
      if(ticket == 0)
        {
         if(last_error == "") last_error = StringFormat("not_confirmed retcode=%u", rc);
         return false;
        }
      if(!PositionSelectByTicket(ticket)) { last_error = "not_confirmed_select"; return false; }
      fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      if(PositionGetDouble(POSITION_SL) <= 0.0)
        {
         //--- el servidor no acepto el SL: se intenta ponerlo y, si no, se cierra
         if(!m_trade.PositionModify(ticket, sl, tp))
           {
            m_trade.PositionClose(ticket);
            last_error = "sl_not_accepted_closed";
            ticket = 0;
            return false;
           }
        }
      last_error = "";
      return true;
     }

   //--- modifica el SL; nunca lo aleja (comprobacion final de seguridad)
   bool     ModifySL(const ulong ticket, const double newSL)
     {
      last_error = "";
      if(!PositionSelectByTicket(ticket)) { last_error = "no_position"; return false; }
      long type = PositionGetInteger(POSITION_TYPE);
      double cur = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);
      double pt  = SymbolInfoDouble(m_sym, SYMBOL_POINT);
      double bid = SymbolInfoDouble(m_sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_sym, SYMBOL_ASK);
      double minD = MinStopDistance();
      if(type == POSITION_TYPE_BUY)
        {
         if(!NBRL_SLIsBetter(true, cur, newSL, pt))  { last_error = "sl_not_better"; return false; }
         if(bid - newSL < minD)                   { last_error = "stops_level"; return false; }
        }
      else
        {
         if(!NBRL_SLIsBetter(false, cur, newSL, pt)) { last_error = "sl_not_better"; return false; }
         if(newSL - ask < minD)                   { last_error = "stops_level"; return false; }
        }
      if(!m_trade.PositionModify(ticket, newSL, tp))
        {
         last_error = StringFormat("modify retcode=%u %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         return false;
        }
      return true;
     }

   bool     ClosePartial(const ulong ticket, const double vol)
     {
      last_error = "";
      if(!PositionSelectByTicket(ticket)) { last_error = "no_position"; return false; }
      if(m_trade.PositionClosePartial(ticket, vol))
        {
         uint rc = m_trade.ResultRetcode();
         if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED) return true;
        }
      last_error = StringFormat("partial retcode=%u %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
      return false;
     }

   bool     Close(const ulong ticket)
     {
      last_error = "";
      for(int attempt = 0; attempt <= MaxOrderRetries; attempt++)
        {
         if(!PositionSelectByTicket(ticket)) return true;
         if(m_trade.PositionClose(ticket))
           {
            uint rc = m_trade.ResultRetcode();
            if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED) return true;
           }
         last_error = StringFormat("close retcode=%u %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         if(!Recoverable(m_trade.ResultRetcode())) return false;
         Pause(RetryDelayMs);
        }
      return false;
     }
  };

#endif
