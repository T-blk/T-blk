#!/bin/sh
# Name: Dashboard - Test
# Vẽ dashboard 1 lần, không tắt giao diện Kindle. Ghi log vào dashboard/test.log
D=/mnt/us/dashboard
sh "$D/dash.sh" --once > "$D/test.log" 2>&1
