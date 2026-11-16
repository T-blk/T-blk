#!/bin/sh
# Name: Dashboard - Do cam ung
# Dò cảm ứng 25 giây: chạm 4 góc rồi bấm nút nguồn. Log: dashboard/touch.log
D=/mnt/us/dashboard
sh "$D/touch.sh" --probe > "$D/touch.log" 2>&1
