#!/bin/sh
# Name: Dashboard - Trang thai
# Mở dashboard thẳng vào lưới chọn trạng thái (Tập trung, Họp, Toilet, Cà phê...).
D=/mnt/us/dashboard
echo stpick > "$D/start_view"
pkill -f "$D/dash.sh" 2>/dev/null
pkill -f "$D/touch.sh" 2>/dev/null
nohup sh "$D/dash.sh" > "$D/dash.log" 2>&1 &
