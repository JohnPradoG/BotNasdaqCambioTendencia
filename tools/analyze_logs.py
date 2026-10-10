#!/usr/bin/env python3
"""Informe de métricas del EA NBRL a partir de sus CSV (SPEC §13).

Lee trades.csv y signals.csv (separador ';') que escribe el EA y genera un
informe Markdown por motor y variante. Solo usa la biblioteca estándar.

Uso:
    python3 tools/analyze_logs.py --dir <carpeta con los CSV> --capital 10000 \
        [--split 2025-01-01] [--out informe.md] [--seed 1]

--capital  capital de referencia para el drawdown porcentual.
--split    fecha (NY) que separa histórico/in-sample de forward/out-of-sample;
           si se indica, se comparan ambos periodos.

El informe solo resume lo que hay en los archivos: no inventa ni extrapola.
"""
import argparse
import csv
import os
import random
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime

WEEKDAYS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]


def parse_time(s):
    s = (s or "").strip()
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None


def fnum(s, default=0.0):
    try:
        return float(str(s).replace(",", "."))
    except (TypeError, ValueError):
        return default


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, newline="", encoding="utf-8", errors="replace") as fh:
        return list(csv.DictReader(fh, delimiter=";"))


def max_drawdown(nets):
    peak = cum = dd = 0.0
    for x in nets:
        cum += x
        peak = max(peak, cum)
        dd = max(dd, peak - cum)
    return dd


def max_streak(nets):
    best = cur = 0
    for x in nets:
        cur = cur + 1 if x <= 0 else 0
        best = max(best, cur)
    return best


def bootstrap_ci(values, n_boot=2000, alpha=0.10, seed=1):
    if len(values) < 2:
        return None
    rng = random.Random(seed)
    means = []
    n = len(values)
    for _ in range(n_boot):
        means.append(sum(values[rng.randrange(n)] for _ in range(n)) / n)
    means.sort()
    lo = means[int(alpha / 2 * n_boot)]
    hi = means[int((1 - alpha / 2) * n_boot) - 1]
    return lo, hi


def fmt(x, d=2):
    return f"{x:,.{d}f}".replace(",", "_").replace(".", ",").replace("_", ".")


def summarize(trades, capital, seed):
    """Métricas de una lista de operaciones (ordenadas por cierre)."""
    nets = [fnum(t["net"]) for t in trades]
    rs = [fnum(t["result_r"]) for t in trades]
    n = len(trades)
    wins = [x for x in nets if x > 0]
    losses = [x for x in nets if x <= 0]
    gp = sum(wins)
    gl = -sum(losses)
    dd = max_drawdown(nets)
    durations = [fnum(t["duration_min"]) for t in trades]
    out = {
        "n": n,
        "win_rate": 100.0 * len(wins) / n if n else 0.0,
        "gross_profit": gp,
        "gross_loss": gl,
        "net": sum(nets),
        "pf": gp / gl if gl > 0 else float("inf") if gp > 0 else 0.0,
        "exp_money": sum(nets) / n if n else 0.0,
        "exp_r": sum(rs) / n if n else 0.0,
        "dd_money": dd,
        "dd_pct": 100.0 * dd / capital if capital else 0.0,
        "avg_duration": statistics.mean(durations) if durations else 0.0,
        "avg_win": statistics.mean(wins) if wins else 0.0,
        "avg_loss": statistics.mean(losses) if losses else 0.0,
        "max_loss_streak": max_streak(nets),
        "mfe_r_mean": statistics.mean([fnum(t["mfe_r"]) for t in trades]) if n else 0.0,
        "mae_r_mean": statistics.mean([fnum(t["mae_r"]) for t in trades]) if n else 0.0,
        "commission": sum(fnum(t["commission"]) for t in trades),
        "swap": sum(fnum(t["swap"]) for t in trades),
        "slippage_pts_mean": statistics.mean([fnum(t["slippage_points"]) for t in trades]) if n else 0.0,
        "spread_pts_mean": statistics.mean([fnum(t["spread_open_points"]) for t in trades]) if n else 0.0,
        "ci": bootstrap_ci(rs, seed=seed),
    }
    # concentración: ¿depende de unas pocas operaciones extraordinarias?
    if n:
        srt = sorted(nets, reverse=True)
        k5 = max(1, int(round(0.05 * n)))
        k10 = max(1, int(round(0.10 * n)))
        out["top5_share"] = 100.0 * sum(srt[:k5]) / gp if gp > 0 else 0.0
        out["top10_share"] = 100.0 * sum(srt[:k10]) / gp if gp > 0 else 0.0
        rs_sorted = sorted(rs, reverse=True)
        rest = rs_sorted[k5:]
        out["exp_r_without_top5"] = sum(rest) / len(rest) if rest else 0.0
        out["median_r"] = statistics.median(rs)
    return out


def group_table(trades, keyfunc, title):
    groups = defaultdict(list)
    for t in trades:
        groups[keyfunc(t)].append(t)
    lines = [f"\n**{title}**\n", "| Grupo | Ops | Aciertos | Neto | Expectativa R |", "|---|---|---|---|---|"]
    for k in sorted(groups, key=lambda x: str(x)):
        g = groups[k]
        nets = [fnum(t["net"]) for t in g]
        rs = [fnum(t["result_r"]) for t in g]
        w = sum(1 for x in nets if x > 0)
        lines.append(f"| {k} | {len(g)} | {fmt(100.0 * w / len(g), 1)} % | {fmt(sum(nets))} | {fmt(sum(rs) / len(g), 3)} |")
    return "\n".join(lines)


def metrics_block(m):
    ci = m["ci"]
    ci_txt = f"[{fmt(ci[0], 3)} ; {fmt(ci[1], 3)}]" if ci else "n/d (menos de 2 operaciones)"
    pf = "∞" if m["pf"] == float("inf") else fmt(m["pf"])
    rows = [
        ("Operaciones", str(m["n"])),
        ("Aciertos", f"{fmt(m['win_rate'], 1)} %"),
        ("Beneficio bruto", fmt(m["gross_profit"])),
        ("Pérdida bruta", fmt(m["gross_loss"])),
        ("Beneficio neto (tras comisión y swap)", fmt(m["net"])),
        ("Profit factor", pf),
        ("Expectativa por operación", fmt(m["exp_money"])),
        ("Expectativa en R", fmt(m["exp_r"], 3)),
        ("IC 90 % bootstrap de la expectativa en R", ci_txt),
        ("Mediana en R", fmt(m.get("median_r", 0.0), 3)),
        ("Drawdown máximo", f"{fmt(m['dd_money'])} ({fmt(m['dd_pct'])} %)"),
        ("Duración media (min)", fmt(m["avg_duration"], 1)),
        ("Ganancia media / pérdida media", f"{fmt(m['avg_win'])} / {fmt(m['avg_loss'])}"),
        ("Mayor racha de pérdidas", str(m["max_loss_streak"])),
        ("MFE medio / MAE medio (R)", f"{fmt(m['mfe_r_mean'], 2)} / {fmt(m['mae_r_mean'], 2)}"),
        ("Comisión total / swap total", f"{fmt(m['commission'])} / {fmt(m['swap'])}"),
        ("Spread medio a la entrada / deslizamiento medio (puntos)",
         f"{fmt(m['spread_pts_mean'], 1)} / {fmt(m['slippage_pts_mean'], 1)}"),
        ("Peso del 5 % / 10 % mejor en el beneficio bruto",
         f"{fmt(m.get('top5_share', 0.0), 1)} % / {fmt(m.get('top10_share', 0.0), 1)} %"),
        ("Expectativa en R sin el 5 % mejor", fmt(m.get("exp_r_without_top5", 0.0), 3)),
    ]
    out = ["| Métrica | Valor |", "|---|---|"]
    out += [f"| {a} | {b} |" for a, b in rows]
    return "\n".join(out)


def report(trades, signals, capital, split, seed):
    lines = ["# Informe NBRL", ""]
    lines.append(f"Generado: {datetime.now():%Y-%m-%d %H:%M}. Operaciones leídas: {len(trades)}. "
                 f"Señales leídas: {len(signals)}.")
    lines.append("")
    lines.append("Todas las cifras salen de los CSV del EA; no hay extrapolaciones. "
                 "El porcentaje de aciertos no es una medida de calidad por sí solo.")
    if not trades:
        lines.append("\n**No hay operaciones cerradas en trades.csv.**")

    trades = sorted(trades, key=lambda t: parse_time(t["close_server_time"]) or datetime.min)
    by_var = defaultdict(list)
    for t in trades:
        by_var[t["variant"]].append(t)

    for var in sorted(by_var):
        tv = by_var[var]
        m = summarize(tv, capital, seed)
        lines.append(f"\n## Variante {var} (motor {tv[0]['engine']})\n")
        lines.append(metrics_block(m))
        if m["n"] and m.get("top5_share", 0) > 50:
            lines.append("\n> Aviso: más de la mitad del beneficio bruto viene del 5 % de operaciones; "
                         "el resultado depende de pocas operaciones extraordinarias.")

        def ny_open(t):
            return parse_time(t["open_ny_time"]) or parse_time(t["open_server_time"])

        lines.append(group_table(tv, lambda t: (f"{ny_open(t).weekday() + 1}-{WEEKDAYS[ny_open(t).weekday()]}" if ny_open(t) else "?"),
                                 "Por día de la semana (hora NY)"))
        lines.append(group_table(
            tv, lambda t: (f"{ny_open(t).hour:02d}:{0 if ny_open(t).minute < 30 else 30:02d}" if ny_open(t) else "?"),
            "Por franja de 30 min (hora NY de entrada)"))
        lines.append(group_table(tv, lambda t: t.get("time_block") or "?", "Por bloque horario"))
        lines.append(group_table(tv, lambda t: t.get("regime") or "?",
                                 "Por régimen (tendencia / consolidación / mixto)"))
        lines.append(group_table(tv, lambda t: t["direction"], "Compras frente a ventas"))
        lines.append(group_table(tv, lambda t: t.get("exit_reason") or "?", "Por motivo de salida"))
        if split:
            lines.append(group_table(
                tv, lambda t: ("histórico" if (ny_open(t) and ny_open(t) < split) else "forward"),
                f"Histórico frente a forward (corte {split:%Y-%m-%d})"))

    # embudo de señales
    if signals:
        lines.append("\n## Embudo de señales\n")
        by_var_status = defaultdict(Counter)
        reasons = defaultdict(Counter)
        for s in signals:
            by_var_status[s["variant"]][s["status"]] += 1
            if s["status"] == "REJECTED":
                reasons[s["variant"]][s.get("reject_reason") or "?"] += 1
        lines.append("| Variante | Detectadas | Ejecutadas | Rechazadas | Solo análisis | Error |")
        lines.append("|---|---|---|---|---|---|")
        for v in sorted(by_var_status):
            c = by_var_status[v]
            lines.append(f"| {v} | {sum(c.values())} | {c['EXECUTED']} | {c['REJECTED']} | "
                         f"{c['ANALYSIS_ONLY']} | {c['ERROR']} |")
        for v in sorted(reasons):
            lines.append(f"\n**Motivos de rechazo {v}**\n")
            lines.append("| Motivo | Señales |")
            lines.append("|---|---|")
            for r, k in reasons[v].most_common():
                lines.append(f"| {r} | {k} |")
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", required=True, help="carpeta con trades.csv y signals.csv")
    ap.add_argument("--capital", type=float, required=True, help="capital de referencia para el DD %%")
    ap.add_argument("--split", help="fecha YYYY-MM-DD que separa histórico y forward")
    ap.add_argument("--out", help="archivo Markdown de salida (por defecto, pantalla)")
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args(argv)
    split = datetime.strptime(a.split, "%Y-%m-%d") if a.split else None
    trades = read_csv(os.path.join(a.dir, "trades.csv"))
    signals = read_csv(os.path.join(a.dir, "signals.csv"))
    text = report(trades, signals, a.capital, split, a.seed)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"Informe escrito en {a.out}")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
