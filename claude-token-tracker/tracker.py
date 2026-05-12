#!/usr/bin/env python3
"""Claude Code token usage tracker — reads local session files, no API key needed.

Usage:
  python tracker.py            # show progress bar, exit
  python tracker.py --notify   # show progress bar + push ntfy notification
  python tracker.py watch      # live-updating loop (for tmux pane)
  python tracker.py serve      # HTTP server for iOS Shortcut
"""

import sys
import os
import json
import time
import glob
import datetime
import argparse
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

try:
    import tomllib
except ImportError:
    import tomli as tomllib

import requests
from rich.console import Console

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
CONFIG_FILE  = SCRIPT_DIR / "config.toml"
CACHE_FILE   = Path.home() / ".claude" / "token-tracker-cache.json"
SESSIONS_DIR = Path.home() / ".claude" / "projects"
CACHE_TTL    = 60  # seconds

# ── Config ────────────────────────────────────────────────────────────────────
def load_config() -> dict:
    cfg = {}
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, "rb") as f:
            cfg = tomllib.load(f)
    cfg.setdefault("budget", {})
    cfg["budget"].setdefault("monthly_tokens", 5_000_000)
    cfg.setdefault("ntfy", {})
    cfg["ntfy"].setdefault("topic", "ofer-claude-gd")
    cfg["ntfy"].setdefault("server", "https://ntfy.sh")
    cfg.setdefault("server", {})
    cfg["server"].setdefault("port", 8765)
    return cfg


# ── Local JSONL parsing ───────────────────────────────────────────────────────
def parse_sessions() -> dict:
    """Scan all ~/.claude/projects/**/*.jsonl and aggregate token usage."""
    now         = datetime.datetime.now(datetime.timezone.utc)
    today       = now.date()
    month_start = today.replace(day=1)
    yesterday   = today - datetime.timedelta(days=1)

    monthly_input  = monthly_output  = 0
    today_input    = today_output    = 0
    yest_input     = yest_output     = 0
    today_cache_read = today_cache_write_5m = today_cache_write_1h = 0
    today_messages = 0
    today_cost = 0.0
    monthly_sessions: set = set()
    today_sessions:   set = set()
    daily_tokens: dict[datetime.date, int] = {}

    pattern = str(SESSIONS_DIR / "**" / "*.jsonl")
    for path in glob.iglob(pattern, recursive=True):
        try:
            with open(path, encoding="utf-8", errors="ignore") as fh:
                for raw in fh:
                    raw = raw.strip()
                    if not raw:
                        continue
                    try:
                        d = json.loads(raw)
                    except json.JSONDecodeError:
                        continue

                    if d.get("type") != "assistant":
                        continue

                    ts_str = d.get("timestamp", "")
                    if not ts_str:
                        continue
                    try:
                        ts = datetime.datetime.fromisoformat(
                            ts_str.replace("Z", "+00:00")
                        ).date()
                    except ValueError:
                        continue

                    if ts < month_start:
                        continue

                    msg    = d.get("message", {}) or {}
                    usage  = msg.get("usage", {}) or {}
                    model  = msg.get("model", "") or ""
                    inp    = usage.get("input_tokens", 0) or 0
                    out    = usage.get("output_tokens", 0) or 0
                    c_read = usage.get("cache_read_input_tokens", 0) or 0
                    cc     = usage.get("cache_creation", {}) or {}
                    c_w5m  = cc.get("ephemeral_5m_input_tokens", 0) or 0
                    c_w1h  = cc.get("ephemeral_1h_input_tokens", 0) or 0
                    if not (c_w5m or c_w1h):
                        c_w5m = usage.get("cache_creation_input_tokens", 0) or 0
                    total  = inp + out
                    sid    = d.get("sessionId", "")

                    monthly_input  += inp
                    monthly_output += out
                    daily_tokens[ts] = daily_tokens.get(ts, 0) + total
                    if sid:
                        monthly_sessions.add(sid)

                    if ts == today:
                        today_input  += inp
                        today_output += out
                        today_cache_read += c_read
                        today_cache_write_5m += c_w5m
                        today_cache_write_1h += c_w1h
                        today_messages += 1
                        today_cost += compute_cost(model, inp, out, c_read, c_w5m, c_w1h)
                        if sid:
                            today_sessions.add(sid)
                    elif ts == yesterday:
                        yest_input  += inp
                        yest_output += out

        except OSError:
            continue

    days_elapsed = max((today - month_start).days, 1)
    monthly_total = monthly_input + monthly_output
    daily_avg = monthly_total // days_elapsed

    return {
        "monthly_input":    monthly_input,
        "monthly_output":   monthly_output,
        "monthly_tokens":   monthly_total,
        "today_input":      today_input,
        "today_output":     today_output,
        "today_tokens":     today_input + today_output,
        "yesterday_tokens": yest_input + yest_output,
        "daily_avg":        daily_avg,
        "days_elapsed":     days_elapsed,
        "monthly_sessions": len(monthly_sessions),
        "today_sessions":   len(today_sessions),
        "today_cache_read":     today_cache_read,
        "today_cache_write_5m": today_cache_write_5m,
        "today_cache_write_1h": today_cache_write_1h,
        "today_messages":   today_messages,
        "today_cost":       round(today_cost, 2),
    }


# ── Pricing (USD per 1M tokens) ───────────────────────────────────────────────
PRICING = {
    "opus":   {"in": 15.0, "out": 75.0, "cache_read": 1.50, "cache_w_5m": 18.75, "cache_w_1h": 30.0},
    "sonnet": {"in":  3.0, "out": 15.0, "cache_read": 0.30, "cache_w_5m":  3.75, "cache_w_1h":  6.0},
    "haiku":  {"in":  1.0, "out":  5.0, "cache_read": 0.10, "cache_w_5m":  1.25, "cache_w_1h":  2.0},
}

def model_family(model: str) -> str:
    m = (model or "").lower()
    if "opus"   in m: return "opus"
    if "haiku"  in m: return "haiku"
    return "sonnet"  # default

def compute_cost(model: str, inp: int, out: int, c_read: int, c_w5m: int, c_w1h: int) -> float:
    p = PRICING[model_family(model)]
    return (
        inp    * p["in"]         +
        out    * p["out"]        +
        c_read * p["cache_read"] +
        c_w5m  * p["cache_w_5m"] +
        c_w1h  * p["cache_w_1h"]
    ) / 1_000_000


def get_stats(cfg: dict) -> dict:
    """Return stats dict, using cache if fresh."""
    if CACHE_FILE.exists():
        try:
            cached = json.loads(CACHE_FILE.read_text())
            if time.time() - cached.get("_ts", 0) < CACHE_TTL:
                return cached
        except Exception:
            pass

    usage = parse_sessions()

    stats = {
        "_ts":   time.time(),
        "month": datetime.date.today().strftime("%B %Y"),
        **usage,
    }

    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(stats, indent=2))
    return stats


# ── Display ───────────────────────────────────────────────────────────────────
def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.1f}K"
    return str(n)


def day_pct(today: int, avg: int) -> float:
    """today / daily_avg * 100"""
    return today / avg * 100 if avg else 0.0


def pct_color(pct: float) -> str:
    if pct >= 150:
        return "bold red"
    if pct >= 100:
        return "bold yellow"
    return "bold green"


def print_stats(stats: dict, console: Console):
    console.print(" [bold]Today:[/]")
    console.print(f" Cost: [bold green]${stats['today_cost']:.2f}[/]")
    console.print(f" Input Tokens: [bold]{stats['today_input']:,}[/]")
    console.print(f" Output Tokens: [bold]{stats['today_output']:,}[/]")
    console.print(f" Messages: [bold]{stats['today_messages']:,}[/]")
    console.print()


# ── ntfy notification ─────────────────────────────────────────────────────────
def send_ntfy(stats: dict, cfg: dict):
    topic  = cfg["ntfy"]["topic"]
    server = cfg["ntfy"]["server"].rstrip("/")

    title   = "Claude Usage — Today"
    message = (
        f"Cost: ${stats['today_cost']:.2f} · "
        f"In: {stats['today_input']:,} · "
        f"Out: {stats['today_output']:,} · "
        f"Msgs: {stats['today_messages']:,}"
    )

    try:
        requests.post(
            f"{server}/{topic}",
            data=message.encode(),
            headers={
                "Title":    title,
                "Priority": "default",
                "Sound":    "pristine",
            },
            timeout=8,
        )
    except Exception as exc:
        print(f"ntfy error: {exc}", file=sys.stderr)


# ── HTTP server (iOS Shortcut) ────────────────────────────────────────────────
def make_handler(cfg: dict):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path == "/push":
                stats = get_stats(cfg)
                send_ntfy(stats, cfg)
                body = json.dumps({"ok": True, "pct": stats.get("pct_tokens", 0)}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)
            elif self.path == "/stats":
                stats = get_stats(cfg)
                body  = json.dumps(stats, indent=2).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(404)
                self.end_headers()

    return Handler


def run_server(cfg: dict):
    port    = cfg["server"]["port"]
    handler = make_handler(cfg)
    httpd   = HTTPServer(("0.0.0.0", port), handler)
    print(f"Token tracker server on http://0.0.0.0:{port}  (/push  /stats)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


# ── Watch mode (tmux pane) ────────────────────────────────────────────────────
WATCH_INTERVAL = 30

def watch_mode(cfg: dict):
    console = Console()
    while True:
        console.clear()
        now_str = datetime.datetime.now().strftime("%H:%M:%S")
        console.print(f" [dim]live · {now_str}[/]")
        print_stats(get_stats(cfg), console)
        time.sleep(WATCH_INTERVAL)


# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("cmd", nargs="?", default="show")
    parser.add_argument("--notify", action="store_true")
    args = parser.parse_args()

    cfg     = load_config()
    console = Console()

    if args.cmd == "serve":
        run_server(cfg)
        return

    if args.cmd == "watch":
        watch_mode(cfg)
        return

    stats = get_stats(cfg)
    print_stats(stats, console)

    if args.notify or args.cmd == "notify":
        send_ntfy(stats, cfg)


if __name__ == "__main__":
    main()
