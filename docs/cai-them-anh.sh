T=~/Downloads/kindle-dashboard/tools; mkdir -p $T
cat > $T/prepare_photos.py <<'PYEOF'
#!/usr/bin/env python3
"""Chuẩn bị ảnh cho Kindle Dashboard (chạy trên Mac/PC).

Tạo 4 cỡ ảnh PNG thang xám (định dạng `eips -g` đọc được):
  photos/*.png           298x250   khung ảnh, bố cục dọc
  photos/land/*.png      454x270   khung ảnh, bố cục ngang
  photos/full/*.png      758x1024  xem toàn màn hình, dọc
  photos/fullland/*.png  1024x758  xem toàn màn hình, ngang
  photos/thumb/*.png     150x150   ảnh nhỏ cho trang chọn ảnh

    python3 tools/prepare_photos.py ~/Pictures/cho-kindle kindle/dashboard/photos
"""
import os
import re
import sys
import unicodedata

from PIL import Image, ImageOps, ImageEnhance

SIZES = {"": (298, 250), "land": (454, 270), "full": (758, 1024), "fullland": (1024, 758), "thumb": (150, 150)}
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


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    *srcs, dst = sys.argv[1:]
    os.makedirs(dst, exist_ok=True)
    n = 0
    used = set()
    for src in collect(srcs):
        try:
            name = out_name(src, used)
            convert(src, dst, name)
            n += 1
            print(f"-> {os.path.basename(src)}  ->  {name}")
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
PYEOF
cat > $T/them-anh.command <<'SHEOF'
#!/bin/bash
# =====================================================================
#  Thêm ảnh vào Kindle Dashboard (chạy trên Mac)
#
#  Cách dùng:
#   1. Bỏ ảnh vào thư mục  Ảnh/cho-kindle  (~/Pictures/cho-kindle)
#   2. Thoát dashboard trên Kindle (chạm biểu tượng Nhà), cắm Kindle vào Mac
#   3. Nhấp đúp file này (hoặc chạy trong Terminal, có thể kèm đường dẫn ảnh:
#        ./them-anh.command ~/Desktop/anh1.jpg ~/Desktop/thu-muc-anh )
#
#  Muốn XOÁ ảnh khỏi Kindle: xoá ảnh đó trong thư mục cho-kindle rồi chạy lại.
# =====================================================================
set -u
SRC="${SRC:-$HOME/Pictures/cho-kindle}"
KINDLE="${KINDLE:-/Volumes/Kindle}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/kindle/dashboard/photos"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mLỖI: %s\033[0m\n' "$*"; read -r -p "Nhấn Enter để đóng..." _; exit 1; }

mkdir -p "$SRC"

# 1) Ảnh truyền vào (kéo thả trong Terminal) -> chép vào thư mục nguồn
if [ $# -gt 0 ]; then
  say "Chép ảnh vào $SRC ..."
  for f in "$@"; do
    if [ -d "$f" ]; then cp -n "$f"/* "$SRC"/ 2>/dev/null; else cp -n "$f" "$SRC"/; fi
  done
fi

n=$(find "$SRC" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' \) | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || { open "$SRC"; fail "Thư mục $SRC chưa có ảnh. Đã mở thư mục, hãy bỏ ảnh vào rồi chạy lại."; }

# 2) Chuẩn bị ảnh (thang xám, đủ 5 cỡ)
say "Chuẩn bị $n ảnh ..."
python3 -c "import PIL" 2>/dev/null || pip3 install --user Pillow || fail "Không cài được Pillow"
python3 -c "import pillow_heif" 2>/dev/null || pip3 install --user pillow-heif >/dev/null 2>&1
rm -rf "$OUT"
python3 "$HERE/prepare_photos.py" "$SRC" "$OUT" || fail "Chuẩn bị ảnh thất bại"

# 3) Chép sang Kindle
if [ ! -d "$KINDLE/dashboard" ]; then
  fail "Không thấy Kindle ($KINDLE/dashboard). Cắm Kindle vào Mac rồi chạy lại. Ảnh đã chuẩn bị xong ở: $OUT"
fi
say "Chép sang Kindle ..."
rm -rf "$KINDLE/dashboard/photos"
if command -v ditto >/dev/null; then ditto --norsrc --noextattr --noacl "$OUT" "$KINDLE/dashboard/photos"
else cp -R "$OUT" "$KINDLE/dashboard/photos"; fi || fail "Chép thất bại"
find "$KINDLE" -name '._*' -delete 2>/dev/null
cnt=$(ls "$KINDLE/dashboard/photos/"*.png 2>/dev/null | wc -l | tr -d ' ')
say "Đã chép $cnt ảnh vào Kindle."
ls "$KINDLE/dashboard/photos/"*.png | xargs -n1 basename

# 4) Eject
if [ "${NO_EJECT:-0}" != 1 ]; then
  diskutil eject "$KINDLE" >/dev/null && say "Đã tháo Kindle an toàn. Rút cáp, rồi bấm Dashboard - Bat."
fi
read -r -p "Nhấn Enter để đóng..." _
SHEOF
chmod +x $T/them-anh.command
