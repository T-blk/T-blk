#!/usr/bin/env python3
"""Kindle dashboard server.

Renders a grayscale PNG sized for the Kindle Paperwhite 2 (758x1024) and
serves it at /dashboard.png. The Kindle fetches it periodically and draws it
with `eips`.

Usage:
    python3 dashboard_server.py                 # serve on config port
    python3 dashboard_server.py --render out.png  # render once (preview)
"""
import argparse
import datetime as dt
import json
import os
import sys
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from zoneinfo import ZoneInfo

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
WEEKDAYS_VI = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
WEATHER_CODES = {
    0: "Trời quang", 1: "Ít mây", 2: "Mây rải rác", 3: "Nhiều mây",
    45: "Sương mù", 48: "Sương mù", 51: "Mưa phùn nhẹ", 53: "Mưa phùn",
    55: "Mưa phùn dày", 61: "Mưa nhẹ", 63: "Mưa vừa", 65: "Mưa to",
    80: "Mưa rào nhẹ", 81: "Mưa rào", 82: "Mưa rào to", 95: "Dông",
    96: "Dông, mưa đá", 99: "Dông, mưa đá",
}


def load_config(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


FONT_CANDIDATES = {
    False: ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/Library/Fonts/Arial.ttf"],
    True: ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
           "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
           "/Library/Fonts/Arial Bold.ttf"],
}


def font(cfg, size, bold=False):
    """Config font first, then common Linux/macOS fonts with Vietnamese glyphs."""
    paths = [cfg.get("font_bold" if bold else "font_regular")] + FONT_CANDIDATES[bold]
    for path in paths:
        if path and os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def fetch_weather(cfg):
    w = cfg.get("weather") or {}
    if not w.get("enabled"):
        return None
    q = urllib.parse.urlencode({
        "latitude": w["latitude"], "longitude": w["longitude"],
        "current": "temperature_2m,relative_humidity_2m,weather_code",
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
        "timezone": cfg.get("timezone", "auto"), "forecast_days": 1,
    })
    try:
        with urllib.request.urlopen(f"https://api.open-meteo.com/v1/forecast?{q}", timeout=8) as r:
            d = json.load(r)
        cur, day = d["current"], d["daily"]
        return {
            "city": w.get("city", ""),
            "temp": round(cur["temperature_2m"]),
            "humidity": cur["relative_humidity_2m"],
            "desc": WEATHER_CODES.get(cur["weather_code"], "—"),
            "tmax": round(day["temperature_2m_max"][0]),
            "tmin": round(day["temperature_2m_min"][0]),
            "rain": day["precipitation_probability_max"][0],
        }
    except Exception as e:  # network down: still render the rest
        print(f"weather error: {e}", file=sys.stderr)
        return None


def read_todos(cfg):
    path = os.path.join(HERE, cfg.get("todo_file", "todo.txt"))
    try:
        with open(path, encoding="utf-8") as f:
            return [l.strip() for l in f if l.strip() and not l.startswith("#")]
    except OSError:
        return []


def render(cfg, battery=None):
    W, H = cfg.get("width", 758), cfg.get("height", 1024)
    img = Image.new("L", (W, H), 255)
    d = ImageDraw.Draw(img)
    now = dt.datetime.now(ZoneInfo(cfg.get("timezone", "UTC")))
    m = 40  # margin

    # Header
    d.text((m, 30), cfg.get("title", ""), font=font(cfg, 30, True), fill=0)
    status = f"Cập nhật {now:%H:%M}"
    if battery is not None:
        status += f"  ·  Pin {battery}%"
    sf = font(cfg, 22)
    d.text((W - m - d.textlength(status, font=sf), 36), status, font=sf, fill=80)
    d.line((m, 80, W - m, 80), fill=0, width=3)

    # Clock & date
    d.text((m, 95), f"{now:%H:%M}", font=font(cfg, 170, True), fill=0)
    d.text((m, 300), f"{WEEKDAYS_VI[now.weekday()]}, {now:%d/%m/%Y}", font=font(cfg, 38), fill=0)

    y = 370
    d.line((m, y, W - m, y), fill=160, width=2)

    # Weather
    wx = fetch_weather(cfg)
    y += 20
    if wx:
        d.text((m, y), wx["city"], font=font(cfg, 26), fill=80)
        d.text((m, y + 35), f"{wx['temp']}°C", font=font(cfg, 96, True), fill=0)
        info = [wx["desc"], f"Cao {wx['tmax']}° / Thấp {wx['tmin']}°",
                f"Độ ẩm {wx['humidity']}%", f"Khả năng mưa {wx['rain']}%"]
        for i, line in enumerate(info):
            d.text((380, y + 30 + i * 36), line, font=font(cfg, 28), fill=0)
        y += 190
    else:
        d.text((m, y), "Không lấy được thời tiết", font=font(cfg, 26), fill=80)
        y += 50

    d.line((m, y, W - m, y), fill=160, width=2)

    # Todos
    y += 20
    d.text((m, y), "Việc hôm nay", font=font(cfg, 32, True), fill=0)
    y += 55
    tf = font(cfg, 30)
    for item in read_todos(cfg)[:8]:
        d.rectangle((m, y + 6, m + 24, y + 30), outline=0, width=3)
        d.text((m + 42, y), item, font=tf, fill=0)
        y += 50

    # Footer quote
    if cfg.get("quote"):
        qf = font(cfg, 24)
        q = f"“{cfg['quote']}”"
        d.text(((W - d.textlength(q, font=qf)) / 2, H - 60), q, font=qf, fill=80)

    return img


def png_bytes(img):
    buf = BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def make_handler(cfg_path):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path != "/dashboard.png":
                self.send_error(404)
                return
            qs = urllib.parse.parse_qs(url.query)
            batt = qs.get("battery", [None])[0]
            batt = int(batt) if batt and batt.isdigit() else None
            body = png_bytes(render(load_config(cfg_path), batt))
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=os.path.join(HERE, "config.json"))
    ap.add_argument("--render", metavar="OUT.png", help="render once and exit")
    ap.add_argument("--battery", type=int)
    a = ap.parse_args()
    if not os.path.exists(a.config):
        a.config = os.path.join(HERE, "config.example.json")
    cfg = load_config(a.config)
    if a.render:
        render(cfg, a.battery).save(a.render)
        print(f"wrote {a.render}")
        return
    port = cfg.get("port", 8080)
    print(f"serving http://0.0.0.0:{port}/dashboard.png (config: {a.config})")
    ThreadingHTTPServer(("0.0.0.0", port), make_handler(a.config)).serve_forever()


if __name__ == "__main__":
    main()
