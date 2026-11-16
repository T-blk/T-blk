#!/usr/bin/env python3
"""Chuẩn bị ảnh cho Kindle Dashboard (chạy trên Mac/PC).

Tạo 4 cỡ ảnh PNG thang xám (định dạng `eips -g` đọc được):
  photos/*.png           298x344   khung ảnh, bố cục dọc
  photos/land/*.png      454x270   khung ảnh, bố cục ngang
  photos/full/*.png      758x1024  xem toàn màn hình, dọc
  photos/fullland/*.png  1024x758  xem toàn màn hình, ngang

    python3 tools/prepare_photos.py ~/Pictures/cho-kindle kindle/dashboard/photos
"""
import os
import sys

from PIL import Image, ImageOps, ImageEnhance

SIZES = {"": (298, 344), "land": (454, 270), "full": (758, 1024), "fullland": (1024, 758)}
EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".heic"}


def collect(paths):
    for p in paths:
        if os.path.isdir(p):
            for name in sorted(os.listdir(p)):
                if os.path.splitext(name)[1].lower() in EXTS:
                    yield os.path.join(p, name)
        else:
            yield p


def convert(src, dst_dir, idx):
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
        out.save(os.path.join(d, f"photo_{idx:03d}.png"), "PNG", optimize=True)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    *srcs, dst = sys.argv[1:]
    os.makedirs(dst, exist_ok=True)
    n = 0
    for src in collect(srcs):
        try:
            convert(src, dst, n + 1)
            n += 1
            print(f"-> {os.path.basename(src)}  (photo_{n:03d})")
        except Exception as e:  # HEIC cần pillow-heif: pip3 install pillow-heif
            print(f"bỏ qua {src}: {e}")
    print(f"Xong {n} ảnh.")


if __name__ == "__main__":
    try:
        from pillow_heif import register_heif_opener
        register_heif_opener()
    except ImportError:
        pass
    main()
