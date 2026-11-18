#!/bin/sh
# Bộ canh gác: chạy riêng, song song với dash.sh. Nếu dashboard bị kẹt (không còn báo "còn sống") hoặc chết
# mà để giao diện Kindle đóng băng, nó tự dừng dashboard và TRẢ LẠI giao diện Kindle — người dùng không bao giờ
# phải giữ nút nguồn hay khởi động lại cứng.
#   sh lib/watchdog.sh PID_DASH
# dash.sh ghi vào /tmp/dash_alive một mốc thời gian (epoch) "nếu tới lúc này mà chưa ghi lại thì là kẹt".
DIR="${DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$DIR/lib/fw.sh"
DPID=$1
INT=${WD_INT:-30}              # giây giữa 2 lần kiểm tra (chỉ đổi khi chạy thử)
GRACE=${WD_GRACE:-120}         # trễ hạn bao lâu mới coi là kẹt
FB=/tmp/dash_fbink
log() { echo "$(date '+%F %T') [watchdog] $*"; }
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null && grep -q "dash.sh" "/proc/$1/cmdline" 2>/dev/null; }
lock_owner() { cat /tmp/dash.lock/pid 2>/dev/null; }

rescue() { # lý do
  log "$1 -> dừng dashboard và trả lại giao diện Kindle"
  echo "$(date '+%F %T') $1" >> "$DIR/hang.log"
  touch /tmp/dash_stop
  kill "$DPID" 2>/dev/null; sleep 3; kill -9 "$DPID" 2>/dev/null
  pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  [ "$(lock_owner)" = "$DPID" ] && rm -rf /tmp/dash.lock
  rm -f /tmp/dash.pid /tmp/dash_alive
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
  fw_resume
  log "đã trả lại giao diện Kindle"
}

log "bắt đầu canh dashboard (pid $DPID, kiểm tra mỗi ${INT}s, kẹt nếu trễ ${GRACE}s)"
stale=0
while :; do
  sleep "$INT"
  # đang cập nhật phần mềm (dashboard cố ý thoát để bản mới tiếp quản) -> chờ, tối đa 15 phút
  if [ -f /tmp/dash_updating ]; then u=$(date -r /tmp/dash_updating +%s 2>/dev/null || echo 0)
    [ $(( $(date +%s) - u )) -lt 900 ] && { stale=0; continue; }; fi
  if ! alive "$DPID"; then
    # Dashboard đã thoát. Có thể là cập nhật / khởi động lại (bản mới sẽ lấy khoá) -> chờ tối đa 60 giây
    # (không tính thời gian đang cập nhật), rồi mới xem giao diện Kindle có bị bỏ lại trong trạng thái đóng băng không.
    t=0
    while [ $t -lt 60 ]; do
      o=$(lock_owner); alive "$o" && exit 0                      # đã có bản dashboard khác tiếp quản
      if [ -f /tmp/dash_updating ] && [ $(( $(date +%s) - $(date -r /tmp/dash_updating +%s 2>/dev/null || echo 0) )) -lt 900 ]; then sleep 10; continue; fi
      sleep 5; t=$(( t + 5 ))
    done
    if [ -f "$FW_FLAG" ] || { _c=$(cvm_pid) && case "$(proc_state "$_c")" in T|t) true ;; *) false ;; esac; }; then
      rescue "dashboard đã thoát nhưng giao diện Kindle còn bị đóng băng"
    fi
    exit 0
  fi
  [ -f /tmp/dash_sleeping ] && { stale=0; continue; }                 # đang ngủ sâu có chủ đích
  w=$(cat /tmp/dash_woke 2>/dev/null); now=$(date +%s)
  [ -n "$w" ] && [ $(( now - w )) -lt 180 ] && { stale=0; continue; }  # vừa dậy sau ngủ sâu: chờ dashboard ghi lại
  dl=$(cat /tmp/dash_alive 2>/dev/null)
  case "$dl" in ''|*[!0-9]*) stale=0; continue ;; esac
  if [ "$now" -gt $(( dl + GRACE )) ]; then
    stale=$(( stale + 1 ))
    log "dashboard trễ hạn $(( now - dl ))s (lần $stale)"
    [ $stale -ge 2 ] && { rescue "dashboard không phản hồi $(( now - dl ))s"; exit 0; }
  else stale=0; fi
done
