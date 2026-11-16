#!/bin/sh
# Name: Dashboard - Tu chay: Bat
# Cài tự chạy: mỗi lần Kindle khởi động, 45 giây sau dashboard tự bật.
# Gỡ: chạy "Dashboard - Tu chay: Tat", hoặc xoá file dashboard/AUTOSTART qua USB.
D=/mnt/us/dashboard
LOG="$D/autostart.log"
{
  echo "$(date '+%F %T') install"
  mntroot rw
  cat > /etc/upstart/kindle-dashboard.conf <<'JOB'
# Kindle Dashboard autostart (cài bởi Dashboard - Tu chay: Bat)
start on started framework or started lab126_gui
script
  [ -f /mnt/us/dashboard/AUTOSTART ] || exit 0
  [ -f /tmp/dash_autostarted ] && exit 0
  touch /tmp/dash_autostarted
  sleep 45
  [ -f /mnt/us/dashboard/AUTOSTART ] || exit 0
  exec sh /mnt/us/dashboard/dash.sh >> /mnt/us/dashboard/dash.log 2>&1
end script
JOB
  r=$?
  mntroot ro
  [ $r = 0 ] && touch "$D/AUTOSTART" && echo "ok" || echo "FAILED ($r)"
  ls -l /etc/upstart/kindle-dashboard.conf
} >> "$LOG" 2>&1
