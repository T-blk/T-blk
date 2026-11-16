#!/bin/sh
# Đóng gói bản cập nhật không dây vào thư mục ota/ (Kindle tải từ GitHub).
#   sh tools/make_ota.sh "Ghi chú thay đổi ngắn gọn"
# Tạo: ota/dashboard.tar.gz, ota/version.txt (version, sha256, size, notes)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTES="${1:-Cải tiến và sửa lỗi}"
cd "$ROOT"
TODAY=$(date +%Y.%m.%d)
OLD=$(sed -n 's/^version=//p' ota/version.txt 2>/dev/null || true)
N=1
case "$OLD" in "$TODAY".*) N=$(echo "${OLD##*.}" | awk '{ print $1 + 1 }') ;; esac
VER=$(printf '%s.%02d' "$TODAY" "$N")
echo "$VER" > kindle/dashboard/VERSION
cp kindle/dashboard/dash.conf kindle/dashboard/dash.conf.default

STAGE=$(mktemp -d)
mkdir -p "$STAGE/dashboard" "$STAGE/documents"
for f in dash.sh touch.sh update.sh VERSION THIRD_PARTY.txt dash.conf.default todo.txt; do
  cp "kindle/dashboard/$f" "$STAGE/dashboard/"
done
for d in lib fonts bin ornaments ui; do cp -R "kindle/dashboard/$d" "$STAGE/dashboard/"; done
rm -f "$STAGE/dashboard/todo.txt"             # không ghi đè danh sách việc của người dùng
cp kindle/documents/*.sh "$STAGE/documents/"
mkdir -p ota
( cd "$STAGE" && tar --owner=0 --group=0 -cf - dashboard documents ) | gzip -9n > ota/dashboard.tar.gz
rm -rf "$STAGE"
SHA=$(sha256sum ota/dashboard.tar.gz | cut -d' ' -f1)
SIZE=$(wc -c < ota/dashboard.tar.gz | tr -d ' ')
cat > ota/version.txt <<EOT
version=$VER
sha256=$SHA
size=$SIZE
notes=$NOTES
EOT
echo "OTA $VER  ($SIZE byte)  $SHA"
