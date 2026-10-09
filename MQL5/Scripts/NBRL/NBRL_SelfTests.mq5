//+------------------------------------------------------------------+
//| NBRL_SelfTests.mq5                                                |
//| Autotests sin operar (docs/etapa-a/05-plan-pruebas.md §1.2).      |
//| Ejecutar en un grafico del simbolo Nasdaq; resultado en Expertos. |
//+------------------------------------------------------------------+
#property version "1.10"

#include <NBRL\SessionManager.mqh>
#include <NBRL\MarketStructureDetector.mqh>
#include <NBRL\Logic.mqh>

int g_fail = 0, g_ok = 0;

void Check(const bool cond, const string name)
  {
   if(cond) { g_ok++; Print("OK   ", name); }
   else     { g_fail++; Print("FAIL ", name); }
  }

datetime U(const string s) { return StringToTime(s); }

void TestDST()
  {
   //--- T-DST-1: 2024-03-10 06:59 UTC = 01:59 EST ; 07:00 UTC = 03:00 EDT
   Check(NBRL_UTCToNY(U("2024.03.10 06:59")) == U("2024.03.10 01:59"), "T-DST-1a");
   Check(NBRL_UTCToNY(U("2024.03.10 07:00")) == U("2024.03.10 03:00"), "T-DST-1b");
   //--- T-DST-2: 2024-11-03 05:59 UTC = 01:59 EDT ; 06:00 UTC = 01:00 EST
   Check(NBRL_UTCToNY(U("2024.11.03 05:59")) == U("2024.11.03 01:59"), "T-DST-2a");
   Check(NBRL_UTCToNY(U("2024.11.03 06:00")) == U("2024.11.03 01:00"), "T-DST-2b");
   //--- T-DST-3: fechas de cambio de otros anios
   Check(NBRL_NthSunday(2021, 3, 2) == U("2021.03.14"), "T-DST-3 2021 marzo");
   Check(NBRL_NthSunday(2021, 11, 1) == U("2021.11.07"), "T-DST-3 2021 noviembre");
   Check(NBRL_NthSunday(2025, 3, 2) == U("2025.03.09"), "T-DST-3 2025 marzo");
   Check(NBRL_NthSunday(2025, 11, 1) == U("2025.11.02"), "T-DST-3 2025 noviembre");
   Check(NBRL_NthSunday(2026, 3, 2) == U("2026.03.08"), "T-DST-3 2026 marzo");
   Check(NBRL_NthSunday(2026, 11, 1) == U("2026.11.01"), "T-DST-3 2026 noviembre");
   //--- T-DST-4: EE. UU. en verano y Europa aun en invierno
   Check(NBRL_UTCToNY(U("2025.03.12 13:35")) == U("2025.03.12 09:35"), "T-DST-4");
   //--- invierno
   Check(NBRL_UTCToNY(U("2025.01.15 14:35")) == U("2025.01.15 09:35"), "T-DST invierno");
  }

void TestSwings()
  {
   //--- serie (indice 0 = vela abierta). Pico en i=5, valle en i=9, strength=2
   double hi[] = {10, 11, 12, 13, 14, 20, 14, 13, 12, 11, 12, 13, 14, 15, 16};
   double lo[] = { 9, 10, 11, 12, 13, 19, 13, 12, 11,  5, 11, 12, 13, 14, 15};
   datetime t[];
   int n = ArraySize(hi);
   ArrayResize(t, n);
   for(int i = 0; i < n; i++) t[i] = (datetime)(1000000 - i * 300);
   SSwing sw[];
   int k = NBRL_FindSwings(hi, lo, t, n, 2, 1.0, sw);
   bool hasHigh5 = false, hasLow9 = false;
   for(int i = 0; i < k; i++)
     {
      if(sw[i].is_high && sw[i].shift == 5) hasHigh5 = true;
      if(!sw[i].is_high && sw[i].shift == 9) hasLow9 = true;
     }
   Check(hasHigh5, "T-SW-1 swing high confirmado");
   Check(hasLow9, "T-SW-1 swing low confirmado");
   //--- un pico en i=2 no puede confirmarse con strength=2 (necesita i-2 >= 1)
   double hi2[] = {10, 11, 30, 12, 11, 10, 9, 8};
   double lo2[] = { 9, 10, 29, 11, 10,  9, 8, 7};
   datetime t2[];
   ArrayResize(t2, 8);
   for(int i = 0; i < 8; i++) t2[i] = (datetime)(1000000 - i * 300);
   SSwing sw2[];
   NBRL_FindSwings(hi2, lo2, t2, 8, 2, 1.0, sw2);
   bool early = false;
   for(int i = 0; i < ArraySize(sw2); i++) if(sw2[i].is_high && sw2[i].shift == 2) early = true;
   Check(!early, "T-SW-2 sin confirmacion anticipada");
  }

void TestUtils()
  {
   Check(ParseHHMM("09:35") == 575, "ParseHHMM");
   Check(ParseHHMM("25:00") == -1, "ParseHHMM invalido");
   Check(MinuteInRange(17 * 60, 16 * 60 + 50, 17 * 60 + 20), "MinuteInRange rollover");
   Check(MinuteInRange(60, 23 * 60, 2 * 60), "MinuteInRange cruce medianoche");
   Check(HashString("abc") == HashString("abc") && HashString("abc") != HashString("abd"), "HashString estable");
  }

//--- T-VOL: reproduce el redondeo de RiskManager con valores fijos
double VolFloor(const double riskMoney, const double loss1, const double step, const double vmin, const double vmax)
  {
   double vol = MathFloor(riskMoney / loss1 / step + 1e-9) * step;
   if(vol > vmax) vol = MathFloor(vmax / step + 1e-9) * step;
   if(vol < vmin - 1e-12) return 0.0;
   return vol;
  }

void TestVolume()
  {
   Check(MathAbs(VolFloor(25, 400, 0.01, 0.01, 100) - 0.06) < 1e-9, "T-VOL-1");
   Check(VolFloor(25, 4000, 0.01, 0.01, 100) == 0.0, "T-VOL-2 minimo supera el riesgo");
   Check(MathAbs(VolFloor(1e6, 1, 0.01, 0.01, 50) - 50) < 1e-9, "T-VOL-3 maximo");
   Check(MathAbs(VolFloor(19, 100, 0.1, 0.1, 100) - 0.1) < 1e-9, "T-VOL-4 siempre hacia abajo");
  }

//--- T-SL: SL estructural, minimo y maximo (valores redondos, sin simbolo)
void TestStops()
  {
   double sl = 0.0;
   string why = "";
   //--- venta: entrada 100, estructura 100.5, ATR 1, sin colchon ni spread,
   //--- minimo 1 ATR -> SL alejado a 101 (nunca acercado)
   bool ok = NBRL_CalcSL(DIR_SELL, 100.0, 100.5, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(ok && MathAbs(sl - 101.0) < 1e-9, "T-SL-1 venta: SL alejado al minimo");
   ok = NBRL_CalcSL(DIR_BUY, 100.0, 99.5, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(ok && MathAbs(sl - 99.0) < 1e-9, "T-SL-1 compra: SL alejado al minimo");
   //--- estructura mas lejos que el minimo: se respeta
   ok = NBRL_CalcSL(DIR_SELL, 100.0, 102.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(ok && MathAbs(sl - 102.0) < 1e-9, "T-SL-1 SL estructural respetado");
   //--- venta: el spread se suma al SL
   ok = NBRL_CalcSL(DIR_SELL, 100.0, 102.0, 1.0, 1.0, 0.25, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(ok && MathAbs(sl - 102.25) < 1e-9, "T-SL-1 venta: spread incluido");
   //--- T-SL-2: SL a 5 ATR con maximo 3 -> rechazo
   why = "";
   ok = NBRL_CalcSL(DIR_SELL, 100.0, 105.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(!ok && why == "sl_too_wide", "T-SL-2 sl_too_wide");
   why = "";
   ok = NBRL_CalcSL(DIR_BUY, 100.0, 101.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, sl, why);
   Check(!ok && why == "sl_wrong_side", "T-SL-2 SL del lado equivocado");
   //--- TP: 1.5R si el estructural no llega a 1R; el estructural si llega
   Check(MathAbs(NBRL_CalcTP(DIR_SELL, 100.0, 102.0, 99.0, 1.5) - 97.0) < 1e-9, "T-TP 1.5R");
   Check(MathAbs(NBRL_CalcTP(DIR_SELL, 100.0, 102.0, 97.5, 1.5) - 97.5) < 1e-9, "T-TP estructural");
   Check(MathAbs(NBRL_CalcTP(DIR_BUY, 100.0, 98.0, 0.0, 1.5) - 103.0) < 1e-9, "T-TP compra sin estructura");
   //--- T-SL-3: el trailing nunca empeora el SL
   Check(!NBRL_SLIsBetter(true, 99.0, 98.5, 0.01), "T-SL-3 compra: SL mas bajo descartado");
   Check(NBRL_SLIsBetter(true, 99.0, 99.5, 0.01), "T-SL-3 compra: SL mas alto aceptado");
   Check(!NBRL_SLIsBetter(false, 101.0, 101.5, 0.01), "T-SL-3 venta: SL mas alto descartado");
   Check(NBRL_SLIsBetter(false, 101.0, 100.5, 0.01), "T-SL-3 venta: SL mas bajo aceptado");
   Check(!NBRL_SLIsBetter(true, 99.0, 99.0, 0.01), "T-SL-3 SL igual descartado");
  }

//--- T-DAY: presupuesto diario y cambio de dia a las 17:00 NY
void TestDay()
  {
   //--- capital 10000, limite 1 % = 100, riesgo por operacion 0.25 % = 25
   Check(!NBRL_DailyBudgetOk(-80.0, 0.0, 25.0, 100.0), "T-DAY-1 -0.8% + 0.25% rechazado");
   Check(NBRL_DailyBudgetOk(-75.0, 0.0, 25.0, 100.0), "T-DAY-1 -0.75% + 0.25% permitido");
   Check(!NBRL_DailyBudgetOk(-50.0, 50.0, 25.0, 100.0), "T-DAY-1 cuenta el riesgo abierto");
   Check(NBRL_DailyBudgetOk(200.0, 0.0, 25.0, 100.0), "T-DAY-1 ganancia no amplia el presupuesto");
   Check(!NBRL_DailyBudgetOk(200.0, 80.0, 25.0, 100.0), "T-DAY-1 ganancia no compensa el riesgo abierto");
   int start = 17 * 60;
   datetime a = NBRL_TradingDayKeyNY(U("2024.03.13 16:59"), start);
   datetime b = NBRL_TradingDayKeyNY(U("2024.03.13 17:00"), start);
   datetime c = NBRL_TradingDayKeyNY(U("2024.03.14 16:59"), start);
   Check(a != b, "T-DAY-2 17:00 NY empieza un dia nuevo");
   Check(b == c, "T-DAY-2 de 17:00 a 16:59 es el mismo dia");
   Check(b == U("2024.03.14"), "T-DAY-2 el dia lleva la fecha de la sesion siguiente");
  }

//--- T-ID: la misma senal solo se procesa una vez
void TestIds()
  {
   CSeenList seen;
   string id1 = "A1_" + HashString("A1|USTECm|5|2024.03.13 10:00|-1|SW123");
   string id2 = "A1_" + HashString("A1|USTECm|5|2024.03.13 10:05|-1|SW123");
   Check(!seen.Seen(id1), "T-ID-1 primera vez: nueva");
   Check(seen.Seen(id1), "T-ID-1 segunda vez: duplicada");
   Check(!seen.Seen(id2), "T-ID-1 otra vela: nueva");
   for(int i = 0; i < 2100; i++) seen.Seen("x" + IntegerToString(i));
   Check(seen.Seen("x2099"), "T-ID-1 lista acotada conserva lo reciente");
  }

void OnStart()
  {
   TestDST();
   TestSwings();
   TestUtils();
   TestVolume();
   TestStops();
   TestDay();
   TestIds();
   PrintFormat("NBRL autotests: %d OK, %d FAIL", g_ok, g_fail);
  }
