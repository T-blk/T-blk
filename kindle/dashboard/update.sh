#!/bin/sh
# Cập nhật không dây cho Kindle Dashboard (tải từ GitHub qua Wi-Fi).
#   sh update.sh --check            in: "uptodate <bản hiện tại>" | "available <bản mới>|<ghi chú>" | "error <lý do>"
#   sh update.sh --install [--restart]   tải, kiểm tra, cài; --restart: khởi động lại dashboard, lỗi thì tự quay lại bản cũ
#   sh update.sh --rollback [--restart]  quay lại bản trước
# Giữ nguyên: dash.conf, settings.conf, todo.txt, AUTOSTART, photos/, clock/
DIR="$(cd "$(dirname "$0")" && pwd)"
US="$(cd "$DIR/.." && pwd)"
[ -f "$DIR/dash.conf" ] && . "$DIR/dash.conf"
BASE="${UPDATE_URL:-https://raw.githubusercontent.com/T-blk/T-blk/claude/kindle-paperwhite-charging-issue-3mr0r4/ota}"
LOG="$US/dashboard_update.log"
NEW="$US/.dash_ota_new"
FB=/tmp/dash_fbink; [ -x "$FB" ] || { cp "$DIR/bin/fbink" "$FB" 2>/dev/null && chmod +x "$FB"; }
BOLD="$DIR/fonts/NotoSans-Bold.ttf"
KEEP_FILES="dash.conf settings.conf todo.txt AUTOSTART battery.log lich-giao-dien.txt .rota_up"
KEEP_DIRS="photos clock"
ASSET_DIRS="fonts bin ornaments clockm ring"   # tài nguyên lớn: chỉ tải lại khi bản mới có thay đổi

log() { echo "$(date '+%F %T') [update] $*" >> "$LOG"; }
[ -f "$DIR/lib/fw.sh" ] && . "$DIR/lib/fw.sh"
ui_back() { # dashboard không chạy được -> trả lại giao diện Kindle đầy đủ
  dash_running && return 0
  command -v fw_resume >/dev/null 2>&1 && fw_resume || { status framework 2>/dev/null | grep -q running || start framework 2>/dev/null; }
  log "trả lại giao diện Kindle"
}
show() { [ "$QUIET" = 1 ] || "$FB" -q -c -m -M -t "regular=$BOLD,px=34" "$*" >/dev/null 2>&1; log "$*"; }
fetch() { curl -s -k -L -m 180 -o "$2" "$1" 2>/dev/null && [ -s "$2" ] || wget -q -T 180 -O "$2" "$1"; }
newer() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }   # so sánh chuỗi yyyy.mm.dd.nn
cur() { cat "$DIR/VERSION" 2>/dev/null || echo 0000.00.00.00; }
field() { sed -n "s/^$1=//p" /tmp/ota_version.txt | head -1; }

wifi_up() {
  [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && return 0
  lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
  lipc-set-prop com.lab126.wifid enable 1 2>/dev/null
  command -v lipc-wait-event >/dev/null 2>&1 && lipc-wait-event -s 30 com.lab126.wifid cmConnected >/dev/null 2>&1
  i=0; while [ $i -lt 60 ]; do
    [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && { sleep 1; return 0; }
    usleep 500000 2>/dev/null || sleep 1; i=$((i + 1)); done
  return 1
}

check() {
  wifi_up || { echo "error Không có Wi-Fi"; return 1; }
  fetch "$BASE/version.txt?t=$(date +%s)" /tmp/ota_version.txt || { echo "error Không tải được thông tin bản mới"; return 1; }
  ver=$(field version); [ -n "$ver" ] || { echo "error Thông tin bản mới bị lỗi"; return 1; }
  c=$(cur)
  if newer "$ver" "$c"; then echo "available $ver|$(field notes)"; else echo "uptodate $c"; fi
}

dash_running() { [ -f /tmp/dash.pid ] && kill -0 "$(cat /tmp/dash.pid)" 2>/dev/null; }
stop_dash() {
  touch /tmp/dash_stop
  pkill -f "$DIR/dash.sh" 2>/dev/null; pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  sleep 1; rm -f /tmp/dash.pid
}
start_dash() { rm -f /tmp/dash_stop; nohup sh "$DIR/dash.sh" > "$DIR/dash.log" 2>&1 & }
healthy() { # chờ bản mới vẽ được màn hình chính
  i=0; while [ $i -lt ${HEALTH_TIMEOUT:-180} ]; do
    grep -qE "first draw ok|render main: done" "$DIR/dash.log" 2>/dev/null && return 0
    sleep 2; i=$((i + 2)); done
  return 1
}
move_keep() { # $1 = từ thư mục  $2 = sang thư mục
  for f in $KEEP_FILES; do [ -e "$1/$f" ] && cp -p "$1/$f" "$2/$f"; done
  for d in $KEEP_DIRS; do [ -d "$1/$d" ] && { rm -rf "$2/$d"; mv "$1/$d" "$2/$d"; }; done
}

rollback() {
  [ -d "$US/dashboard.old" ] || { show "Không có bản cũ để quay lại"; return 1; }
  show "Đang quay lại bản trước…"
  stop_dash
  rm -rf "$US/dashboard.bad"; mv "$DIR" "$US/dashboard.bad"; mv "$US/dashboard.old" "$DIR"
  move_keep "$US/dashboard.bad" "$DIR"
  log "rolled back to $(cur)"
  for d in $ASSET_DIRS; do [ -d "$DIR/$d" ] || [ ! -d "$US/dashboard.bad/$d" ] || mv "$US/dashboard.bad/$d" "$DIR/$d"; done
  [ -f "$DIR/.assets_id" ] || cp -p "$US/dashboard.bad/.assets_id" "$DIR/" 2>/dev/null
  sync
  [ "$RESTART" = 1 ] && start_dash
  return 0
}

get_pkg() { # tên sha size -> /tmp/ota_<tên>.tgz đã kiểm tra
  f=/tmp/ota_$1.tgz; rm -f "$f"
  fetch "$BASE/$1.tar.gz?v=$ver" "$f" || { show "Lỗi: không tải được gói $1"; return 1; }
  got=$(wc -c < "$f" | tr -d ' ')
  [ -z "$3" ] || [ "$got" = "$3" ] || { show "Lỗi: tải thiếu ($got/$3 byte)"; return 1; }
  gzip -t "$f" 2>/dev/null || { show "Lỗi: file tải về bị hỏng"; return 1; }
  if [ -n "$2" ] && command -v sha256sum >/dev/null; then
    [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$2" ] || { show "Lỗi: sai mã kiểm tra (sha256)"; return 1; }
  fi
}

install() {
  r=$(check); log "check: $r"
  case "$r" in available*) ;; uptodate*) show "Đang dùng bản mới nhất ($(cur))"; return 1 ;; *) show "Lỗi: ${r#error }"; return 1 ;; esac
  ver=$(field version); csha=$(field core_sha); asha=$(field assets_sha)
  REUSE=0
  if [ -n "$csha" ]; then                                   # gói tách: thường chỉ tải phần mã (~vài trăm KB)
    REUSE=1; [ "$(cat "$DIR/.assets_id" 2>/dev/null)" = "$asha" ] || REUSE=0
    for d in $ASSET_DIRS; do [ -d "$DIR/$d" ] || REUSE=0; done
    if [ $REUSE = 1 ]; then show "Đang tải bản $ver ($(( $(field core_size) / 1024 )) KB)…"
    else show "Đang tải bản $ver (kèm font & ảnh, $(( ($(field core_size) + $(field assets_size)) / 1024 )) KB)…"; fi
    get_pkg core "$csha" "$(field core_size)" || return 1
    [ $REUSE = 1 ] || get_pkg assets "$asha" "$(field assets_size)" || return 1
    show "Đang giải nén…"
    rm -rf "$NEW"; mkdir -p "$NEW"
    ( cd "$NEW" && gzip -dc /tmp/ota_core.tgz | tar -xf - ) || { show "Lỗi: giải nén thất bại"; return 1; }
    if [ $REUSE = 0 ]; then
      ( cd "$NEW" && gzip -dc /tmp/ota_assets.tgz | tar -xf - ) || { show "Lỗi: giải nén thất bại"; return 1; }
      echo "$asha" > "$NEW/dashboard/.assets_id"
    fi
  else
    show "Đang tải bản $ver…"
    get_pkg dashboard "$(field sha256)" "$(field size)" || return 1
    show "Đang giải nén…"
    rm -rf "$NEW"; mkdir -p "$NEW"
    ( cd "$NEW" && gzip -dc /tmp/ota_dashboard.tgz | tar -xf - ) || { show "Lỗi: giải nén thất bại"; return 1; }
  fi
  rm -f /tmp/ota_*.tgz
  [ -f "$NEW/dashboard/dash.sh" ] && [ -f "$NEW/dashboard/VERSION" ] || { show "Lỗi: gói cập nhật thiếu file"; return 1; }
  [ -f "$DIR/dash.conf" ] || cp "$NEW/dashboard/dash.conf.default" "$NEW/dashboard/dash.conf"

  was=0; dash_running && was=1
  [ "$was" = 1 ] && stop_dash
  show "Đang cài bản $ver…"
  rm -rf "$US/dashboard.old"
  mv "$DIR" "$US/dashboard.old" || { show "Lỗi: không đổi được thư mục"; return 1; }
  mv "$NEW/dashboard" "$DIR"
  move_keep "$US/dashboard.old" "$DIR"
  if [ $REUSE = 1 ]; then                                    # dùng lại font & ảnh đang có (chuyển, không chép)
    for d in $ASSET_DIRS; do mv "$US/dashboard.old/$d" "$DIR/$d"; done
    cp -p "$US/dashboard.old/.assets_id" "$DIR/"
  fi
  sync
  [ -d "$NEW/documents" ] && cp -f "$NEW/documents/"*.sh "$US/documents/" 2>/dev/null
  rm -rf "$NEW"
  log "installed $ver (was $(cat "$US/dashboard.old/VERSION" 2>/dev/null))"

  if [ "$RESTART" = 1 ] || [ "$was" = 1 ]; then
    start_dash
    if healthy; then log "new version healthy"; return 0; fi
    log "new version did not start -> rollback"
    rollback
    healthy || ui_back
    return 1
  fi
  show "Đã cài bản $ver. Bấm Dashboard - Bat để chạy."
  ui_back
}

QUIET=0; RESTART=0
for a in "$@"; do case "$a" in --quiet) QUIET=1 ;; --restart) RESTART=1 ;; esac; done
case "$1" in
  --check) QUIET=1; check ;;
  --install)
    if ! install && [ "$RESTART" = 1 ] && ! dash_running; then
      # tải/cài lỗi: chạy lại bản đang có; vẫn không lên thì trả giao diện Kindle
      sleep 3; start_dash; healthy || ui_back
    fi ;;
  --rollback) rollback ;;
  *) echo "Dùng: sh update.sh --check | --install [--restart] | --rollback [--restart]" ;;
esac
