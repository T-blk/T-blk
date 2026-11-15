#!/bin/sh
# Vòng lặp dashboard cho Kindle Paperwhite 2 (đã jailbreak).
# Tải PNG từ server, vẽ bằng eips, ngủ, lặp lại.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/dash.conf"
IMG=/tmp/dashboard.png

log() { echo "$(date '+%F %T') $*"; }

battery() { lipc-get-prop com.lab126.powerd battLevel 2>/dev/null || gasgauge-info -c 2>/dev/null | tr -d '%'; }

wait_wifi() {
  lipc-set-prop com.lab126.wifid enable 1
  i=0
  while [ $i -lt 30 ]; do
    [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && return 0
    sleep 1; i=$((i + 1))
  done
  return 1
}

draw() {  # $1 = 1 for full refresh
  b=$(battery)
  if wait_wifi && wget -q -T 20 -O "$IMG.tmp" "$SERVER_URL?battery=$b"; then
    mv "$IMG.tmp" "$IMG"
    [ "$1" = 1 ] && eips -c
    eips -g "$IMG" $([ "$1" = 1 ] && echo -f)
    log "drawn (battery $b%)"
  else
    eips 1 1 "Mat ket noi server $(date +%H:%M)  "
    log "fetch failed"
  fi
}

prepare() {
  # Tạm dừng giao diện Amazon để không vẽ đè lên dashboard
  stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
  sleep 2
  lipc-set-prop com.lab126.powerd preventScreenSaver 1
}

if [ "$1" = "--once" ]; then
  draw 1
  exit 0
fi

prepare
n=0
while true; do
  b=$(battery)
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    eips -c; eips 10 20 "PIN YEU - HAY SAC KINDLE ($b%)"
    log "low battery, stopping"; exit 0
  fi
  full=0; [ $((n % FULL_REFRESH_EVERY)) -eq 0 ] && full=1
  draw $full
  n=$((n + 1))
  secs=$((REFRESH_MIN * 60))
  if [ "$DEEP_SLEEP" = 1 ] && [ -e "$RTC_DEV" ]; then
    lipc-set-prop com.lab126.wifid enable 0
    rtcwake -d "$RTC_DEV" -m mem -s "$secs" >/dev/null 2>&1 || sleep "$secs"
  else
    sleep "$secs"
  fi
done
