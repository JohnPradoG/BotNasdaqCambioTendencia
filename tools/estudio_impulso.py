#!/usr/bin/env python3
"""Estudio rapido (sin MT5) de la hipotesis del motor D: impulso fuerte + order block.

Lee velas M1 exportadas de USTECm, arma M15, detecta impulsos, simula entradas
D0 (mercado al cierre del impulso) y D1 (retroceso al order block con rechazo)
con SL estructural y TP 1.5R, recorriendo M1 para saber que se toca primero
(si ambos caen en la misma vela M1 se asume SL). Cobra el spread completo.
Solo usa 2021-11-01 a 2024-12-31 (el resto queda reservado para el OOS).
Imprime la cuadricula declarada de antemano y un control de azar (misma entrada, direccion aleatoria).

Uso: python3 tools/estudio_impulso.py --m1 RUTA.csv [--spread 5.0] [--out informe.md]
Limitaciones: sin bloqueos de sesion/rollover, un solo trade a la vez por variante, spread fijo.
"""
import argparse, itertools, sys
import numpy as np
import pandas as pd

TP_R = 1.5
BUF_ATR, MIN_ATR, MAX_ATR = 0.1, 0.5, 3.0
IMP_BODY, IMP_CLOSE, BREAK_LB, VOL_LB, OB_BACK, PEND_BARS = 0.6, 0.2, 10, 50, 6, 8
IS_FROM, IS_TO = "2021-11-01", "2024-12-31 23:59"


def load_m1(path, sep=None):
    # sep=None autodetecta (lento con millones de filas): pasar --sep "\t" o ";" si se conoce
    df = pd.read_csv(path, sep=sep) if sep else pd.read_csv(path, sep=None, engine="python")
    df.columns = [c.strip("<> ").lower() for c in df.columns]
    if "date" in df.columns and "time" in df.columns:
        ts = pd.to_datetime(df["date"].astype(str) + " " + df["time"].astype(str))
    else:
        ts = pd.to_datetime(df["time"])
    out = pd.DataFrame({
        "o": df["open"].astype(float), "h": df["high"].astype(float),
        "l": df["low"].astype(float), "c": df["close"].astype(float),
        "tv": df.get("tick_volume", df.get("tickvol", df.get("volume", pd.Series(1, index=df.index)))).astype(float)})
    out.index = ts
    out = out[~out.index.duplicated()].sort_index()
    return out[IS_FROM:IS_TO]


def to_tf(m1, rule):
    g = m1.resample(rule, label="left", closed="left")
    b = pd.DataFrame({"o": g["o"].first(), "h": g["h"].max(), "l": g["l"].min(),
                      "c": g["c"].last(), "tv": g["tv"].sum()}).dropna()
    tr = pd.concat([b.h - b.l, (b.h - b.c.shift()).abs(), (b.l - b.c.shift()).abs()], axis=1).max(axis=1)
    b["atr"] = tr.ewm(alpha=1 / 14, adjust=False).mean()
    return b


def simulate(m1v, t_entry, side, entry, sl, spread):
    """Devuelve R realizado. side=+1 compra, -1 venta. Data en bid."""
    i0 = m1v["idx"].searchsorted(t_entry)
    if i0 >= len(m1v["idx"]) - 1:
        return None
    px = entry + spread if side > 0 else entry
    r = abs(px - sl)
    tp = px + TP_R * r if side > 0 else px - TP_R * r
    h, l = m1v["h"][i0:i0 + 3000], m1v["l"][i0:i0 + 3000]
    if side > 0:
        hit_sl, hit_tp = l <= sl, h >= tp
    else:
        hit_sl, hit_tp = h + spread >= sl, l + spread <= tp
    a = np.argmax(hit_sl) if hit_sl.any() else 10**9
    b = np.argmax(hit_tp) if hit_tp.any() else 10**9
    if a == 10**9 and b == 10**9:
        return None
    return -1.0 if a <= b else TP_R


def run(m15, m1v, k, volpct, mode, spread, rng=None):
    n = len(m15)
    o, h, l, c, tv, atr = (m15[x].values for x in ("o", "h", "l", "c", "tv", "atr"))
    idx = m15.index
    res = []
    busy_until = -1
    for i in range(max(BREAK_LB, VOL_LB) + 2, n - 1):
        if i <= busy_until:
            continue
        rg = h[i] - l[i]
        if atr[i] <= 0 or rg < k * atr[i] or rg <= 0:
            continue
        for side in (-1, 1):  # -1 impulso bajista (venta), +1 alcista (compra)
            if side < 0:
                ok = c[i] < o[i] and (o[i] - c[i]) >= IMP_BODY * rg and (c[i] - l[i]) <= IMP_CLOSE * rg \
                     and c[i] < l[i - BREAK_LB:i].min()
            else:
                ok = c[i] > o[i] and (c[i] - o[i]) >= IMP_BODY * rg and (h[i] - c[i]) <= IMP_CLOSE * rg \
                     and c[i] > h[i - BREAK_LB:i].max()
            if not ok:
                continue
            if volpct > 0 and (tv[i - VOL_LB:i] <= tv[i]).mean() * 100 < volpct:
                continue
            ob = next((j for j in range(i - 1, i - 1 - OB_BACK, -1)
                       if (c[j] > o[j] if side < 0 else c[j] < o[j])), None)
            if mode == "D0":
                tent = idx[i] + pd.Timedelta(minutes=15)
                entry = c[i]
                sl = h[i] if side < 0 else l[i]
                last = i
            else:
                if ob is None:
                    continue
                mid = (o[ob] + c[ob]) / 2
                sl = max(h[ob], h[i]) if side < 0 else min(l[ob], l[i])
                j = None
                for q in range(i + 1, min(i + 1 + PEND_BARS, n)):
                    if (side < 0 and c[q] > sl) or (side > 0 and c[q] < sl):
                        break
                    if (side < 0 and h[q] >= mid and c[q] < mid) or (side > 0 and l[q] <= mid and c[q] > mid):
                        j = q
                        break
                if j is None:
                    continue
                tent = idx[j] + pd.Timedelta(minutes=15)
                entry = c[j]
                last = j
            a = atr[i]
            sl = sl + BUF_ATR * a if side < 0 else sl - BUF_ATR * a
            dist = abs(entry - sl)
            if dist < MIN_ATR * a:
                sl = entry + MIN_ATR * a if side < 0 else entry - MIN_ATR * a
            if abs(entry - sl) > MAX_ATR * a:
                continue
            d = side if rng is None else (1 if rng.random() < 0.5 else -1)
            if d != side:  # control de azar: misma barra y mismo R, direccion aleatoria
                sl = entry + abs(entry - sl) if d < 0 else entry - abs(entry - sl)
            r_pre = simulate(m1v, tent, d, entry, sl, 0.0)
            r_net = simulate(m1v, tent, d, entry, sl, spread)
            if r_net is None:
                continue
            # R del spread en R del stop
            res.append((idx[i], d, r_pre, r_net))
            busy_until = last + 4
            break
    return pd.DataFrame(res, columns=["t", "side", "r_pre", "r_net"])


def stat(x):
    if len(x) < 2:
        return "n=%d" % len(x)
    m, s = x.mean(), x.std(ddof=1)
    ci = 1.645 * s / np.sqrt(len(x))
    return "%+.3f [%+.3f;%+.3f]" % (m, m - ci, m + ci)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--m1", required=True)
    ap.add_argument("--spread", type=float, default=5.0, help="spread en puntos de indice")
    ap.add_argument("--out", default="")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--sep", default="", help="separador del CSV (\\t, ;, ,). Vacio = autodetectar (lento)")
    a = ap.parse_args()
    m1 = load_m1(a.m1, a.sep.replace("\\t", "\t") if a.sep else None)
    m15 = to_tf(m1, "15min")
    m1v = {"idx": m1.index.values, "h": m1.h.values, "l": m1.l.values}
    lines = ["# Estudio impulso + OB (IS 2021-11 a 2024-12, spread %.1f pts)" % a.spread,
             "", "M1: %d velas, M15: %d velas" % (len(m1), len(m15)), "",
             "| k | vol | modo | n | R sin spread (IC90) | R con spread (IC90) | azar con spread | 2022 | 2023 | 2024 | compras n/R | ventas n/R |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    rng = np.random.default_rng(a.seed)
    for k, v, mode in itertools.product((1.5, 1.8, 2.2), (0, 70, 80), ("D0", "D1")):
        print("combinacion k=%.1f vol=%d %s ..." % (k, v, mode), file=sys.stderr, flush=True)
        r = run(m15, m1v, k, v, mode, a.spread)
        if r.empty:
            lines.append("| %.1f | %s | %s | 0 |" % (k, "-" if v == 0 else "P%d" % v, mode))
            continue
        z = run(m15, m1v, k, v, mode, a.spread, rng)
        yr = [r[r.t.dt.year == y].r_net.mean() if (r.t.dt.year == y).any() else float("nan") for y in (2022, 2023, 2024)]
        b, s = r[r.side > 0], r[r.side < 0]
        lines.append("| %.1f | %s | %s | %d | %s | %s | %s | %+.2f | %+.2f | %+.2f | %d/%+.2f | %d/%+.2f |" % (
            k, "-" if v == 0 else "P%d" % v, mode, len(r), stat(r.r_pre.dropna()), stat(r.r_net),
            stat(z.r_net) if len(z) else "n=0", *yr, len(b), b.r_net.mean() if len(b) else 0.0,
            len(s), s.r_net.mean() if len(s) else 0.0))
    txt = "\n".join(lines) + "\n\nCriterio de paso a MT5: n>=60, R con spread >= +0,10 y IC90 inferior > -0,05, positivo en 2022, 2023 y 2024, y mejor que el azar.\n"
    print(txt)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(txt)


if __name__ == "__main__":
    sys.exit(main())
