#!/bin/sh
# Name: Dashboard - Trang thai
# Mở dashboard thẳng vào lưới chọn trạng thái (Tập trung, Họp, Toilet, Cà phê...).
# Dùng chung cách mở an toàn của "Dashboard - Bat" (không bao giờ chạy 2 bản cùng lúc).
D=/mnt/us/dashboard
echo stpick > "$D/start_view"
exec sh /mnt/us/documents/Dashboard-Bat.sh
