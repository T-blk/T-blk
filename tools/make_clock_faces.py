#!/usr/bin/env python3
"""Sinh 720 mặt đồng hồ kim (mỗi phút một ảnh, 12 giờ) cho kiểu giờ "kim".

    python3 tools/make_clock_faces.py kindle/dashboard/clock 210
"""
import math
import os
import sys

from PIL import Image, ImageDraw

out = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard/clock"
size = int(sys.argv[2]) if len(sys.argv) > 2 else 210
SS = 4                                   # vẽ lớn rồi thu nhỏ cho mịn
S = size * SS
c = S / 2
os.makedirs(out, exist_ok=True)


def hand(d, angle_deg, length, width, tail=0.0):
    a = math.radians(angle_deg - 90)
    x2, y2 = c + math.cos(a) * length, c + math.sin(a) * length
    x1, y1 = c - math.cos(a) * tail, c - math.sin(a) * tail
    d.line((x1, y1, x2, y2), fill=0, width=int(width))
    r = width / 2
    d.ellipse((x2 - r, y2 - r, x2 + r, y2 + r), fill=0)


face = Image.new("L", (S, S), 255)
d = ImageDraw.Draw(face)
R = S / 2 - 3 * SS
d.ellipse((c - R, c - R, c + R, c + R), outline=0, width=4 * SS)
for i in range(60):
    a = math.radians(i * 6 - 90)
    major = i % 5 == 0
    r1 = R - (22 if i % 15 == 0 else 16 if major else 7) * SS
    w = (6 if i % 15 == 0 else 4 if major else 2) * SS
    d.line((c + math.cos(a) * r1, c + math.sin(a) * r1,
            c + math.cos(a) * (R - 8 * SS), c + math.sin(a) * (R - 8 * SS)), fill=0 if major else 90, width=w)

for h in range(12):
    for m in range(60):
        img = face.copy()
        d = ImageDraw.Draw(img)
        hand(d, (h + m / 60) * 30, R * 0.52, 12 * SS, tail=R * 0.08)
        hand(d, m * 6, R * 0.80, 7 * SS, tail=R * 0.10)
        d.ellipse((c - 9 * SS, c - 9 * SS, c + 9 * SS, c + 9 * SS), fill=0)
        d.ellipse((c - 3 * SS, c - 3 * SS, c + 3 * SS, c + 3 * SS), fill=255)
        img.resize((size, size), Image.LANCZOS).save(os.path.join(out, f"{h:02d}{m:02d}.png"), optimize=True)
print(f"Xong 720 mặt đồng hồ {size}x{size} -> {out}")
