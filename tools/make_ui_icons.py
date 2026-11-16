#!/usr/bin/env python3
"""Sinh hình minh hoạ hướng màn hình cho trang Cài đặt (PNG thang xám cho eips).

    python3 tools/make_ui_icons.py kindle/dashboard/ui
Tạo orient_doc.png, orient_nguoc.png, orient_ngangtrai.png, orient_ngangphai.png (170x170).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "kindle/dashboard/ui"
FONT = os.path.join(os.path.dirname(__file__), "..", "kindle", "dashboard", "fonts", "NotoSans-Bold.ttf")
SS = 4
SIZE = 170
os.makedirs(OUT, exist_ok=True)


def device(angle):
    """Vẽ Kindle dọc (dây sạc ở đáy) rồi xoay; nội dung màn hình luôn đứng thẳng với người xem."""
    W, H = 96 * SS, 136 * SS
    pad = 34 * SS
    im = Image.new("L", (W + 2 * pad, H + 2 * pad), 255)
    d = ImageDraw.Draw(im)
    x0, y0 = pad, pad
    d.rounded_rectangle((x0, y0, x0 + W, y0 + H), radius=12 * SS, fill=40)          # thân máy
    d.rectangle((x0 + 9 * SS, y0 + 12 * SS, x0 + W - 9 * SS, y0 + H - 24 * SS), fill=245)  # màn hình
    d.rectangle((x0 + W / 2 - 13 * SS, y0 + H - 15 * SS, x0 + W / 2 + 13 * SS, y0 + H - 11 * SS), fill=170)  # chữ kindle
    # dây sạc ra từ cạnh đáy
    cx = x0 + W / 2
    d.rectangle((cx - 6 * SS, y0 + H, cx + 6 * SS, y0 + H + 10 * SS), fill=0)        # đầu cắm
    d.line((cx, y0 + H + 10 * SS, cx, y0 + H + 32 * SS), fill=0, width=4 * SS)        # dây
    im = im.rotate(angle, expand=True, fillcolor=255, resample=Image.BICUBIC)
    # nội dung màn hình: chữ "Aa" + vài dòng, luôn đứng thẳng
    d = ImageDraw.Draw(im)
    cw, ch = im.size
    f = ImageFont.truetype(FONT, 26 * SS)
    t = "Aa"
    tw = d.textlength(t, font=f)
    landscape = angle in (90, 270)
    sx, sy = (cw - tw) / 2, ch / 2 - (30 if not landscape else 24) * SS
    d.text((sx, sy), t, font=f, fill=0)
    lw = (40 if not landscape else 56) * SS
    for k in range(3):
        y = ch / 2 + (8 + k * 9) * SS
        d.line((cw / 2 - lw / 2, y, cw / 2 + lw / 2 - (k * 8 * SS), y), fill=90, width=3 * SS)
    # thu về khung vuông SIZE
    s = min(SIZE * SS / cw, SIZE * SS / ch)
    im = im.resize((int(cw * s), int(ch * s)), Image.LANCZOS)
    canvas = Image.new("L", (SIZE * SS, SIZE * SS), 255)
    canvas.paste(im, ((SIZE * SS - im.size[0]) // 2, (SIZE * SS - im.size[1]) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


for name, angle in (("doc", 0), ("nguoc", 180), ("ngangtrai", 270), ("ngangphai", 90)):
    device(angle).save(os.path.join(OUT, f"orient_{name}.png"), optimize=True)
print("Xong hình minh hoạ hướng màn hình ->", OUT)
