#!/bin/sh
# Name: Dashboard - Bat
# Bật dashboard: tắt giao diện Kindle, hiện bảng tin, làm mới định kỳ.
# Thoát: giữ nút nguồn ~20 giây để khởi động lại Kindle.
D=/mnt/us/dashboard
pkill -f "$D/dash.sh" 2>/dev/null
nohup sh "$D/dash.sh" > "$D/dash.log" 2>&1 &
