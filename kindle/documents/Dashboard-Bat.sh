#!/bin/sh
# Name: Dashboard - Bat
# Bật dashboard. Thoát: chạm "Về Home" (góc trên phải) hoặc bấm nút nguồn.
D=/mnt/us/dashboard
pkill -f "$D/dash.sh" 2>/dev/null
pkill -f "$D/touch.sh" 2>/dev/null
# Mở từ màn hình chính Kindle (luôn dọc, đúng chiều): ghi nhớ góc "đứng thẳng" ngay tại đây cho chắc
if [ ! -f /tmp/dash_fw_paused ]; then
  F=/tmp/dash_fbink; [ -x "$F" ] || { cp "$D/bin/fbink" "$F" && chmod +x "$F"; }
  g() { "$F" -e 2>/dev/null | tr ';' '\n' | sed -n "s/^$1=//p" | head -1; }
  r=$(g currentRota); w=$(g viewWidth); h=$(g viewHeight)
  case "$r" in [0-3]) [ -n "$w" ] && [ -n "$h" ] && [ "$w" -lt "$h" ] && echo "$r" > "$D/.rota_up2" ;; esac
fi
DASH_NOLEARN=1 nohup sh "$D/dash.sh" > "$D/dash.log" 2>&1 &
