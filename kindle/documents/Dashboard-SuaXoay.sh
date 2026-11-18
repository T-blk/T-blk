#!/bin/sh
# Name: Dashboard - Sua xoay cham
# Chạy từ màn hình chính Kindle khi cảm ứng bị lệch/ngược so với màn hình:
# học lại chiều "đứng thẳng" từ màn hình chính (luôn dọc, đúng chiều), xoá các chỉnh lật cảm ứng cũ, rồi mở dashboard.
D=/mnt/us/dashboard; S=$D/settings.conf
mkdir /tmp/dash_bat.lock 2>/dev/null || exit 0          # đang có lần chạm khác xử lý -> bỏ qua
trap 'rm -rf /tmp/dash_bat.lock' EXIT
touch /tmp/dash_stop; rm -f /tmp/dash.pid
pkill -f "$D/dash.sh" 2>/dev/null; pkill -f "$D/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
pkill -f "$D/lib/watchdog.sh" 2>/dev/null
i=0; while [ $i -lt 16 ] && pgrep -f "$D/dash.sh" >/dev/null 2>&1; do usleep 500000 2>/dev/null || sleep 1; i=$((i + 1)); done
pkill -9 -f "$D/dash.sh" 2>/dev/null; rm -rf /tmp/dash.lock
[ -f "$D/lib/fw.sh" ] && { . "$D/lib/fw.sh"; fw_resume; }   # đánh thức giao diện Kindle nếu đang bị đóng băng (kể cả khi mất cờ)
rm -f /tmp/dash_rota_orig /tmp/dash_lock_now
sleep 2
F=/tmp/dash_fbink; [ -x "$F" ] || { cp "$D/bin/fbink" "$F" && chmod +x "$F"; }
g() { "$F" -e 2>/dev/null | tr ';' '\n' | sed -n "s/^$1=//p" | head -1; }
r=$(g currentRota); w=$(g viewWidth); h=$(g viewHeight)
case "$r" in [0-3]) [ -n "$w" ] && [ -n "$h" ] && [ "$w" -lt "$h" ] && echo "$r" > "$D/.rota_up2" ;; esac
if [ -f "$S" ]; then grep -v -e '^PORT_TOUCH_INVERT=' -e '^LAND_TOUCH_INVERT=' "$S" > "$S.tmp"; mv "$S.tmp" "$S"; fi
echo "$(date '+%F %T') sua xoay: rota_up2=$(cat "$D/.rota_up2" 2>/dev/null) (rota $r ${w}x$h)" >> "$D/dashboard_fix.log"
touch "$D/.calib_req"                       # mở dashboard bằng màn hình "chạm vào ô" để tự chỉnh hướng cảm ứng
rm -f /tmp/dash_stop
[ -f "$D/dash.log" ] && mv -f "$D/dash.log" "$D/dash.log.1"
DASH_NOLEARN=1 nohup sh "$D/dash.sh" >> "$D/dash.log" 2>&1 &
