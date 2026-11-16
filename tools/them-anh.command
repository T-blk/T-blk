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
