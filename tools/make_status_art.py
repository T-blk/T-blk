#!/usr/bin/env python3
"""Minh hoạ tự vẽ cho màn hình trạng thái + hoa lá cành.

  ui/status/<id>.png     560x420  minh hoạ toàn cảnh (có cành hoa lá hai bên)
  ui/status/<id>_s.png   200x150  ảnh nhỏ cho lưới chọn nhanh
  ui/flora_div.png       420x40   đường phân cách hoa lá
  ornaments/{hoala,hoanhai,ladeo}_{doc,ngang}_{l,r}.png  dải viền hoa lá (26 px)

    python3 tools/make_status_art.py kindle/dashboard
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard"
SS = 4
INK, MID, SOFT, PALE, WHITE = 0, 90, 150, 215, 255


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("L", (w * SS, h * SS), WHITE)
        self.d = ImageDraw.Draw(self.im)

    def P(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def line(self, pts, w=5, c=INK):
        self.d.line(self.P(pts), fill=c, width=int(w * SS), joint="curve")
        for x, y in (pts[0], pts[-1]):
            r = w * SS / 2
            self.d.ellipse((x * SS - r, y * SS - r, x * SS + r, y * SS + r), fill=c)

    def poly(self, pts, fill=None, outline=INK, w=5):
        P = self.P(pts)
        if fill is not None:
            self.d.polygon(P, fill=fill)
        if outline is not None:
            self.d.line(P + [P[0]], fill=outline, width=int(w * SS), joint="curve")

    def rrect(self, x0, y0, x1, y1, r, fill=None, outline=INK, w=5):
        self.d.rounded_rectangle((x0 * SS, y0 * SS, x1 * SS, y1 * SS), radius=r * SS, fill=fill,
                                 outline=outline, width=int(w * SS) if outline is not None else 0)

    def ell(self, cx, cy, rx, ry=None, fill=None, outline=INK, w=5):
        ry = rx if ry is None else ry
        self.d.ellipse(((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS), fill=fill,
                       outline=outline, width=int(w * SS) if outline is not None else 0)

    def arc(self, cx, cy, r, a0, a1, w=5, c=INK):
        self.d.arc(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS), a0, a1, fill=c, width=int(w * SS))

    def curve(self, pts, w=5, c=INK, n=40):
        """Bezier bậc 2/3 qua các điểm điều khiển."""
        out = []
        for i in range(n + 1):
            t = i / n
            if len(pts) == 3:
                (x0, y0), (x1, y1), (x2, y2) = pts
                x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
                y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
            else:
                (x0, y0), (x1, y1), (x2, y2), (x3, y3) = pts
                x = (1 - t) ** 3 * x0 + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3 * x3
                y = (1 - t) ** 3 * y0 + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3 * y3
            out.append((x, y))
        self.line(out, w, c)
        return out

    def text(self, xy, s, size, c=INK):
        from PIL import ImageFont
        f = ImageFont.truetype(os.path.join(ROOT, "fonts", "Inter-Bold.ttf"), size * SS)
        self.d.text((xy[0] * SS, xy[1] * SS), s, font=f, fill=c, anchor="mm")

    def done(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


# ---------------- hoa lá ----------------
def leaf(cv, x, y, ang, L=34, wd=13, fill=PALE, w=3):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    for i in range(21):
        t = i / 20
        px = t * L
        py = math.sin(t * math.pi) * wd / 2
        pts.append((px, py))
    pts += [(px, -py) for px, py in reversed(pts)]
    P = [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]
    cv.poly(P, fill=fill, outline=INK, w=w)
    cv.line([(x, y), (x + L * 0.85 * ca, y + L * 0.85 * sa)], w=max(1.2, w * 0.5), c=INK)


def flower(cv, x, y, r=12, petals=5, fill=WHITE, w=3, rot=0):
    for k in range(petals):
        a = math.radians(rot + k * 360 / petals)
        cv.ell(x + math.cos(a) * r * 0.9, y + math.sin(a) * r * 0.9, r * 0.62, fill=fill, outline=INK, w=w)
    cv.ell(x, y, r * 0.38, fill=INK, outline=None)


def sprig(cv, x, y, h, side=1, seed=0):
    """Cành hoa lá mọc từ (x,y) lên trên, nghiêng về phía side."""
    rnd = random.Random(seed)
    top = (x + side * 26, y - h)
    pts = cv.curve([(x, y), (x - side * 18, y - h * 0.45), top], w=3.5)
    for i, t in enumerate((0.18, 0.32, 0.46, 0.6, 0.74)):
        px, py = pts[int(t * (len(pts) - 1))]
        s = 1 if i % 2 == 0 else -1
        leaf(cv, px, py, -90 + s * 52 + rnd.uniform(-8, 8), L=30 + rnd.uniform(-4, 6), wd=13)
    flower(cv, top[0], top[1], r=13, rot=rnd.uniform(0, 72))
    px, py = pts[int(0.55 * (len(pts) - 1))]
    cv.line([(px, py), (px + side * 30, py - 26)], w=2.5)
    flower(cv, px + side * 34, py - 30, r=8, petals=5, fill=PALE, rot=rnd.uniform(0, 72))
    for t in (0.86,):
        px, py = pts[int(t * (len(pts) - 1))]
        cv.ell(px - side * 10, py, 4, fill=INK, outline=None)


def frame_florals(cv, seed):
    W, H = cv.w, cv.h
    sprig(cv, 44, H - 18, H * 0.62, side=1, seed=seed)
    sprig(cv, W - 44, H - 18, H * 0.62, side=-1, seed=seed + 7)
    for x in range(110, W - 100, 46):            # cỏ nhỏ dưới đáy
        cv.curve([(x, H - 14), (x + 4, H - 26), (x + 10, H - 32)], w=2, c=SOFT)
    cv.line([(70, H - 14), (W - 70, H - 14)], w=2.5, c=SOFT)


# ---------------- minh hoạ ----------------
def steam(cv, x, y, h=60, n=3, gap=26):
    for i in range(n):
        sx = x + (i - (n - 1) / 2) * gap
        cv.curve([(sx, y), (sx - 14, y - h * 0.33), (sx + 14, y - h * 0.66), (sx, y - h)], w=4, c=MID)


def art_taptrung(cv):
    cx, by = 280, 330
    cv.poly([(cx - 150, by), (cx + 150, by), (cx + 175, by + 26), (cx - 175, by + 26)], fill=PALE)
    cv.rrect(cx - 128, by - 190, cx + 128, by - 4, 10, fill=WHITE)
    cv.rrect(cx - 112, by - 174, cx + 112, by - 20, 4, fill=None, outline=SOFT, w=2)
    for i, (x0, ln) in enumerate(((0, 120), (24, 80), (24, 140), (48, 60), (24, 110), (0, 50))):
        cv.line([(cx - 96 + x0, by - 150 + i * 22), (cx - 96 + x0 + ln, by - 150 + i * 22)], w=6, c=INK if i % 3 == 0 else SOFT)
    # tai nghe
    cv.arc(cx, by - 196, 92, 200, 340, w=10)
    for s in (-1, 1):
        cv.rrect(cx + s * 92 - 18, by - 236, cx + s * 92 + 18, by - 176, 12, fill=INK, outline=None)
    # cây nhỏ
    cv.poly([(cx + 190, by + 26), (cx + 230, by + 26), (cx + 240, by - 26), (cx + 180, by - 26)], fill=WHITE)
    for a, L in ((-120, 52), (-90, 64), (-60, 50), (-140, 36), (-40, 38)):
        leaf(cv, cx + 210, by - 26, a, L=L, wd=18)


def art_hop(cv):
    cx, cy = 280, 220
    cv.ell(cx, cy + 120, 190, 34, fill=PALE)
    for i, x in enumerate((cx - 120, cx, cx + 120)):
        cv.ell(x, cy + 30, 30, fill=WHITE)
        cv.d.pieslice(((x - 54) * SS, (cy + 64) * SS, (x + 54) * SS, (cy + 172) * SS), 180, 360, fill=INK if i == 1 else MID)
    cv.rrect(cx - 170, cy - 150, cx - 20, cy - 60, 26, fill=WHITE)
    cv.poly([(cx - 120, cy - 62), (cx - 96, cy - 62), (cx - 126, cy - 30)], fill=WHITE, outline=None)
    cv.line([(cx - 120, cy - 60), (cx - 126, cy - 32), (cx - 98, cy - 60)], w=5)
    for k in range(3):
        cv.ell(cx - 130 + k * 36, cy - 105, 8, fill=INK, outline=None)
    cv.rrect(cx + 10, cy - 170, cx + 180, cy - 80, 26, fill=INK, outline=None)
    for k in range(3):
        cv.line([(cx + 40, cy - 145 + k * 22), (cx + 150 - k * 30, cy - 145 + k * 22)], w=6, c=WHITE)
    cv.poly([(cx + 120, cy - 82), (cx + 146, cy - 82), (cx + 150, cy - 50)], fill=INK, outline=None)


def art_goidien(cv):
    cx, cy = 280, 220
    pts = [(cx - 90, cy - 70), (cx - 40, cy - 110), (cx - 10, cy - 60), (cx - 40, cy - 30), (cx + 30, cy + 40),
           (cx + 60, cy + 10), (cx + 110, cy + 40), (cx + 70, cy + 90)]
    cv.curve([(cx - 70, cy - 90), (cx - 150, cy + 10), (cx - 20, cy + 150), (cx + 90, cy + 70)], w=44, c=INK)
    cv.rrect(cx - 128, cy - 132, cx - 48, cy - 66, 18, fill=INK, outline=None)
    cv.rrect(cx + 48, cy + 50, cx + 128, cy + 116, 18, fill=INK, outline=None)
    for r in (40, 72, 104):
        cv.arc(cx + 70, cy - 70, r, 270, 360, w=7, c=MID if r > 40 else INK)


def art_roidi(cv):
    cx, by = 210, 360
    cv.rrect(cx - 90, by - 280, cx + 90, by, 6, fill=PALE)
    cv.poly([(cx - 90, by - 280), (cx + 10, by - 250), (cx + 10, by + 22), (cx - 90, by)], fill=WHITE)
    cv.ell(cx - 6, by - 130, 8, fill=INK, outline=None)
    for k, (x, y) in enumerate(((cx + 120, by - 10), (cx + 160, by - 40), (cx + 200, by - 14), (cx + 240, by - 46))):
        cv.ell(x, y, 13, 20, fill=INK, outline=None)
        cv.ell(x + 2, y - 30, 6, fill=INK, outline=None)
    cv.curve([(cx + 130, by - 180), (cx + 180, by - 230), (cx + 250, by - 200)], w=7)
    cv.line([(cx + 250, by - 200), (cx + 222, by - 222)], w=7)
    cv.line([(cx + 250, by - 200), (cx + 226, by - 172)], w=7)


def art_toilet(cv):
    cx, cy = 300, 230
    cv.ell(cx - 60, cy, 70, 70, fill=WHITE, w=6)
    cv.ell(cx - 60, cy, 24, 24, fill=PALE, w=5)
    cv.poly([(cx - 60, cy + 70), (cx + 120, cy + 70), (cx + 140, cy + 150), (cx - 40, cy + 150)], fill=WHITE, w=5)
    for k in range(3):
        cv.line([(cx - 10 + k * 50, cy + 80), (cx + 4 + k * 50, cy + 140)], w=2, c=SOFT)
    cv.rrect(cx + 20, cy - 170, cx + 130, cy - 60, 20, fill=INK, outline=None)
    cv.text((cx + 75, cy - 115), "WC", 48, WHITE)


def art_cafe(cv):
    cx, by = 280, 330
    cv.ell(cx, by + 10, 170, 26, fill=PALE)
    cv.poly([(cx - 110, by - 150), (cx + 110, by - 150), (cx + 90, by - 10), (cx - 90, by - 10)], fill=WHITE, w=6)
    cv.d.chord(((cx - 90) * SS, (by - 60) * SS, (cx + 90) * SS, (by + 30) * SS), 0, 180, fill=WHITE)
    cv.arc(cx + 110, by - 100, 40, 280, 80, w=12)
    cv.line([(cx - 104, by - 120), (cx + 104, by - 120)], w=4, c=SOFT)
    leaf(cv, cx - 20, by - 80, -30, L=48, wd=22, fill=MID)
    steam(cv, cx, by - 170, h=90)
    for x, y, a in ((cx - 210, by - 6, 30), (cx + 200, by + 2, -20), (cx + 232, by - 22, 60)):
        cv.ell(x, y, 16, 11, fill=INK, outline=None)
        cv.curve([(x - 10, y), (x, y - 4), (x + 10, y)], w=2, c=WHITE)


def art_antrua(cv):
    cx, by = 280, 330
    cv.d.chord(((cx - 160) * SS, (by - 160) * SS, (cx + 160) * SS, (by + 60) * SS), 0, 180, fill=WHITE, outline=INK, width=6 * SS)
    cv.line([(cx - 160, by - 50), (cx + 160, by - 50)], w=6)
    for k in range(5):
        cv.curve([(cx - 110 + k * 14, by - 50), (cx - 60 + k * 30, by - 110), (cx + 30 + k * 18, by - 52)], w=4, c=MID)
    cv.rrect(cx - 50, by + 60, cx + 50, by + 76, 6, fill=INK, outline=None)
    cv.line([(cx + 60, by - 210), (cx - 20, by - 70)], w=8)
    cv.line([(cx + 90, by - 200), (cx + 10, by - 66)], w=8)
    steam(cv, cx - 70, by - 70, h=80, n=2, gap=40)
    leaf(cv, cx + 100, by - 60, -150, L=40, wd=18, fill=MID)


def art_ngutrua(cv):
    cx, cy = 260, 210
    cv.ell(cx, cy, 120, fill=INK, outline=None)
    cv.ell(cx + 58, cy - 40, 112, fill=WHITE, outline=None)
    for k, (x, y, s) in enumerate(((cx + 140, cy - 60, 70), (cx + 200, cy - 130, 52), (cx + 245, cy - 185, 38))):
        cv.text((x, y), "Z", s, INK if k == 0 else MID)
    for x, y in ((cx - 120, cy - 130), (cx - 120, cy + 140), (cx + 210, cy + 60)):
        for a in range(4):
            r = math.radians(a * 90)
            cv.line([(x, y), (x + math.cos(r) * 14, y + math.sin(r) * 14)], w=3)
    cv.rrect(cx - 170, cy + 150, cx + 220, cy + 196, 22, fill=PALE)


def art_vengay(cv):
    cx, by = 280, 330
    cv.d.chord(((cx - 70) * SS, (by - 150) * SS, (cx + 150) * SS, (by + 70) * SS), 180, 360, fill=PALE)
    for r in (130, 156):
        cv.arc(cx + 40, by - 40, r, 200, 340, w=3, c=SOFT)
    cv.line([(60, by - 40), (cv.w - 60, by - 40)], w=5)
    hx = cx - 90
    cv.poly([(hx - 70, by - 40), (hx - 70, by - 140), (hx, by - 200), (hx + 70, by - 140), (hx + 70, by - 40)], fill=WHITE)
    cv.rrect(hx - 18, by - 100, hx + 18, by - 40, 4, fill=INK, outline=None)
    cv.rrect(hx + 26, by - 130, hx + 54, by - 102, 3, fill=PALE, w=3)
    cv.curve([(hx + 80, by - 40), (hx + 200, by - 60), (hx + 260, by)], w=4, c=MID)


ARTS = {
    "taptrung": art_taptrung, "hop": art_hop, "goidien": art_goidien, "roidi": art_roidi, "toilet": art_toilet,
    "cafe": art_cafe, "antrua": art_antrua, "ngutrua": art_ngutrua, "vengay": art_vengay,
}


def divider():
    cv = Canvas(420, 40)
    cv.line([(10, 20), (170, 20)], w=2, c=SOFT)
    cv.line([(250, 20), (410, 20)], w=2, c=SOFT)
    for s in (-1, 1):
        leaf(cv, 210 + s * 12, 20, 90 - s * 90, L=26, wd=11, w=2)
    flower(cv, 210, 20, r=9, w=2)
    return cv.done()


# ---------------- dải viền hoa lá 26 px ----------------
def strip(theme, h, seed):
    W = 26
    cv = Canvas(W, h)
    rnd = random.Random(seed)
    c = W / 2
    if theme == "hoala":                 # dây leo uốn lượn, lá + hoa
        pts = [(c + math.sin(y / 46) * 6, y) for y in range(0, h + 1, 3)]
        cv.line(pts, w=1.6)
        for i, y in enumerate(range(20, h, 46)):
            x = c + math.sin(y / 46) * 6
            s = 1 if i % 2 else -1
            leaf(cv, x, y, 90 + s * 120, L=11, wd=6, w=1.1)
            if i % 3 == 1:
                flower(cv, x - s * 5, y + 22, r=4.4, w=1.1)
    elif theme == "hoanhai":             # chuỗi hoa nhỏ + chấm
        cv.line([(c, 0), (c, h)], w=0.8, c=SOFT)
        for i, y in enumerate(range(16, h, 38)):
            flower(cv, c, y, r=5.2 if i % 2 == 0 else 3.8, petals=5 if i % 2 == 0 else 4, w=1.1, fill=WHITE if i % 2 == 0 else PALE, rot=rnd.uniform(0, 72))
            cv.ell(c, y + 19, 1.4, fill=INK, outline=None)
    else:                                 # ladeo: lá dương xỉ
        cv.line([(c, 0), (c, h)], w=1.4)
        for y in range(8, h, 14):
            for s in (-1, 1):
                leaf(cv, c, y, 90 + s * 125, L=9, wd=4.5, w=0.9, fill=PALE if (y // 14) % 2 else WHITE)
    return cv.done()


def main():
    sd = os.path.join(ROOT, "ui", "status")
    os.makedirs(sd, exist_ok=True)
    for i, (k, fn) in enumerate(ARTS.items()):
        cv = Canvas(560, 420)
        frame_florals(cv, seed=i * 3)
        fn(cv)
        im = cv.done().quantize(16).convert("L")
        im.save(os.path.join(sd, f"{k}.png"), optimize=True)
        th = im.copy()
        th.thumbnail((200, 150), Image.LANCZOS)
        th.save(os.path.join(sd, f"{k}_s.png"), optimize=True)
    divider().quantize(16).convert("L").save(os.path.join(ROOT, "ui", "flora_div.png"), optimize=True)
    od = os.path.join(ROOT, "ornaments")
    for t, seed in (("hoala", 1), ("hoanhai", 2), ("ladeo", 3)):
        for tag, h in (("doc", 1024), ("ngang", 758)):
            s = strip(t, h, seed).quantize(16).convert("L")
            s.save(os.path.join(od, f"{t}_{tag}_l.png"), optimize=True)
            s.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(od, f"{t}_{tag}_r.png"), optimize=True)
    print("ok")


if __name__ == "__main__":
    main()
