#!/bin/sh
# Name: Dashboard - Bat
# Bật dashboard. Thoát: chạm "Về Home" (góc trên phải) hoặc bấm nút nguồn.
# An toàn: hiện chữ NGAY khi chạm (khỏi chạm lại); chạm thừa trong lúc đang mở bị bỏ qua; nếu dashboard đang
# chạy thì dừng hẳn bản cũ rồi mới mở bản mới (không bao giờ có 2 bản chạy cùng lúc).
D=/mnt/us/dashboard
mkdir /tmp/dash_bat.lock 2>/dev/null || exit 0          # một lần chạm khác đang xử lý -> bỏ qua
trap 'rm -rf /tmp/dash_bat.lock' EXIT
F=/tmp/dash_fbink; [ -x "$F" ] || { cp "$D/bin/fbink" "$F" 2>/dev/null && chmod +x "$F"; }
o=$(cat /tmp/dash.lock/pid 2>/dev/null)
if [ -n "$o" ] && kill -0 "$o" 2>/dev/null && grep -q dash.sh "/proc/$o/cmdline" 2>/dev/null; then
  age=$(( $(date +%s) - $(date -r /tmp/dash.lock +%s 2>/dev/null || echo 0) ))
  [ "$age" -lt 30 ] && exit 0                              # vừa mở xong -> đây là lần chạm thừa
  "$F" -q -m -M -t "regular=$D/fonts/NotoSans-Bold.ttf,px=40" "Đang mở lại dashboard…" >/dev/null 2>&1
  touch /tmp/dash_stop; kill "$o" 2>/dev/null              # đang chạy lâu rồi -> khởi động lại: dừng bản cũ…
  i=0; while [ $i -lt 16 ] && kill -0 "$o" 2>/dev/null; do usleep 500000 2>/dev/null || sleep 1; i=$((i + 1)); done
  kill -9 "$o" 2>/dev/null                                 # …và chờ nó thoát hẳn
fi
"$F" -q -m -M -t "regular=$D/fonts/NotoSans-Bold.ttf,px=40" "Đang mở dashboard…" >/dev/null 2>&1
pkill -f "$D/dash.sh" 2>/dev/null; pkill -f "$D/touch.sh" 2>/dev/null; pkill -f "$D/lib/watchdog.sh" 2>/dev/null
rm -rf /tmp/dash.lock; rm -f /tmp/dash_stop /tmp/dash.pid
# Mở từ màn hình chính Kindle (luôn dọc, đúng chiều): ghi nhớ góc "đứng thẳng" ngay tại đây cho chắc
if [ ! -f /tmp/dash_fw_paused ]; then
  g() { "$F" -e 2>/dev/null | tr ';' '\n' | sed -n "s/^$1=//p" | head -1; }
  r=$(g currentRota); w=$(g viewWidth); h=$(g viewHeight)
  case "$r" in [0-3]) [ -n "$w" ] && [ -n "$h" ] && [ "$w" -lt "$h" ] && echo "$r" > "$D/.rota_up2" ;; esac
fi
[ -f "$D/dash.log" ] && mv -f "$D/dash.log" "$D/dash.log.1"   # giữ nhật ký lần trước để còn tra lỗi
DASH_NOLEARN=1 nohup sh "$D/dash.sh" >> "$D/dash.log" 2>&1 &
sleep 2                                                     # giữ khoá thêm chút: chạm thừa ngay sau cũng bị bỏ qua
