#!/bin/sh
# Name: Dashboard - Cap nhat
# Tải và cài bản dashboard mới nhất qua Wi-Fi (giữ nguyên cài đặt, link lịch, ảnh).
# Hiện chữ ngay khi chạm; chạm thêm lần nữa trong lúc đang cập nhật sẽ được báo "đang có lần cập nhật khác".
F=/tmp/dash_fbink; [ -x "$F" ] || { cp /mnt/us/dashboard/bin/fbink "$F" 2>/dev/null && chmod +x "$F"; }
"$F" -q -m -M -t "regular=/mnt/us/dashboard/fonts/NotoSans-Bold.ttf,px=36" "Đang kiểm tra bản mới…" >/dev/null 2>&1
sh /mnt/us/dashboard/update.sh --install >> /mnt/us/dashboard_update.log 2>&1
