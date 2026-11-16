#!/usr/bin/env python3
"""Chuẩn bị ảnh cho Kindle Dashboard (chạy trên Mac/PC).

Thu nhỏ ảnh vừa khung 298x344, chuyển thang xám, tăng tương phản nhẹ,
lưu PNG 8-bit (định dạng `eips -g` đọc được).

    python3 tools/prepare_photos.py ~/Pictures/chon-cho-kindle  kindle/dashboard/photos
    python3 tools/prepare_photos.py anh1.jpg anh2.heic ... kindle/dashboard/photos
"""
import os
import sys

from PIL import Image, ImageOps, ImageEnhance

BOX = (298, 344)
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
    img = ImageOps.fit(img, BOX, Image.LANCZOS)          # cắt giữa cho đầy khung
    img = ImageEnhance.Contrast(img).enhance(1.15)
    out = os.path.join(dst_dir, f"photo_{idx:03d}.png")
    img.save(out, "PNG", optimize=True)
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    *srcs, dst = sys.argv[1:]
    os.makedirs(dst, exist_ok=True)
    n = 0
    for src in collect(srcs):
        try:
            n += 1
            print("->", convert(src, dst, n))
        except Exception as e:  # HEIC cần pillow-heif: pip3 install pillow-heif
            n -= 1
            print(f"bỏ qua {src}: {e}")
    print(f"Xong {n} ảnh.")


if __name__ == "__main__":
    try:
        from pillow_heif import register_heif_opener
        register_heif_opener()
    except ImportError:
        pass
    main()
