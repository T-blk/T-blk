#!/bin/sh
[ -f /tmp/dashboard.pid ] && kill "$(cat /tmp/dashboard.pid)" 2>/dev/null
rm -f /tmp/dashboard.pid
lipc-set-prop com.lab126.powerd preventScreenSaver 0
# Khởi động lại giao diện gốc của Kindle
start framework 2>/dev/null || start lab126_gui 2>/dev/null
