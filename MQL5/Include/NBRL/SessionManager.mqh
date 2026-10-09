//+------------------------------------------------------------------+
//| SessionManager.mqh                                                |
//| Hora de Nueva York con horario de verano, modo 24/5 o ventana,   |
//| bloqueos (rollover, reapertura, viernes), exclusiones y dia de   |
//| trading. Reglas: docs/etapa-a/01-documento-tecnico.md §5          |
//+------------------------------------------------------------------+
#ifndef NBRL_SESSION_MQH
#define NBRL_SESSION_MQH

#include "Inputs.mqh"

//+------------------------------------------------------------------+
//| Funciones de calendario (UTC)                                    |
//+------------------------------------------------------------------+
datetime NBRL_MakeDate(const int y, const int m, const int d, const int h = 0, const int mi = 0)
  {
   MqlDateTime t;
   ZeroMemory(t);
   t.year = y;
   t.mon  = m;
   t.day  = d;
   t.hour = h;
   t.min  = mi;
   t.sec  = 0;
   return StructToTime(t);
  }

int NBRL_DayOfWeek(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.day_of_week;
  }

//--- n-esimo domingo del mes (n >= 1)
datetime NBRL_NthSunday(const int y, const int m, const int n)
  {
   datetime first = NBRL_MakeDate(y, m, 1);
   int dow = NBRL_DayOfWeek(first);
   int day = 1 + ((7 - dow) % 7) + 7 * (n - 1);
   return NBRL_MakeDate(y, m, day);
  }

//--- EE. UU. en horario de verano (reglas desde 2007).
//--- Inicio: 2.º domingo de marzo 02:00 EST = 07:00 UTC.
//--- Fin:    1.er domingo de noviembre 02:00 EDT = 06:00 UTC.
bool NBRL_IsUSDST(const datetime utc)
  {
   MqlDateTime s;
   TimeToStruct(utc, s);
   datetime start = NBRL_NthSunday(s.year, 3, 2) + 7 * 3600;
   datetime end   = NBRL_NthSunday(s.year, 11, 1) + 6 * 3600;
   return (utc >= start && utc < end);
  }

datetime NBRL_UTCToNY(const datetime utc)
  {
   return utc - (NBRL_IsUSDST(utc) ? 4 : 5) * 3600;
  }

//+------------------------------------------------------------------+
//| CSessionManager                                                   |
//+------------------------------------------------------------------+
class CSessionManager
  {
private:
   string   m_symbol;
   int      m_rollFrom, m_rollTo;
   int      m_friLast, m_friClose;
   int      m_winStart, m_winLast, m_winEnd;
   int      m_dayStart;
   int      m_exFrom[], m_exTo[];
   datetime m_events[];           // eventos en hora NY (como datetime)
   bool     m_weekday[7];
   datetime m_lastTick;           // servidor
   datetime m_reopenAt;           // servidor
   int      m_autoOffsetSec;
   bool     m_auto;

   int      MinuteOfDay(const datetime t) const
     {
      MqlDateTime s;
      TimeToStruct(t, s);
      return s.hour * 60 + s.min;
     }

public:
   string   last_reason;

            CSessionManager(void) : m_lastTick(0), m_reopenAt(0), m_autoOffsetSec(0), m_auto(false) {}

   bool     Init(const string symbol)
     {
      m_symbol = symbol;
      bool ok = true;
      string p[];
      if(StringSplit(RolloverBlockNY, '-', p) == 2)
        {
         m_rollFrom = ParseHHMM(p[0]);
         m_rollTo   = ParseHHMM(p[1]);
        }
      else
        {
         m_rollFrom = -1;
         m_rollTo   = -1;
        }
      m_friLast  = ParseHHMM(FridayLastEntryNY);
      m_friClose = ParseHHMM(FridayCloseNY);
      m_winStart = ParseHHMM(TradeStartNY);
      m_winLast  = ParseHHMM(LastEntryNY);
      m_winEnd   = ParseHHMM(SessionEndNY);
      m_dayStart = ParseHHMM(TradingDayStartNY);
      if(m_dayStart < 0 || m_friLast < 0 || m_friClose < 0)
        {
         Print(NBRL_NAME, ": hora de sesion no valida");
         ok = false;
        }
      if(SessionMode == SESSION_WINDOW && (m_winStart < 0 || m_winLast < 0 || m_winEnd < 0))
        {
         Print(NBRL_NAME, ": ventana WINDOW no valida");
         ok = false;
        }
      //--- exclusiones diarias
      ArrayResize(m_exFrom, 0);
      ArrayResize(m_exTo, 0);
      string w[];
      int nw = StringSplit(ExcludeWindowsNY, ';', w);
      for(int i = 0; i < nw; i++)
        {
         string ab[];
         if(StringSplit(w[i], '-', ab) != 2) continue;
         int a = ParseHHMM(ab[0]);
         int b = ParseHHMM(ab[1]);
         if(a < 0 || b < 0) { Print(NBRL_NAME, ": exclusion ignorada '", w[i], "'"); continue; }
         int k = ArraySize(m_exFrom);
         ArrayResize(m_exFrom, k + 1);
         ArrayResize(m_exTo, k + 1);
         m_exFrom[k] = a;
         m_exTo[k]   = b;
        }
      //--- eventos programados (hora NY)
      ArrayResize(m_events, 0);
      string e[];
      int ne = StringSplit(EventTimesNY, ';', e);
      for(int i = 0; i < ne; i++)
        {
         string s = e[i];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(s == "") continue;
         datetime t = StringToTime(s);
         if(t <= 0) { Print(NBRL_NAME, ": evento ignorado '", s, "'"); continue; }
         int k = ArraySize(m_events);
         ArrayResize(m_events, k + 1);
         m_events[k] = t;
        }
      //--- dias permitidos (dia de la semana del dia de trading)
      for(int i = 0; i < 7; i++) m_weekday[i] = false;
      string d[];
      int nd = StringSplit(TradeWeekdays, ',', d);
      for(int i = 0; i < nd; i++)
        {
         int v = (int)StringToInteger(d[i]);
         if(v >= 0 && v <= 6) m_weekday[v] = true;
        }
      //--- offset del servidor
      m_auto = (ServerTimeMode == SRVTIME_AUTO && !MQLInfoInteger(MQL_TESTER));
      if(ServerTimeMode == SRVTIME_AUTO && MQLInfoInteger(MQL_TESTER))
         Print(NBRL_NAME, ": en el Strategy Tester se usa el offset MANUAL (TimeGMT no es fiable)");
      RefreshAutoOffset();
      return ok;
     }

   void     RefreshAutoOffset(void)
     {
      if(!m_auto) return;
      long diff = (long)TimeTradeServer() - (long)TimeGMT();
      m_autoOffsetSec = (int)(MathRound(diff / 1800.0) * 1800);
     }

   int      AutoOffsetSec(void) const { return m_autoOffsetSec; }

   //--- servidor -> UTC
   datetime ServerToUTC(const datetime server) const
     {
      if(m_auto) return server - m_autoOffsetSec;
      int off = (int)MathRound(ServerUTCOffsetHours * 3600.0);
      datetime utc = server - off;
      if(ServerDSTMode == SRVDST_US && NBRL_IsUSDST(utc - 3600)) utc -= 3600;
      return utc;
     }

   datetime ServerToNY(const datetime server) const { return NBRL_UTCToNY(ServerToUTC(server)); }

   //--- clave del dia de trading: medianoche del dia al que pertenece
   //--- (con inicio a las 17:00 NY, el lunes empieza el domingo 17:00 NY)
   datetime TradingDayKey(const datetime server) const
     {
      long shifted = (long)ServerToNY(server) + (long)(24 * 60 - m_dayStart) * 60;
      return (datetime)(shifted - shifted % 86400);
     }

   int      NYMinute(const datetime server) const { return MinuteOfDay(ServerToNY(server)); }

   int      TimeBlock(const datetime server) const
     {
      int m = NYMinute(server);
      if(m >= 18 * 60 || m < 3 * 60)  return TB_ASIA;
      if(m < 9 * 60 + 30)             return TB_EUROPE;
      if(m < 16 * 60)                 return TB_NY;
      return TB_POST;
     }

   //--- se llama en cada tick: detecta reaperturas del mercado
   void     OnTickTime(const datetime server)
     {
      if(m_lastTick > 0 && server - m_lastTick >= ReopenGapMin * 60)
        {
         m_reopenAt = server;
         if(VerboseLog) Print(NBRL_NAME, ": reapertura detectada ", TimeToString(server));
        }
      if(server > m_lastTick) m_lastTick = server;
     }

   //--- el simbolo tiene sesion de trading abierta segun el broker
   bool     SymbolSessionOpen(const datetime server) const
     {
      MqlDateTime s;
      TimeToStruct(server, s);
      int secOfDay = s.hour * 3600 + s.min * 60 + s.sec;
      datetime from, to;
      for(uint i = 0; i < 10; i++)
        {
         if(!SymbolInfoSessionTrade(m_symbol, (ENUM_DAY_OF_WEEK)s.day_of_week, i, from, to)) break;
         int f = (int)((long)from % 86400);
         int t = (int)((long)to % 86400);
         if((long)to - (long)from >= 86400) return true;   // sesion de dia completo
         if(t == 0 && to > from) t = 86400;
         if(secOfDay >= f && secOfDay < t) return true;
        }
      return false;
     }

   //--- permite nuevas entradas ahora; si no, last_reason explica por que
   bool     CanOpen(const datetime server)
     {
      last_reason = "";
      datetime ny = ServerToNY(server);
      int m = MinuteOfDay(ny);
      int nyDow = NBRL_DayOfWeek(ny);
      int dayDow = NBRL_DayOfWeek(TradingDayKey(server));

      if(!m_weekday[dayDow])                 { last_reason = "weekday";        return false; }
      if(!SymbolSessionOpen(server))         { last_reason = "symbol_closed";  return false; }
      if(m_reopenAt > 0 && server < m_reopenAt + ReopenBlockMin * 60)
                                             { last_reason = "reopen_block";   return false; }
      if(SessionMode == SESSION_H24_5)
        {
         if(MinuteInRange(m, m_rollFrom, m_rollTo)) { last_reason = "rollover_block"; return false; }
         if(nyDow == 5 && m >= m_friLast)           { last_reason = "friday_cutoff";  return false; }
         if(nyDow == 6)                             { last_reason = "weekend";        return false; }
         int tb = TimeBlock(server);
         if((tb == TB_ASIA && !AllowAsia) || (tb == TB_EUROPE && !AllowEurope) ||
            (tb == TB_NY && !AllowNY) || (tb == TB_POST && !AllowPost))
           { last_reason = "time_block_" + TimeBlockName(tb); return false; }
        }
      else
        {
         if(!(m >= m_winStart && m < m_winLast)) { last_reason = "outside_window"; return false; }
        }
      for(int i = 0; i < ArraySize(m_exFrom); i++)
         if(MinuteInRange(m, m_exFrom[i], m_exTo[i])) { last_reason = "exclusion_window"; return false; }
      for(int i = 0; i < ArraySize(m_events); i++)
         if(ny >= m_events[i] - EventMarginBeforeMin * 60 && ny <= m_events[i] + EventMarginAfterMin * 60)
           { last_reason = "event_window"; return false; }
      return true;
     }

   //--- hay que cerrar las posiciones del EA por politica de sesion
   bool     MustCloseAll(const datetime server, string &why) const
     {
      datetime ny = ServerToNY(server);
      int m = MinuteOfDay(ny);
      int nyDow = NBRL_DayOfWeek(ny);
      if(SessionMode == SESSION_H24_5)
        {
         if(WeekendClosePolicy == POLICY_CLOSE_ALL && ((nyDow == 5 && m >= m_friClose) || nyDow == 6))
           { why = "weekend_close"; return true; }
         if(DailyRolloverPolicy == POLICY_CLOSE_ALL && MinuteInRange(m, m_rollFrom, m_rollTo))
           { why = "rollover_close"; return true; }
        }
      else
        {
         if(SessionClosePolicy == POLICY_CLOSE_ALL && (m >= m_winEnd || m < m_winStart))
           { why = "session_end"; return true; }
        }
      return false;
     }
  };

#endif
