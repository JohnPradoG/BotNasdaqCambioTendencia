//+------------------------------------------------------------------+
//| NasdaqBreakoutReversalLab.mq5                                     |
//| EA NASDAQ BREAKOUT & REVERSAL LAB - MT5 / Exness                  |
//| Especificacion: docs/SPEC.md. Diseno: docs/etapa-a/.              |
//| v0.1 (Etapa B): motores A (A1/A2) y B (B1/B2), riesgo comun,     |
//| seguridad de ejecucion, gestion basica de salidas y registros.   |
//| El motor C (falsas rupturas) se anade en la Etapa C.              |
//+------------------------------------------------------------------+
#property copyright "NBRL"
#property version   "1.00"
#property description "Nasdaq Breakout & Reversal Lab (experimental, sin resultados validados)"

#include <NBRL\Inputs.mqh>
#include <NBRL\SessionManager.mqh>
#include <NBRL\MarketStructureDetector.mqh>
#include <NBRL\ReversalAnticipationEngine.mqh>
#include <NBRL\ConsolidationBreakoutEngine.mqh>
#include <NBRL\SignalQualityFilter.mqh>
#include <NBRL\RiskManager.mqh>
#include <NBRL\SafetyController.mqh>
#include <NBRL\PositionManager.mqh>
#include <NBRL\TradeLogger.mqh>
#include <NBRL\PerformanceAnalyzer.mqh>

//--- modulos
CSessionManager      g_session;
CMarketStructure     g_msd;
CReversalEngine      g_engA;
CBreakoutEngine      g_engB;
CSignalQualityFilter g_filter;
CRiskManager         g_risk;
CSafetyController    g_safety;
CPositionManager     g_pos;
CTradeLogger         g_log;
CPerformanceAnalyzer g_perf;

//--- estado
string   g_sym;
datetime g_lastBar = 0;
string   g_seen[];
int      g_rank[NBRL_VARIANTS];
string   g_lastReject = "";
string   g_lastSignal = "";
string   g_lastRiskWhy = "";
bool     g_riskClose = false;
int      g_signalsToday = 0;
datetime g_panelTime = 0;

//+------------------------------------------------------------------+
datetime NY(const datetime server) { return g_session.ServerToNY(server); }

void LogEvent(const string category, const string detail)
  {
   datetime now = TimeCurrent();
   g_log.Event(now, NY(now), g_sym, InpMagic, category, detail);
  }

bool ParamsOk(string &why)
  {
   if(B_RangeMinBars < 3 || B_RangeMinBars > B_RangeMaxBars) { why = "B_RangeMinBars/MaxBars"; return false; }
   if(B_RangeMaxBars + 3 >= NBRL_BARS_ENTRY)                 { why = "B_RangeMaxBars demasiado grande"; return false; }
   if(A_LegLookback < 4 || A_LegLookback >= NBRL_BARS_CTX - 2) { why = "A_LegLookback"; return false; }
   if(SwingStrengthCtx < 1 || SwingStrengthEntry < 1)        { why = "SwingStrength"; return false; }
   if(TP_R <= 0.0 || SLMinATR <= 0.0 || SLMaxATR <= 0.0)     { why = "TP_R/SLMinATR/SLMaxATR"; return false; }
   if(PeriodSeconds(InpTFContext) <= PeriodSeconds(InpTFEntry)) { why = "InpTFContext debe ser mayor que InpTFEntry"; return false; }
   return true;
  }

void ParsePriority()
  {
   for(int v = 0; v < NBRL_VARIANTS; v++) g_rank[v] = 100 + v;
   string p[];
   int n = StringSplit(InpPriority, ',', p);
   for(int i = 0; i < n; i++)
     {
      string t = p[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      for(int v = 0; v < NBRL_VARIANTS; v++)
         if(VariantName(v) == t) g_rank[v] = i;
     }
  }

bool Seen(const string id)
  {
   for(int i = ArraySize(g_seen) - 1; i >= 0; i--)
      if(g_seen[i] == id) return true;
   int n = ArraySize(g_seen);
   if(n >= 2000)
     {
      ArrayRemove(g_seen, 0, 500);
      n = ArraySize(g_seen);
     }
   ArrayResize(g_seen, n + 1);
   g_seen[n] = id;
   return false;
  }

//+------------------------------------------------------------------+
//| Registro de una senal con su estado final                        |
//+------------------------------------------------------------------+
void LogSignal(const SSignal &s, const string status, const string reason, const double sl, const double tp,
               const double vol, const double riskM, const double spreadPts, const ulong ticket)
  {
   datetime now = TimeCurrent();
   int dg = g_msd.digits;
   double pt = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   double rPts = (sl > 0.0 && pt > 0.0 ? MathAbs(s.entry_ref - sl) / pt : 0.0);
   string line = s.id + ";" + TimeToString(now, TIME_DATE | TIME_SECONDS) + ";" +
                 TimeToString(NY(now), TIME_DATE | TIME_SECONDS) + ";" + g_sym + ";" + IntegerToString(InpMagic) + ";" +
                 EngineName(s.variant) + ";" + VariantName(s.variant) + ";" + DirName(s.dir) + ";" +
                 EnumToString(InpTFContext) + ";" + EnumToString(InpTFEntry) + ";" + s.type + ";" +
                 TimeToString(s.bar_time, TIME_DATE | TIME_MINUTES) + ";" + CTradeLogger::Clean(s.structure_id) + ";" +
                 DoubleToString(s.entry_ref, dg) + ";" + DoubleToString(sl, dg) + ";" + DoubleToString(tp, dg) + ";" +
                 DoubleToString(rPts, 1) + ";" + DoubleToString(vol, 2) + ";" + DoubleToString(riskM, 2) + ";" +
                 DoubleToString(spreadPts, 1) + ";" + DoubleToString(s.atr_ctx, dg) + ";" +
                 DoubleToString(s.atr_entry, dg) + ";" + RegimeName(s.regime) + ";" + DoubleToString(s.vol_ratio, 2) + ";" +
                 TimeBlockName(g_session.TimeBlock(now)) + ";" + CTradeLogger::Clean(s.reasons) + ";" +
                 status + ";" + CTradeLogger::Clean(reason) + ";" + IntegerToString((long)ticket);
   g_log.Signal(line);
   g_lastSignal = VariantName(s.variant) + " " + DirName(s.dir) + " " + status;
   if(status == "REJECTED") g_lastReject = VariantName(s.variant) + ": " + reason;
  }

//+------------------------------------------------------------------+
//| SL y TP finales con las reglas comunes (doc. tecnico §4.7)        |
//+------------------------------------------------------------------+
bool BuildStops(const SSignal &s, const double entry, const double spread, double &sl, double &tp, string &why)
  {
   double atrE = s.atr_entry, atrC = s.atr_ctx;
   if(s.dir == DIR_SELL) sl = s.sl_struct + SLBufferATR * atrE + spread;
   else                  sl = s.sl_struct - SLBufferATR * atrE;
   double dist = (s.dir == DIR_SELL ? sl - entry : entry - sl);
   if(dist <= 0.0) { why = "sl_wrong_side"; return false; }
   double minD = MathMax(SLMinATR * atrE, g_safety.MinStopDistance() + spread);
   if(dist < minD)
     {
      dist = minD;     // el SL se aleja hasta el minimo; nunca se acerca
      sl = (s.dir == DIR_SELL ? entry + dist : entry - dist);
     }
   if(dist > SLMaxATR * atrC) { why = "sl_too_wide"; return false; }
   sl = NormalizePrice(g_sym, sl);
   dist = MathAbs(entry - sl);
   double reward = 0.0;
   if(s.tp_struct > 0.0) reward = (s.dir == DIR_SELL ? entry - s.tp_struct : s.tp_struct - entry);
   if(s.tp_struct > 0.0 && reward >= 1.0 * dist) tp = s.tp_struct;
   else tp = (s.dir == DIR_SELL ? entry - TP_R * dist : entry + TP_R * dist);
   tp = NormalizePrice(g_sym, tp);
   return true;
  }

//+------------------------------------------------------------------+
//| Intenta convertir una senal en operacion                          |
//+------------------------------------------------------------------+
void TryExecute(SSignal &s)
  {
   datetime now = TimeCurrent();
   double bid = SymbolInfoDouble(g_sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(g_sym, SYMBOL_ASK);
   double pt = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   double spread = ask - bid;
   double spreadPts = (pt > 0.0 ? spread / pt : 0.0);
   double entry = (s.dir == DIR_BUY ? ask : bid);
   double sl = 0.0, tp = 0.0, vol = 0.0, riskM = 0.0;
   string why = "";

   if(InpBlockNewEntries)                               why = "global_block";
   else if(!g_session.CanOpen(now))                     why = "session:" + g_session.last_reason;
   else if(g_pos.Active() || g_safety.HasOwnExposure()) why = "position_open";
   if(why == "") BuildStops(s, entry, spread, sl, tp, why);
   if(why == "") g_filter.Check(s, entry, sl, tp, spread, pt, why);
   if(why == "")
     {
      vol = g_risk.CalcVolume(s.dir, entry, sl, riskM);
      if(vol <= 0.0) why = "risk:" + g_risk.last_reason;
     }
   if(why == "" && !g_risk.AllowEntry(riskM, s.variant)) why = "risk:" + g_risk.last_reason;

   if(why != "")
     {
      LogSignal(s, "REJECTED", why, sl, tp, vol, riskM, spreadPts, 0);
      return;
     }
   if(InpAnalysisOnly)
     {
      LogSignal(s, "ANALYSIS_ONLY", "", sl, tp, vol, riskM, spreadPts, 0);
      return;
     }
   string comment = NBRL_NAME + "|" + VariantName(s.variant) + "|" + StringSubstr(s.id, 3);
   ulong ticket = 0;
   double fill = 0.0;
   if(g_safety.Open(s.dir, vol, sl, tp, comment, ticket, fill))
     {
      double slReal = sl, tpReal = tp;
      if(PositionSelectByTicket(ticket))
        {
         slReal = PositionGetDouble(POSITION_SL);
         tpReal = PositionGetDouble(POSITION_TP);
         vol    = PositionGetDouble(POSITION_VOLUME);
        }
      g_pos.OnOpened(s, ticket, entry, fill, slReal, tpReal, vol, riskM, spreadPts, g_session.TimeBlock(now), now, NY(now));
      LogSignal(s, "EXECUTED", "", slReal, tpReal, vol, riskM, spreadPts, ticket);
      LogEvent("ENTRY", StringFormat("%s %s %s vol=%.2f fill=%s sl=%s tp=%s risk=%.2f ticket=%I64u",
                                     s.id, VariantName(s.variant), DirName(s.dir), vol,
                                     DoubleToString(fill, g_msd.digits), DoubleToString(slReal, g_msd.digits),
                                     DoubleToString(tpReal, g_msd.digits), riskM, ticket));
      g_risk.DayStats();
     }
   else
     {
      LogSignal(s, "ERROR", g_safety.last_error, sl, tp, vol, riskM, spreadPts, 0);
      LogEvent("ERROR", "open_failed " + s.id + " " + g_safety.last_error);
     }
  }

//+------------------------------------------------------------------+
//| Senales de la vela cerrada: deduplicar, resolver conflictos, ejecutar |
//+------------------------------------------------------------------+
void ProcessSignals(SSignal &sigs[])
  {
   int n = ArraySize(sigs);
   int cand[];
   ArrayResize(cand, 0);
   for(int i = 0; i < n; i++)
     {
      string key = VariantName(sigs[i].variant) + "|" + g_sym + "|" + EnumToString(InpTFEntry) + "|" +
                   TimeToString(sigs[i].bar_time) + "|" + DirName(sigs[i].dir) + "|" + sigs[i].structure_id;
      sigs[i].id = VariantName(sigs[i].variant) + "-" + HashString(key);
      if(Seen(sigs[i].id)) { sigs[i].rejected = true; sigs[i].reject_reason = "duplicate"; continue; }
      g_signalsToday++;
      if(sigs[i].rejected)
        {
         LogSignal(sigs[i], "REJECTED", "engine:" + sigs[i].reject_reason, 0, 0, 0, 0, 0, 0);
         continue;
        }
      int k = ArraySize(cand);
      ArrayResize(cand, k + 1);
      cand[k] = i;
     }
   int m = ArraySize(cand);
   if(m == 0) return;

   bool hasBuy = false, hasSell = false;
   for(int i = 0; i < m; i++)
     {
      if(sigs[cand[i]].dir == DIR_BUY) hasBuy = true;
      else hasSell = true;
     }
   if(hasBuy && hasSell)
     {
      for(int i = 0; i < m; i++) LogSignal(sigs[cand[i]], "REJECTED", "opposite_conflict", 0, 0, 0, 0, 0, 0);
      return;
     }
   int best = cand[0];
   for(int i = 1; i < m; i++)
      if(g_rank[sigs[cand[i]].variant] < g_rank[sigs[best].variant]) best = cand[i];
   for(int i = 0; i < m; i++)
      if(cand[i] != best) LogSignal(sigs[cand[i]], "REJECTED", "conflict", 0, 0, 0, 0, 0, 0);
   TryExecute(sigs[best]);
  }

void LogEngineEvents(const string &ev[])
  {
   for(int i = 0; i < ArraySize(ev); i++) LogEvent("SETUP", ev[i]);
  }

bool OnNewBar()
  {
   if(!g_msd.Update(g_session)) return false;
   g_risk.DayStats();
   SSignal sigs[];
   ArrayResize(sigs, 0);
   g_engA.Evaluate(g_msd, sigs);
   LogEngineEvents(g_engA.events);
   g_engB.Evaluate(g_msd, sigs);
   LogEngineEvents(g_engB.events);
   ProcessSignals(sigs);
   return true;
  }

void UpdatePanel()
  {
   if(!ShowPanel) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   datetime now = TimeCurrent();
   if(now == g_panelTime) return;
   g_panelTime = now;
   string mode = (InpAnalysisOnly ? "SOLO ANALISIS" : (InpBlockNewEntries ? "ENTRADAS BLOQUEADAS" : "ACTIVO"));
   string eng = (InpEnableA1 ? "A1 " : "") + (InpEnableA2 ? "A2 " : "") + (InpEnableB1 ? "B1 " : "") + (InpEnableB2 ? "B2 " : "");
   double ref = g_risk.DayRef();
   string txt = StringFormat(
      "%s v%s  %s  magic %I64d  [%s]\n"
      "Servidor %s | NY %s | bloque %s | sesion %s\n"
      "Motores: %s\n"
      "Hoy: operaciones %d  senales %d  realizado %.2f (%.2f%%)  riesgo abierto %.2f\n"
      "DD EA %.2f%%  kill switch %s  dia bloqueado %s\n"
      "Posicion: %s\n"
      "Ultima senal: %s\n"
      "Ultimo rechazo: %s",
      NBRL_NAME, NBRL_VERSION, g_sym, InpMagic, mode,
      TimeToString(now, TIME_MINUTES), TimeToString(NY(now), TIME_MINUTES),
      TimeBlockName(g_session.TimeBlock(now)), (g_session.CanOpen(now) ? "abierta" : g_session.last_reason),
      eng,
      g_risk.trades_today, g_signalsToday, g_risk.realized, (ref > 0.0 ? 100.0 * g_risk.realized / ref : 0.0),
      g_risk.OpenRisk(),
      g_risk.DDPct(), (g_risk.KillSwitch() ? "SI" : "no"), (g_risk.DayBlocked() ? g_risk.block_reason : "no"),
      (g_pos.Active() ? VariantName(g_pos.ActiveVariant()) : "ninguna"),
      g_lastSignal, g_lastReject);
   Comment(txt);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_sym = (InpSymbol == "" ? _Symbol : InpSymbol);
   string info;
   if(!g_safety.ValidateSymbol(g_sym, info))
     {
      Print(NBRL_NAME, ": ", info);
      return INIT_PARAMETERS_INCORRECT;
     }
   string why;
   if(!ParamsOk(why))
     {
      Print(NBRL_NAME, ": parametro no valido: ", why);
      return INIT_PARAMETERS_INCORRECT;
     }
   //--- en el tester se parte siempre de un estado limpio
   if(MQLInfoInteger(MQL_TESTER))
      GlobalVariablesDeleteAll(NBRL_NAME + "_" + IntegerToString(InpMagic) + "_");
   if(!g_session.Init(g_sym))           return INIT_PARAMETERS_INCORRECT;
   if(!g_msd.Init(g_sym))               return INIT_FAILED;
   if(!g_risk.Init(g_sym, InpMagic))    { Print(NBRL_NAME, ": parametros de riesgo no validos"); return INIT_PARAMETERS_INCORRECT; }
   g_log.Init(g_sym, InpMagic);
   g_safety.Init(InpMagic);
   g_pos.Init(g_sym, InpMagic);
   g_perf.Reset();
   g_engA.Reset();
   g_engB.Reset();
   ParsePriority();
   ArrayResize(g_seen, 0);

   datetime now = TimeCurrent();
   LogEvent("INIT", StringFormat("v%s %s server=%s ny=%s utc_offset_mode=%s auto_offset_s=%d session=%s analysis_only=%s",
                                 NBRL_VERSION, info, TimeToString(now, TIME_DATE | TIME_SECONDS),
                                 TimeToString(NY(now), TIME_DATE | TIME_SECONDS), EnumToString(ServerTimeMode),
                                 g_session.AutoOffsetSec(), EnumToString(SessionMode),
                                 (InpAnalysisOnly ? "true" : "false")));
   Print(NBRL_NAME, " v", NBRL_VERSION, " iniciado en ", g_sym, ". Registros en MQL5/Files/", g_log.Folder(),
         (LogToCommon ? " (carpeta comun)" : ""));

   //--- recuperacion tras reinicio: readoptar la posicion propia
   ulong t = g_safety.FindOwnPosition();
   if(t != 0)
     {
      g_pos.Adopt(t);
      LogEvent("RECOVERY", g_pos.last_event);
     }
   //--- no volver a evaluar la vela ya procesada antes del reinicio
   string gvBar = NBRL_NAME + "_" + IntegerToString(InpMagic) + "_" + g_sym + "_lastBar";
   if(GlobalVariableCheck(gvBar)) g_lastBar = (datetime)(long)GlobalVariableGet(gvBar);
   g_risk.DayStats();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_perf.PrintSummary();
   g_msd.Deinit();
   Comment("");
  }

void OnTick()
  {
   datetime now = TimeCurrent();
   g_session.OnTickTime(now);

   //--- dia de trading
   if(g_risk.OnDayCheck(g_session.TradingDayKey(now), now))
     {
      g_session.RefreshAutoOffset();
      g_signalsToday = 0;
      g_risk.DayStats();
      LogEvent("DAY", StringFormat("nuevo dia de trading ref=%.2f limite=%.2f", g_risk.DayRef(), g_risk.DayLimitMoney()));
     }

   //--- limites de riesgo y politica de sesion
   string riskWhy;
   if(g_risk.CheckLimits(riskWhy)) g_riskClose = true;
   if(riskWhy != "" && riskWhy != g_lastRiskWhy)
     {
      LogEvent("RISK", riskWhy);
      g_lastRiskWhy = riskWhy;
     }
   if(!g_pos.Active()) g_riskClose = false;
   string sessWhy = "";
   bool sessClose = g_session.MustCloseAll(now, sessWhy);
   g_pos.OnTick(g_session, g_safety, g_risk, g_log, g_perf, g_msd.atrE1,
                g_riskClose || sessClose, (g_riskClose ? "risk_limit" : sessWhy));

   //--- nueva vela cerrada del TF de entrada
   datetime bt = iTime(g_sym, InpTFEntry, 0);
   if(bt != 0 && bt != g_lastBar)
     {
      if(OnNewBar())
        {
         g_lastBar = bt;
         GlobalVariableSet(NBRL_NAME + "_" + IntegerToString(InpMagic) + "_" + g_sym + "_lastBar", (double)bt);
        }
     }
   UpdatePanel();
  }

double OnTester()
  {
   return g_perf.TesterCriterion();
  }
//+------------------------------------------------------------------+
