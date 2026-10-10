//+------------------------------------------------------------------+
//| TradeLogger.mqh                                                   |
//| Registro CSV (separador ';') de senales, operaciones y eventos.  |
//| Carpeta: MQL5/Files/<LogFolder>/<simbolo>_<magic>/                |
//| (o Common/Files si LogToCommon=true, recomendado en el tester).   |
//+------------------------------------------------------------------+
#ifndef NBRL_LOGGER_MQH
#define NBRL_LOGGER_MQH

#include "Inputs.mqh"

#define NBRL_SIGNALS_HEADER "signal_id;server_time;ny_time;symbol;magic;engine;variant;direction;tf_context;tf_entry;signal_type;signal_bar_time;structure_id;entry_ref;sl;tp;r_points;volume;risk_money;spread_points;atr_ctx;atr_entry;regime;vol_ratio;time_block;reasons;status;reject_reason;ticket"
#define NBRL_TRADES_HEADER  "signal_id;position_id;symbol;magic;engine;variant;direction;tf_context;tf_entry;signal_type;structure_id;open_server_time;open_ny_time;entry_ref;entry_price;slippage_points;sl_initial;tp_initial;volume;risk_money;spread_open_points;atr_entry;regime;time_block;entry_reasons;close_server_time;close_ny_time;exit_price;exit_reason;commission;swap;profit;net;result_r;mfe_r;mae_r;mfe_points;mae_points;duration_min;modifications"
#define NBRL_EVENTS_HEADER  "server_time;ny_time;symbol;magic;category;detail"

class CTradeLogger
  {
private:
   string   m_dir;
   int      m_common;

   void     Append(const string file, const string header, const string line)
     {
      string path = m_dir + file;
      int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | m_common);
      if(h == INVALID_HANDLE)
        {
         Print(NBRL_NAME, ": no se pudo abrir ", path, " error ", GetLastError());
         return;
        }
      if(FileSize(h) == 0) FileWriteString(h, header + "\r\n");
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, line + "\r\n");
      FileClose(h);
     }

public:
   bool     Init(const string sym, const long magic)
     {
      m_common = (LogToCommon ? FILE_COMMON : 0);
      m_dir = LogFolder + "\\" + sym + "_" + IntegerToString(magic) + "\\";
      return true;
     }

   string   Folder(void) const { return m_dir; }

   static string Clean(const string s)
     {
      string r = s;
      StringReplace(r, ";", ",");
      StringReplace(r, "\r", " ");
      StringReplace(r, "\n", " ");
      return r;
     }

   void     Signal(const string line) { Append("signals.csv", NBRL_SIGNALS_HEADER, line); }
   void     Trade(const string line)  { Append("trades.csv", NBRL_TRADES_HEADER, line); }

   void     Event(const datetime server, const datetime ny, const string sym, const long magic,
                  const string category, const string detail)
     {
      string line = TimeToString(server, TIME_DATE | TIME_SECONDS) + ";" +
                    TimeToString(ny, TIME_DATE | TIME_SECONDS) + ";" + sym + ";" +
                    IntegerToString(magic) + ";" + category + ";" + Clean(detail);
      Append("events.csv", NBRL_EVENTS_HEADER, line);
      if(VerboseLog || category == "ERROR" || category == "RISK")
         Print(NBRL_NAME, " [", category, "] ", detail);
     }
  };

#endif
