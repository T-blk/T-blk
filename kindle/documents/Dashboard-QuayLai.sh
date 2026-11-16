#!/bin/sh
# Name: Dashboard - Quay lai ban cu
# Quay lại bản dashboard trước lần cập nhật gần nhất.
sh /mnt/us/dashboard/update.sh --rollback >> /mnt/us/dashboard_update.log 2>&1
