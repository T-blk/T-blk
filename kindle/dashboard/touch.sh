#!/bin/sh
# Đọc cảm ứng + nút nguồn cho Kindle Dashboard.
#   sh touch.sh          theo dõi: chạm nút "Về Home" hoặc bấm nút nguồn -> về giao diện Kindle
#   sh touch.sh --probe  dò cảm ứng 25 giây, ghi log để hiệu chỉnh toạ độ
# Mỗi sự kiện input là 16 byte (ARM 32-bit): sec usec type code value.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/dash.conf"
FB=/tmp/dash_fbink
BOLD="$DIR/fonts/NotoSans-Bold.ttf"
: "${TOUCH_MAX_X:=758}" "${TOUCH_MAX_Y:=1024}" "${TOUCH_SWAP_XY:=0}" "${TOUCH_FLIP_X:=0}" "${TOUCH_FLIP_Y:=0}"

log() { echo "$(date '+%F %T') [touch] $*"; }

# Đọc đúng 1 sự kiện -> in "type code value" (value có dấu)
if echo | od -An -tu4 >/dev/null 2>&1; then
  read_ev() { dd if="$1" bs=16 count=1 2>/dev/null | od -An -tu4; }
else
  read_ev() { dd if="$1" bs=16 count=1 2>/dev/null | hexdump -v -e '4/4 "%u " "\n"'; }
fi

devices() {
  for e in /dev/input/event*; do
    n=$(cat "/sys/class/input/$(basename "$e")/device/name" 2>/dev/null)
    echo "$e|$n"
  done
}

go_home() {
  log "go home ($1)"
  "$FB" -q -c -m -M -t "regular=$BOLD,px=44" "Đang về Home…" >/dev/null 2>&1
  pkill -f "$DIR/dash.sh" 2>/dev/null
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
  start framework 2>/dev/null || start lab126_gui 2>/dev/null
  pkill -f "dd if=/dev/input" 2>/dev/null
  pkill -f "$DIR/touch.sh" 2>/dev/null
  exit 0
}

# Toạ độ cảm ứng -> toạ độ màn hình (758x1024)
map_xy() {
  x=$1; y=$2
  [ "$TOUCH_SWAP_XY" = 1 ] && { t=$x; x=$y; y=$t; }
  x=$(( x * 758 / TOUCH_MAX_X )); y=$(( y * 1024 / TOUCH_MAX_Y ))
  [ "$TOUCH_FLIP_X" = 1 ] && x=$(( 757 - x ))
  [ "$TOUCH_FLIP_Y" = 1 ] && y=$(( 1023 - y ))
  SX=$x; SY=$y
}

# $1=device  $2=mode(watch|probe)
watch_dev() {
  dev=$1; mode=$2
  X=-1; Y=-1; down=0; last=0
  while :; do
    set -- $(read_ev "$dev")
    [ $# -ge 5 ] && shift            # od có thể in thêm cột offset
    [ $# -lt 4 ] && { sleep 1; continue; }
    w3=$3; val=$4
    type=$(( w3 % 65536 )); code=$(( w3 / 65536 ))
    [ "$val" -gt 2147483647 ] 2>/dev/null && val=$(( val - 4294967296 ))
    [ "$mode" = probe ] && [ "$type" != 0 ] && log "raw $dev type=$type code=$code value=$val"
    release=0
    case "$type" in
      3) case "$code" in 0|53) X=$val; down=1 ;; 1|54) Y=$val; down=1 ;; 57) [ "$val" = -1 ] && release=1 ;; esac ;;
      1) case "$code" in
           330) [ "$val" = 0 ] && release=1; [ "$val" = 1 ] && down=1 ;;
           116) [ "$val" = 1 ] && { [ "$mode" = probe ] && log "POWER pressed" || go_home "power button"; } ;;
         esac ;;
    esac
    if [ $release = 1 ] && [ $down = 1 ] && [ $X -ge 0 ] && [ $Y -ge 0 ]; then
      now=$(date +%s)
      if [ $(( now - last )) -ge 1 ]; then
        last=$now; map_xy $X $Y
        log "tap raw=($X,$Y) screen=($SX,$SY)"
        if [ "$mode" = watch ] && [ $SX -ge 540 ] && [ $SY -le 120 ]; then go_home "tap Home"; fi
      fi
      down=0
    fi
  done
}

if [ "$1" = "--probe" ]; then
  log "devices:"; devices
  log "reader: $(echo | od -An -tu4 >/dev/null 2>&1 && echo od || echo hexdump)"
  cp "$DIR/bin/fbink" "$FB" 2>/dev/null && chmod +x "$FB"
  stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
  sleep 2
  "$FB" -q -c -t "regular=$BOLD,px=40,top=330,left=40,right=40" "DÒ CẢM ỨNG (25 giây)

Chạm lần lượt 4 góc:
trên-trái, trên-phải,
dưới-trái, dưới-phải.
Cuối cùng bấm nút nguồn 1 lần." >/dev/null 2>&1
  for c in "0 0" "0 718" "984 0" "984 718"; do set -- $c; "$FB" -q -B BLACK -k "top=$1,left=$2,width=40,height=40" >/dev/null 2>&1; done
  for d in /dev/input/event*; do watch_dev "$d" probe & done
  sleep 25
  pkill -f "dd if=/dev/input" 2>/dev/null; kill $(jobs -p) 2>/dev/null
  log "probe done"
  start framework 2>/dev/null || start lab126_gui 2>/dev/null
  exit 0
fi

# Chế độ theo dõi
log "watching: $(devices | tr '\n' ' ')"
for d in /dev/input/event*; do watch_dev "$d" watch & done
wait
