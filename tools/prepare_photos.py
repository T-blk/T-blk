#!/usr/bin/env python3
"""Chuẩn bị ảnh cho Kindle Dashboard (chạy trên Mac/PC).

Tạo các cỡ ảnh PNG thang xám (định dạng `eips -g` đọc được):
  photos/*.png           298x250   khung ảnh, bố cục dọc
  photos/land/*.png      454x270   khung ảnh, bố cục ngang
  photos/full/*.png      758x1024  xem toàn màn hình, dọc
  photos/fullland/*.png  1024x758  xem toàn màn hình, ngang
  photos/thumb/*.png     150x150   ảnh nhỏ cho trang chọn ảnh
  photos/v/RxC[m]/*.png  cỡ riêng cho từng ô ảnh x kiểu hiển thị (tràn, polaroid, tròn, nhãn, bìa)
                         m: r = bo góc (thẻ), t = bo 2 góc trên, c = tròn
  photos/captions.txt    chú thích (tên file gốc, giữ dấu tiếng Việt)

    python3 tools/prepare_photos.py ~/Pictures/cho-kindle kindle/dashboard/photos
"""
import os
import re
import sys
import unicodedata

from PIL import Image, ImageOps, ImageEnhance

SIZES = {"": (298, 250), "land": (454, 270), "full": (758, 1024), "fullland": (1024, 758), "thumb": (150, 150)}
# Ô ảnh của các bố cục: (rộng, cao, mặt nạ khi "tràn khung")  — khớp với lib/layouts.sh
SLOTS = [(298, 250, ""), (341, 250, "r"), (758, 600, "")]
CARD_BG = 238          # nền xám của bố cục Thẻ (GRAYE)
RADIUS = 26


def variants():
    out = set()
    for w, h, mk in SLOTS:
        tm = "t" if mk == "r" else ""
        d = min(w, h) - 10
        out |= {(w, h, mk), (w - 28, h - 72, ""), (d, d, "c"), (w, h - 50, tm), (w, h - 70, tm)}
    return sorted(out)


def masked(img, w, h, mk):
    from PIL import ImageDraw
    out = ImageOps.fit(img, (w, h), Image.LANCZOS)
    if not mk:
        return out
    m = Image.new("L", (w * 4, h * 4), 0)
    dr = ImageDraw.Draw(m)
    if mk == "c":
        dr.ellipse((0, 0, w * 4 - 1, h * 4 - 1), fill=255)
        bg = 255
    else:
        r = RADIUS * 4
        dr.rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1 + (r if mk == "t" else 0)), radius=r, fill=255)
        bg = CARD_BG
    m = m.resize((w, h), Image.LANCZOS)
    base = Image.new("L", (w, h), bg)
    base.paste(out, (0, 0), m)
    return base


EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".heic"}


def collect(paths):
    for p in paths:
        if os.path.isdir(p):
            for name in sorted(os.listdir(p)):
                if os.path.splitext(name)[1].lower() in EXTS:
                    yield os.path.join(p, name)
        else:
            yield p


def out_name(src, used):
    """Tên ảnh ổn định theo tên file gốc (ASCII, không dấu cách) để ảnh "cố định" không bị đổi."""
    stem = os.path.splitext(os.path.basename(src))[0]
    stem = stem.replace("đ", "d").replace("Đ", "D")
    stem = unicodedata.normalize("NFKD", stem).encode("ascii", "ignore").decode()
    stem = re.sub(r"[^A-Za-z0-9_-]+", "_", stem).strip("_")[:40] or "anh"
    name, k = stem, 2
    while name.lower() in used:
        name, k = f"{stem}_{k}", k + 1
    used.add(name.lower())
    return name + ".png"


def convert(src, dst_dir, name):
    img = Image.open(src)
    img = ImageOps.exif_transpose(img).convert("L")
    img = ImageEnhance.Contrast(img).enhance(1.15)
    for sub, box in SIZES.items():
        d = os.path.join(dst_dir, sub) if sub else dst_dir
        os.makedirs(d, exist_ok=True)
        if sub.startswith("full"):
            out = ImageOps.pad(img, box, Image.LANCZOS, color=255)   # giữ trọn ảnh, viền trắng
        else:
            out = ImageOps.fit(img, box, Image.LANCZOS)              # cắt giữa cho đầy khung
        out.save(os.path.join(d, name), "PNG", optimize=True)
    for w, h, mk in variants():
        d = os.path.join(dst_dir, "v", f"{w}x{h}{mk}")
        os.makedirs(d, exist_ok=True)
        masked(img, w, h, mk).save(os.path.join(d, name), "PNG", optimize=True)


def caption(src):
    stem = unicodedata.normalize("NFC", os.path.splitext(os.path.basename(src))[0])
    stem = re.sub(r"^(IMG|DSC|DSCN|PXL|P)[_-]?\d+[_-]?", "", stem, flags=re.I)
    stem = re.sub(r"[_]+", " ", stem).strip()
    stem = re.sub(r"\s+(\d{4})$", r" · \1", stem)
    return stem.replace("|", "/")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    *srcs, dst = sys.argv[1:]
    os.makedirs(dst, exist_ok=True)
    n = 0
    used = set()
    caps = []
    for src in collect(srcs):
        try:
            name = out_name(src, used)
            convert(src, dst, name)
            c = caption(src)
            if c:
                caps.append(f"{name}|{c}")
            n += 1
            print(f"-> {os.path.basename(src)}  ->  {name}")
        except Exception as e:  # HEIC cần pillow-heif: pip3 install pillow-heif
            print(f"bỏ qua {src}: {e}")
    with open(os.path.join(dst, "captions.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(caps) + ("\n" if caps else ""))
    print(f"Xong {n} ảnh.")


if __name__ == "__main__":
    try:
        from pillow_heif import register_heif_opener
        register_heif_opener()
    except ImportError:
        pass
    main()
