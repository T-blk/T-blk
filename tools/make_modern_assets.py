#!/usr/bin/env python3
"""Ảnh dựng sẵn cho giao diện hiện đại:
  clockm/HHMM.png  720 mặt đồng hồ kim tối giản (180 px)
  ring/MM.png      60 vòng phút (180 px, giữa để trắng cho chữ giờ)
  ui/bg_the.png    nền xám + 4 thẻ trắng bo góc cho bố cục "Thẻ"

    python3 tools/make_modern_assets.py kindle/dashboard
"""
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard"
SS = 4
INK, SOFT, HAIR, CARD = 0, 150, 205, 238


def save(im, path):
    im = im.resize((im.width // SS, im.height // SS), Image.LANCZOS)
    im.quantize(16).convert("L").save(path, "PNG", optimize=True)


def analog(size=180):
    out = os.path.join(ROOT, "clockm")
    os.makedirs(out, exist_ok=True)
    S = size * SS
    c = S / 2
    R = S / 2 - 3 * SS
    face = Image.new("L", (S, S), 255)
    d = ImageDraw.Draw(face)
    for k in range(60):
        a = math.radians(k * 6 - 90)
        big = k % 5 == 0
        r1 = R - (15 if big else 6) * SS
        d.line((c + math.cos(a) * r1, c + math.sin(a) * r1, c + math.cos(a) * R, c + math.sin(a) * R),
               fill=INK if big else SOFT, width=(3 if big else 1) * SS)
    for h in range(12):
        for m in range(60):
            im = face.copy()
            d = ImageDraw.Draw(im)
            for ang, L, wd in (((h + m / 60) * 30, R * 0.52, 6), (m * 6, R * 0.80, 3)):
                a = math.radians(ang - 90)
                x2, y2 = c + math.cos(a) * L, c + math.sin(a) * L
                d.line((c, c, x2, y2), fill=INK, width=wd * SS)
                rr = wd * SS / 2
                d.ellipse((x2 - rr, y2 - rr, x2 + rr, y2 + rr), fill=INK)
            d.ellipse((c - 5 * SS, c - 5 * SS, c + 5 * SS, c + 5 * SS), fill=INK)
            save(im, os.path.join(out, f"{h:02d}{m:02d}.png"))


def rings(size=180):
    out = os.path.join(ROOT, "ring")
    os.makedirs(out, exist_ok=True)
    S = size * SS
    w = 10 * SS
    box = (w / 2 + SS, w / 2 + SS, S - w / 2 - SS, S - w / 2 - SS)
    for m in range(60):
        im = Image.new("L", (S, S), 255)
        d = ImageDraw.Draw(im)
        d.ellipse(box, outline=HAIR, width=w)
        if m:
            d.arc(box, -90, -90 + m * 6, fill=INK, width=w)
        save(im, os.path.join(out, f"{m:02d}.png"))


def bg_the():
    W, H = 758, 1024
    im = Image.new("L", (W * SS, H * SS), CARD)
    d = ImageDraw.Draw(im)
    for x, y, w, h in ((28, 84, 702, 250), (28, 354, 341, 250), (389, 354, 341, 250), (28, 624, 702, 380)):
        d.rounded_rectangle((x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1), radius=26 * SS, fill=255)
    os.makedirs(os.path.join(ROOT, "ui"), exist_ok=True)
    save(im, os.path.join(ROOT, "ui", "bg_the.png"))


if __name__ == "__main__":
    bg_the()
    rings()
    analog()
    print("ok")
