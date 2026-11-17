#!/bin/bash
# =====================================================================
#  Gửi ảnh sang Kindle qua Wi-Fi — KHÔNG cần cắm cáp (chạy trên Mac)
#
#  1. Trên Kindle: Cài đặt > "Nhận ảnh từ Mac qua Wi-Fi…"  (hiện địa chỉ + mã PIN)
#  2. Trên Mac (cùng Wi-Fi):
#       ./gui-anh-wifi.command                       gửi toàn bộ ảnh trong ~/Pictures/cho-kindle
#       ./gui-anh-wifi.command kindle-trangthai.zip  gửi gói ảnh trạng thái đã chuẩn bị sẵn
#  Có thể đặt sẵn: KINDLE_IP=192.168.1.23 KINDLE_PIN=1234
# =====================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${SRC:-$HOME/Pictures/cho-kindle}"
say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mLỖI: %s\033[0m\n' "$*"; read -r -p "Nhấn Enter để đóng..." _; exit 1; }

IP="${KINDLE_IP:-}"; PIN="${KINDLE_PIN:-}"
[ -n "$IP" ] || read -r -p "Địa chỉ Kindle (hiện trên màn hình Kindle, vd 192.168.1.23): " IP
[ -n "$PIN" ] || read -r -p "Mã PIN trên Kindle: " PIN
IP=${IP#http://}; IP=${IP%%/*}; case "$IP" in *:*) BASE="http://$IP" ;; *) BASE="http://$IP:8080" ;; esac
curl -s -m 5 "$BASE/hello" | grep -q kindle-dashboard || fail "Không thấy Kindle ở $BASE. Kiểm tra Kindle đang mở màn hình 'Nhận ảnh từ Mac' và cùng Wi-Fi."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
MODE=all
if [ $# -gt 0 ] && [ -f "$1" ] && [ "${1##*.}" = zip ]; then
  unzip -q "$1" -d "$WORK/z" || fail "Không giải nén được $1"
  ST=$(find "$WORK/z" -type d -name status | head -1); [ -n "$ST" ] || fail "Gói không có thư mục status"
  mkdir -p "$WORK/photos"; cp -R "$ST" "$WORK/photos/status"; MODE=status
  G=$(find "$WORK/z" -type d -name 2-trang-thai | head -1)
  [ -n "$G" ] && mkdir -p "$SRC" && ditto "$G" "$SRC/2-trang-thai" && say "Đã lưu ảnh gốc vào $SRC/2-trang-thai"
elif [ $# -gt 0 ] && [ -d "$1/status" ]; then
  mkdir -p "$WORK/photos"; cp -R "$1/status" "$WORK/photos/status"; MODE=status
else
  say "Chuẩn bị ảnh từ $SRC …"
  python3 -c "import PIL" 2>/dev/null || pip3 install --user Pillow || fail "Không cài được Pillow"
  python3 "$HERE/prepare_photos.py" "$SRC" "$WORK/photos" --preview "$SRC/_xem-truoc" || fail "Chuẩn bị ảnh thất bại"
fi

FILES=$(cd "$WORK/photos" && find . -type f \( -name '*.png' -o -name '*.txt' \) | sed 's#^\./##')
N=$(echo "$FILES" | grep -c .); [ "$N" -gt 0 ] || fail "Không có ảnh để gửi"
say "Gửi $N file sang Kindle ($BASE) …"
if [ $MODE = status ]; then curl -s -m 10 "$BASE/photoclear?k=$PIN&dir=status" | grep -q true || fail "Sai mã PIN?"
else curl -s -m 10 "$BASE/photoclear?k=$PIN&dir=all" | grep -q true || fail "Sai mã PIN?"; fi
i=0; err=0
while IFS= read -r f; do
  i=$((i + 1))
  if curl -s -m 60 --data-binary @"$WORK/photos/$f" -H 'Content-Type: application/octet-stream' "$BASE/upload?k=$PIN&path=$f" | grep -q true; then
    printf '\r  %d/%d  %s                    ' "$i" "$N" "$f"
  else err=$((err + 1)); printf '\n  lỗi: %s\n' "$f"; fi
done <<< "$FILES"
curl -s -m 10 "$BASE/photodone?k=$PIN" >/dev/null
echo
[ $err = 0 ] && say "Xong! Đã gửi $N file. Trên Kindle chạm mũi tên trái để quay lại." || say "Gửi xong nhưng $err file lỗi — chạy lại lệnh này."
read -r -p "Nhấn Enter để đóng..." _
