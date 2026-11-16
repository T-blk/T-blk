#!/bin/sh
# Name: Dashboard - Tat
# Dừng vòng lặp dashboard và bật lại giao diện Kindle.
pkill -f /mnt/us/dashboard/dash.sh 2>/dev/null
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
start framework 2>/dev/null || start lab126_gui 2>/dev/null
