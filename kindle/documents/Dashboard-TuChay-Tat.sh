#!/bin/sh
# Name: Dashboard - Tu chay: Tat
# Gỡ tự chạy khi khởi động.
D=/mnt/us/dashboard
{
  echo "$(date '+%F %T') uninstall"
  rm -f "$D/AUTOSTART"
  mntroot rw
  rm -f /etc/upstart/kindle-dashboard.conf
  mntroot ro
  echo "done"
} >> "$D/autostart.log" 2>&1
