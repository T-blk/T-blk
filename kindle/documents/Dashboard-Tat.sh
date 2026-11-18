#!/bin/sh
# Name: Dashboard - Tat
# Dừng dashboard và bật lại giao diện Kindle (trả hướng màn hình về như cũ).
touch /tmp/dash_stop; rm -f /tmp/dash.pid
pkill -f /mnt/us/dashboard/dash.sh 2>/dev/null
pkill -f /mnt/us/dashboard/touch.sh 2>/dev/null
pkill -f "dd if=/dev/input" 2>/dev/null
pkill -f /mnt/us/dashboard/lib/watchdog.sh 2>/dev/null; rm -rf /tmp/dash.lock; rm -f /tmp/dash_alive
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
if [ -f /mnt/us/dashboard/lib/fw.sh ]; then . /mnt/us/dashboard/lib/fw.sh; fw_resume
else status framework 2>/dev/null | grep -q running || start framework 2>/dev/null || start lab126_gui 2>/dev/null; fi
o=$(cat /tmp/dash_lock_orig 2>/dev/null); [ -n "$o" ] || o=U
i=0; while [ $i -lt 120 ]; do
  [ -n "$(lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null)" ] && { sleep 2; lipc-set-prop com.lab126.winmgr orientationLock "$o"; break; }
  sleep 1; i=$((i + 1))
done
