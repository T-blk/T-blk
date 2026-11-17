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

[ -f kindle/dashboard/clockm/1159.png ] && [ -f kindle/dashboard/ring/59.png ] || python3 tools/make_modern_assets.py kindle/dashboard

STAGE=$(mktemp -d)
mkdir -p "$STAGE/dashboard" "$STAGE/documents"
for f in dash.sh touch.sh update.sh remote_srv.sh VERSION THIRD_PARTY.txt dash.conf.default todo.txt; do
  cp "kindle/dashboard/$f" "$STAGE/dashboard/"
done
for d in lib fonts bin ornaments ui clockm ring; do cp -R "kindle/dashboard/$d" "$STAGE/dashboard/"; done
rm -f "$STAGE/dashboard/todo.txt"             # không ghi đè danh sách việc của người dùng
cp kindle/documents/*.sh "$STAGE/documents/"
mkdir -p ota
TAR="tar --owner=0 --group=0 --numeric-owner --sort=name --mtime=@0"
# Gói tách: mã (nhỏ, đổi thường xuyên) + tài nguyên (font, ảnh dựng sẵn — lớn, ít đổi; chỉ tải lại khi khác)
ASSETS="fonts bin ornaments clockm ring"
( cd "$STAGE" && $TAR -cf - $(for d in $ASSETS; do echo "dashboard/$d"; done) ) | gzip -9n > ota/assets.tar.gz
( cd "$STAGE" && $TAR $(for d in $ASSETS; do echo "--exclude=dashboard/$d"; done) -cf - dashboard documents ) | gzip -9n > ota/core.tar.gz
# Gói đầy đủ (cho update.sh đời cũ), kèm mã nhận dạng tài nguyên để lần sau chỉ cần tải phần mã
sha256sum ota/assets.tar.gz | cut -d' ' -f1 > "$STAGE/dashboard/.assets_id"
( cd "$STAGE" && $TAR -cf - dashboard documents ) | gzip -9n > ota/dashboard.tar.gz
rm -rf "$STAGE"
sz() { wc -c < "$1" | tr -d ' '; }
sh_() { sha256sum "$1" | cut -d' ' -f1; }
cat > ota/version.txt <<EOT
version=$VER
sha256=$(sh_ ota/dashboard.tar.gz)
size=$(sz ota/dashboard.tar.gz)
core_sha=$(sh_ ota/core.tar.gz)
core_size=$(sz ota/core.tar.gz)
assets_sha=$(sh_ ota/assets.tar.gz)
assets_size=$(sz ota/assets.tar.gz)
notes=$NOTES
EOT
echo "OTA $VER  đầy đủ $(sz ota/dashboard.tar.gz) B · mã $(sz ota/core.tar.gz) B · tài nguyên $(sz ota/assets.tar.gz) B"
