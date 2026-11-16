#!/bin/sh
# Name: Dashboard - Bat
# Bật dashboard. Thoát: chạm "Về Home" (góc trên phải) hoặc bấm nút nguồn.
D=/mnt/us/dashboard
pkill -f "$D/dash.sh" 2>/dev/null
pkill -f "$D/touch.sh" 2>/dev/null
nohup sh "$D/dash.sh" > "$D/dash.log" 2>&1 &
