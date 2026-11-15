#!/bin/sh
# Chạy dash.sh ở nền, tách khỏi KUAL
DIR="$(cd "$(dirname "$0")/.." && pwd)"
nohup sh "$DIR/bin/dash.sh" > "$DIR/dash.log" 2>&1 &
echo $! > /tmp/dashboard.pid
