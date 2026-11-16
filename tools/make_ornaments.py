#!/usr/bin/env python3
"""Sinh dải hoa văn trang trí hai bên màn hình cho từng dịp lễ (PNG thang xám cho eips).

    python3 tools/make_ornaments.py kindle/dashboard/ornaments

Mỗi chủ đề tạo 4 file: <chude>_doc_l.png, <chude>_doc_r.png (26x1024), <chude>_ngang_l.png, <chude>_ngang_r.png (26x758).
"""
import math
import os
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard/ornaments"
SW = 26           # bề rộng dải
SS = 4            # vẽ lớn rồi thu nhỏ cho mịn
os.makedirs(OUT, exist_ok=True)


class Pen:
    def __init__(self, h, gray=0):
        self.img = Image.new("L", (SW * SS, h * SS), 255)
        self.d = ImageDraw.Draw(self.img)
        self.g = gray

    def S(self, v):
        return v * SS

    def line(self, pts, w=1.2, g=None):
        self.d.line([(self.S(x), self.S(y)) for x, y in pts], fill=self.g if g is None else g, width=max(1, int(w * SS)), joint="curve")

    def circle(self, cx, cy, r, w=1.2, fill=None, g=None):
        c = self.g if g is None else g
        self.d.ellipse((self.S(cx - r), self.S(cy - r), self.S(cx + r), self.S(cy + r)),
                       outline=c, width=max(1, int(w * SS)), fill=(c if fill else None))

    def poly(self, pts, w=1.2, fill=False, g=None):
        c = self.g if g is None else g
        P = [(self.S(x), self.S(y)) for x, y in pts]
        if fill:
            self.d.polygon(P, fill=c)
        else:
            self.d.line(P + [P[0]], fill=c, width=max(1, int(w * SS)), joint="curve")

    def done(self, h):
        return self.img.resize((SW, h), Image.LANCZOS)


# ---------------- hoạ tiết (tâm ở cx=13, cy) ----------------
C = SW / 2


def flower5(p, cy, r=4.2, filled=False):
    for k in range(5):
        a = math.radians(k * 72 - 90)
        p.circle(C + math.cos(a) * r * 1.15, cy + math.sin(a) * r * 1.15, r, w=1.1, fill=filled)
    p.circle(C, cy, 1.6, fill=True)
    for k in range(5):
        a = math.radians(k * 72 - 54)
        p.line([(C, cy), (C + math.cos(a) * 2.8, cy + math.sin(a) * 2.8)], w=0.6)


def bud(p, cy):
    p.circle(C, cy, 2.6, w=1.1)
    p.line([(C, cy + 2.6), (C, cy + 5)], w=0.9)


def heart(p, cy, s=1.0, fill=False):
    pts = []
    for t in range(0, 360, 10):
        a = math.radians(t)
        x = 16 * math.sin(a) ** 3
        y = -(13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a))
        pts.append((C + x * 0.55 * s, cy + y * 0.55 * s))
    p.poly(pts, w=1.2, fill=fill)


def star(p, cy, r=8, fill=False):
    pts = []
    for k in range(10):
        rr = r if k % 2 == 0 else r * 0.42
        a = math.radians(k * 36 - 90)
        pts.append((C + math.cos(a) * rr, cy + math.sin(a) * rr))
    p.poly(pts, w=1.1, fill=fill)


def diamond(p, cy, r=7):
    p.poly([(C, cy - r), (C + r * 0.75, cy), (C, cy + r), (C - r * 0.75, cy)], w=1.1)
    p.poly([(C, cy - r * 0.45), (C + r * 0.33, cy), (C, cy + r * 0.45), (C - r * 0.33, cy)], w=0.8)


def dot(p, cy, r=1.3):
    p.circle(C, cy, r, fill=True)


def lantern(p, cy):
    p.line([(C, cy - 13), (C, cy - 9)], w=0.8)
    p.d.rounded_rectangle((p.S(C - 7), p.S(cy - 8), p.S(C + 7), p.S(cy + 7)), radius=p.S(6), outline=p.g, width=int(1.3 * SS))
    for dx in (-3.5, 0, 3.5):
        p.line([(C + dx, cy - 7.5), (C + dx * 1.2, cy), (C + dx, cy + 6.5)], w=0.6)
    p.line([(C - 4, cy - 8), (C + 4, cy - 8)], w=1.6)
    p.line([(C - 4, cy + 7), (C + 4, cy + 7)], w=1.6)
    for dx in (-1.5, 0, 1.5):
        p.line([(C + dx, cy + 7), (C + dx * 1.4, cy + 12)], w=0.6)


def moon(p, cy, r=7):
    p.circle(C, cy, r, fill=True)
    p.circle(C + 3.6, cy - 2.4, r * 0.85, fill=True, g=255)


def snowflake(p, cy, r=8):
    for k in range(6):
        a = math.radians(k * 60)
        x2, y2 = C + math.cos(a) * r, cy + math.sin(a) * r
        p.line([(C, cy), (x2, y2)], w=1.0)
        for s in (0.55,):
            bx, by = C + math.cos(a) * r * s, cy + math.sin(a) * r * s
            for da in (-40, 40):
                b = math.radians(k * 60 + da)
                p.line([(bx, by), (bx + math.cos(b) * 3, by + math.sin(b) * 3)], w=0.8)


def tree(p, cy):
    for i, (w, y) in enumerate(((5, -9), (7.5, -4), (10, 1))):
        p.poly([(C, cy + y - 4), (C + w, cy + y + 4), (C - w, cy + y + 4)], w=1.1)
    p.line([(C, cy + 5), (C, cy + 9)], w=1.6)


def lotus(p, cy):
    def petal(ax, ay, ang, L=10, Wd=3.6):
        a = math.radians(ang)
        tip = (ax + math.cos(a) * L, ay + math.sin(a) * L)
        nx, ny = -math.sin(a), math.cos(a)
        mid = (ax + math.cos(a) * L * 0.5, ay + math.sin(a) * L * 0.5)
        p.poly([(ax, ay), (mid[0] + nx * Wd, mid[1] + ny * Wd), tip, (mid[0] - nx * Wd, mid[1] - ny * Wd)], w=1.0)
    base = cy + 6
    for ang in (-90, -125, -55, -155, -25):
        petal(C, base, ang, L=11 if ang == -90 else 9)
    p.line([(C - 9, base + 1), (C + 9, base + 1)], w=1.0)


def book(p, cy):
    p.poly([(C, cy - 5), (C - 10, cy - 7), (C - 10, cy + 6), (C, cy + 8)], w=1.1)
    p.poly([(C, cy - 5), (C + 10, cy - 7), (C + 10, cy + 6), (C, cy + 8)], w=1.1)
    for k in (-2, 1, 4):
        p.line([(C - 8, cy + k - 2), (C - 2, cy + k - 1)], w=0.5)
        p.line([(C + 2, cy + k - 1), (C + 8, cy + k - 2)], w=0.5)


def balloon(p, cy):
    p.d.ellipse((p.S(C - 6), p.S(cy - 10), p.S(C + 6), p.S(cy + 4)), outline=p.g, width=int(1.2 * SS))
    p.poly([(C, cy + 4), (C - 1.5, cy + 6), (C + 1.5, cy + 6)], fill=True)
    p.line([(C, cy + 6), (C + 2, cy + 9), (C - 1, cy + 12)], w=0.6)


def firework(p, cy, r=9):
    for k in range(12):
        a = math.radians(k * 30)
        p.line([(C + math.cos(a) * r * 0.35, cy + math.sin(a) * r * 0.35), (C + math.cos(a) * r, cy + math.sin(a) * r)], w=0.8)
        p.circle(C + math.cos(a) * (r + 1.6), cy + math.sin(a) * (r + 1.6), 0.7, fill=True)
    dot(p, cy, 1.4)


def dongson(p, cy, r=10):
    p.circle(C, cy, r, w=1.0)
    p.circle(C, cy, r * 0.7, w=0.7)
    pts = []
    for k in range(24):
        rr = r * 0.55 if k % 2 == 0 else r * 0.18
        a = math.radians(k * 15 - 90)
        pts.append((C + math.cos(a) * rr, cy + math.sin(a) * rr))
    p.poly(pts, fill=True)
    for k in range(16):
        a = math.radians(k * 22.5)
        p.circle(C + math.cos(a) * r * 0.85, cy + math.sin(a) * r * 0.85, 0.55, fill=True)


def vine(p, h, amp=4, period=128, w=0.8):
    p.line([(C + math.sin(y / period * 2 * math.pi) * amp, y) for y in range(0, h + 1, 2)], w=w)


# ---------------- chủ đề ----------------
THEMES = {
    "macdinh":   dict(gray=120, seq=[lambda p, y: diamond(p, y), lambda p, y: dot(p, y)], step=36, rail=True),
    "tet":       dict(gray=0, seq=[lambda p, y: flower5(p, y), lambda p, y: bud(p, y), lambda p, y: flower5(p, y, r=3.4, filled=True), lambda p, y: bud(p, y)], step=40, vine=True),
    "duonglich": dict(gray=0, seq=[lambda p, y: firework(p, y), lambda p, y: star(p, y, r=5, fill=True)], step=46),
    "tinhyeu":   dict(gray=0, seq=[lambda p, y: heart(p, y), lambda p, y: flower5(p, y, r=3), lambda p, y: heart(p, y, s=0.7, fill=True), lambda p, y: flower5(p, y, r=3)], step=40, vine=True),
    "quockhanh": dict(gray=0, seq=[lambda p, y: star(p, y, r=9, fill=True), lambda p, y: star(p, y, r=5)], step=40, rail=True),
    "thieunhi":  dict(gray=0, seq=[lambda p, y: balloon(p, y), lambda p, y: star(p, y, r=5)], step=44),
    "sen":       dict(gray=0, seq=[lambda p, y: lotus(p, y), lambda p, y: dot(p, y)], step=44, rail=True),
    "trungthu":  dict(gray=0, seq=[lambda p, y: lantern(p, y), lambda p, y: star(p, y, r=5), lambda p, y: moon(p, y), lambda p, y: star(p, y, r=5)], step=44),
    "nhagiao":   dict(gray=0, seq=[lambda p, y: book(p, y), lambda p, y: flower5(p, y, r=3.4)], step=44, vine=True),
    "noel":      dict(gray=0, seq=[lambda p, y: snowflake(p, y), lambda p, y: tree(p, y), lambda p, y: star(p, y, r=5, fill=True)], step=42),
    "dongson":   dict(gray=0, seq=[lambda p, y: dongson(p, y), lambda p, y: diamond(p, y, r=5)], step=40, rail=True),
}


def strip(name, h, mirror=False):
    t = THEMES[name]
    p = Pen(h, t["gray"])
    if t.get("rail"):
        p.line([(3, 0), (3, h)], w=0.8)
        p.line([(SW - 3, 0), (SW - 3, h)], w=0.8)
    if t.get("vine"):
        vine(p, h)
    y, i = t["step"] / 2 + 6, 0
    while y < h - 10:
        t["seq"][i % len(t["seq"])](p, y)
        y += t["step"]; i += 1
    img = p.done(h)
    return img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img


for name in THEMES:
    for tag, h in (("doc", 1024), ("ngang", 758)):
        strip(name, h).save(os.path.join(OUT, f"{name}_{tag}_l.png"), optimize=True)
        strip(name, h, mirror=True).save(os.path.join(OUT, f"{name}_{tag}_r.png"), optimize=True)
print(f"Xong {len(THEMES)} chủ đề -> {OUT}")
