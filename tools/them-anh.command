#!/bin/bash
# =====================================================================
#  Thêm ảnh vào Kindle Dashboard (chạy trên Mac)
#
#  Cách dùng:
#   1. Bỏ ảnh vào các thư mục đã tạo sẵn trong  Ảnh/cho-kindle  (~/Pictures/cho-kindle):
#        1-anh-khung/              ảnh kỷ niệm: ô ảnh, xem toàn màn hình, bố cục Thẻ / Ảnh lớn
#        2-trang-thai/taptrung/    ảnh cho màn hình "Đang tập trung" (anime, meme... tuỳ bạn)
#        2-trang-thai/toilet/  ... mỗi trạng thái một thư mục
#      (chạy file này lần đầu là có đủ thư mục)
#   2. Thoát dashboard trên Kindle (chạm biểu tượng Nhà), cắm Kindle vào Mac
#   3. Nhấp đúp file này (hoặc chạy trong Terminal, có thể kèm đường dẫn ảnh:
#        ./them-anh.command ~/Desktop/anh1.jpg ~/Desktop/thu-muc-anh )
#
#  Muốn XOÁ ảnh khỏi Kindle: xoá ảnh đó trong thư mục cho-kindle rồi chạy lại.
#
#  Ảnh riêng cho màn hình trạng thái (anime, meme... của bạn): bỏ vào thư mục con
#  cho-kindle/trangthai, đặt tên theo mã: taptrung hop goidien roidi toilet cafe antrua ngutrua vengay
#  (vd toilet.jpg, cafe_1.png, cafe_2.png). Không có thì dùng hình minh hoạ có sẵn.
# =====================================================================
set -u
SRC="${SRC:-$HOME/Pictures/cho-kindle}"
KINDLE="${KINDLE:-/Volumes/Kindle}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/kindle/dashboard/photos"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mLỖI: %s\033[0m\n' "$*"; read -r -p "Nhấn Enter để đóng..." _; exit 1; }

PREV="$SRC/_xem-truoc"
mkdir -p "$SRC/1-anh-khung"
for id in taptrung hop goidien roidi toilet cafe antrua ngutrua vengay; do mkdir -p "$SRC/2-trang-thai/$id"; done
[ -f "$SRC/DOC-TOI.txt" ] || cat > "$SRC/DOC-TOI.txt" <<'EOT'
ẢNH CHO KINDLE DASHBOARD — chép ảnh vào đúng thư mục rồi nhấp đúp them-anh.command

1-anh-khung/       Ảnh kỷ niệm. Hiện trong ô ảnh, bố cục "Thẻ", "Ảnh lớn", và khi chạm để xem toàn màn hình.
                   Tên file thành chú thích:  "Đà Lạt 2025.jpg" -> "Đà Lạt · 2025"

2-trang-thai/      Ảnh riêng cho màn hình trạng thái (thay hình minh hoạ có sẵn). Anime, meme, ảnh của bạn...
   taptrung/  Đang tập trung        hop/      Đang họp           goidien/  Đang nghe điện thoại
   roidi/     Ra ngoài một chút     toilet/   Toilet time         cafe/     Cà phê thư giãn
   antrua/    Đi ăn trưa            ngutrua/  Ngủ trưa            vengay/   Tan làm rồi
   Nhiều ảnh trong một thư mục: mỗi lần bật trạng thái sẽ đổi một ảnh. Thư mục trống: dùng hình có sẵn.

_xem-truoc/        Máy tự tạo: ảnh mô phỏng đúng như sẽ hiện trên Kindle (00-tong-hop.png = xem hết).

Ảnh màu tự chuyển sang thang xám 16 mức của màn Kindle, tăng tương phản và làm nét.
Ảnh dọc hợp màn hình trạng thái; ảnh ngang hợp ô ảnh. Ảnh không bị cắt ở màn hình trạng thái.
EOT

# 1) Ảnh truyền vào (kéo thả trong Terminal) -> chép vào thư mục nguồn
if [ $# -gt 0 ]; then
  say "Chép ảnh vào $SRC ..."
  for f in "$@"; do
    if [ -d "$f" ]; then cp -n "$f"/* "$SRC"/ 2>/dev/null; else cp -n "$f" "$SRC"/; fi
  done
fi

n=$(find "$SRC" -maxdepth 3 -path "$PREV" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' \) -print | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || { open "$SRC"; fail "Chưa có ảnh nào. Đã mở thư mục $SRC — chép ảnh vào 1-anh-khung hoặc 2-trang-thai/<trạng thái> rồi chạy lại."; }

# 2) Chuẩn bị ảnh (thang xám, đủ 5 cỡ)
say "Chuẩn bị $n ảnh ..."
python3 -c "import PIL" 2>/dev/null || pip3 install --user Pillow || fail "Không cài được Pillow"
python3 -c "import pillow_heif" 2>/dev/null || pip3 install --user pillow-heif >/dev/null 2>&1
rm -rf "$OUT"
python3 "$HERE/prepare_photos.py" "$SRC" "$OUT" --preview "$PREV" || fail "Chuẩn bị ảnh thất bại"
[ -f "$PREV/00-tong-hop.png" ] && open "$PREV/00-tong-hop.png"     # xem trước như trên Kindle

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
