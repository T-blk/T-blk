#!/bin/sh
# Name: Dashboard - Tat
# Dừng dashboard và bật lại giao diện Kindle.
touch /tmp/dash_stop; rm -f /tmp/dash.pid
pkill -f /mnt/us/dashboard/dash.sh 2>/dev/null
pkill -f /mnt/us/dashboard/touch.sh 2>/dev/null
pkill -f "dd if=/dev/input" 2>/dev/null
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
status framework 2>/dev/null | grep -q running || start framework 2>/dev/null || start lab126_gui 2>/dev/null
