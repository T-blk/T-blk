#!/bin/sh
# Kindle Dashboard cho Paperwhite 2 (đã jailbreak).
#   sh dash.sh          chạy liên tục (tắt giao diện Kindle)
#   sh dash.sh --once   vẽ 1 lần, giữ giao diện Kindle (để test)
# Kindle tự vẽ bằng FBInk + phông Noto Sans; không cần máy tính.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/dash.conf"
W=758
CACHE=/tmp/dash_weather.json
FB=/tmp/dash_fbink
REG="$DIR/fonts/NotoSans-Regular.ttf"
BOLD="$DIR/fonts/NotoSans-Bold.ttf"

log() { echo "$(date '+%F %T') $*"; }

# FAT (/mnt/us) có thể không cho chạy file; chép FBInk sang /tmp (tmpfs).
cp "$DIR/bin/fbink" "$FB" 2>/dev/null && chmod +x "$FB"

battery() { lipc-get-prop com.lab126.powerd battLevel 2>/dev/null || gasgauge-info -c 2>/dev/null | tr -d '%'; }

wifi_on() {
  lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
  lipc-set-prop com.lab126.wifid enable 1 2>/dev/null
  i=0
  while [ $i -lt 30 ]; do
    [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && return 0
    sleep 1; i=$((i + 1))
  done
  return 1
}

# ---------- Thời tiết (Open-Meteo, không cần API key) ----------
fetch_weather() {
  q="latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
  wifi_on || { log "weather: no wifi"; return 1; }
  if curl -s -k -m 20 -o "$CACHE.tmp" "https://api.open-meteo.com/v1/forecast?$q" && grep -q '"current"' "$CACHE.tmp"; then
    log "weather: ok (curl https)"
  elif wget -q -T 20 -O "$CACHE.tmp" "http://api.open-meteo.com/v1/forecast?$q" && grep -q '"current"' "$CACHE.tmp"; then
    log "weather: ok (wget http)"
  else
    log "weather: fetch failed"; rm -f "$CACHE.tmp"; return 1
  fi
  mv "$CACHE.tmp" "$CACHE"
}

jnum() { # $1=json $2=key -> first number after "key":
  echo "$1" | sed -n "s/.*\"$2\":\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"
}
jarr() { # $1=json $2=key -> first number in "key":[...]
  echo "$1" | sed -n "s/.*\"$2\":\[\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"
}
round() { awk -v x="$1" 'BEGIN{ if (x=="") exit; printf "%d", (x<0 ? x-0.5 : x+0.5) }'; }

weather_desc() {
  case "$1" in
    0) echo "Trời quang" ;; 1) echo "Ít mây" ;; 2) echo "Mây rải rác" ;; 3) echo "Nhiều mây" ;;
    45|48) echo "Sương mù" ;; 51|53|55) echo "Mưa phùn" ;; 56|57) echo "Mưa phùn lạnh" ;;
    61) echo "Mưa nhẹ" ;; 63) echo "Mưa vừa" ;; 65) echo "Mưa to" ;;
    80) echo "Mưa rào nhẹ" ;; 81) echo "Mưa rào" ;; 82) echo "Mưa rào to" ;;
    95) echo "Dông" ;; 96|99) echo "Dông, mưa đá" ;; *) echo "—" ;;
  esac
}

parse_weather() { # sets WX_* vars; returns 1 if no data
  [ -s "$CACHE" ] || return 1
  J=$(tr -d '\n\r ' < "$CACHE")
  CUR=$(echo "$J" | sed -n 's/.*"current":{\([^}]*\)}.*/\1/p')
  WX_TEMP=$(round "$(jnum "$CUR" temperature_2m)")
  WX_HUM=$(jnum "$CUR" relative_humidity_2m)
  WX_DESC=$(weather_desc "$(jnum "$CUR" weather_code)")
  WX_MAX=$(round "$(jarr "$J" temperature_2m_max)")
  WX_MIN=$(round "$(jarr "$J" temperature_2m_min)")
  WX_RAIN=$(jarr "$J" precipitation_probability_max)
  [ -n "$WX_TEMP" ]
}

# ---------- Vẽ ----------
txt() { # px top left "text" [b]
  f="$REG"; [ "$5" = b ] && f="$BOLD"
  "$FB" -q -b -t "regular=$f,px=$1,top=$2,left=$3" "$4" >/dev/null 2>&1
}
hline() { # top thickness
  "$FB" -q -b -B BLACK -k "top=$1,left=40,width=$((W - 80)),height=$2" >/dev/null 2>&1
}

WEEKDAYS="Chủ Nhật|Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm|Thứ Sáu|Thứ Bảy"

render() { # $1 = 1 for flashing full refresh
  b=$(battery)
  wd=$(echo "$WEEKDAYS" | cut -d'|' -f$(( $(date +%w) + 1 )))

  "$FB" -q -b -k >/dev/null 2>&1                       # xoá trắng (chưa refresh)
  txt 32 28 40 "$TITLE" b
  st="$(date +%H:%M)"; [ -n "$b" ] && st="$st · Pin $b%"
  txt 24 34 470 "$st"
  hline 82 3

  txt 190 80 32 "$(date +%H:%M)" b
  txt 40 315 40 "$wd, $(date +%d/%m/%Y)"
  hline 380 2

  if parse_weather; then
    txt 26 392 40 "$CITY"
    txt 100 418 36 "${WX_TEMP}°C" b
    txt 28 430 400 "$WX_DESC"
    txt 28 468 400 "Cao ${WX_MAX}° / Thấp ${WX_MIN}°"
    txt 28 506 400 "Độ ẩm ${WX_HUM}%"
    txt 28 544 400 "Khả năng mưa ${WX_RAIN}%"
  else
    txt 26 400 40 "$CITY: chưa có dữ liệu thời tiết"
  fi
  hline 594 2

  txt 32 610 40 "Việc hôm nay" b
  y=665
  grep -v '^#' "$DIR/todo.txt" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -8 | while IFS= read -r item; do
    txt 30 "$y" 40 "•  $item"
    y=$((y + 46))
  done

  [ -n "$QUOTE" ] && txt 24 975 40 "“$QUOTE”"

  if [ "$1" = 1 ]; then "$FB" -q -f -s >/dev/null 2>&1; else "$FB" -q -s >/dev/null 2>&1; fi
}

# ---------- Chế độ server (tuỳ chọn) ----------
render_server() {
  b=$(battery)
  if wifi_on && wget -q -T 20 -O /tmp/dashboard.png "$SERVER_URL?battery=$b"; then
    [ "$1" = 1 ] && eips -c
    if [ "$1" = 1 ]; then eips -f -g /tmp/dashboard.png; else eips -g /tmp/dashboard.png; fi
  else
    eips 1 1 "Mat ket noi server $(date +%H:%M)  "; log "server fetch failed: $SERVER_URL"
  fi
}

draw() {
  if [ -n "$SERVER_URL" ]; then render_server "$1"; else render "$1"; fi
}

weather_due() {
  [ -n "$SERVER_URL" ] && return 1
  [ -s "$CACHE" ] || return 0
  age=$(( $(date +%s) - $(date -r "$CACHE" +%s 2>/dev/null || echo 0) ))
  [ "$age" -ge $((WEATHER_MIN * 60)) ]
}

if [ "$1" = "--once" ]; then
  [ -n "$SERVER_URL" ] || fetch_weather
  draw 1; log "drawn once"; exit 0
fi

stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
sleep 2
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null

n=0
while true; do
  b=$(battery)
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    "$FB" -q -c -m -M -t "regular=$BOLD,px=40" "PIN YẾU – HÃY SẠC KINDLE ($b%)" >/dev/null 2>&1 \
      || { eips -c; eips 10 20 "PIN YEU - HAY SAC KINDLE ($b%)"; }
    log "low battery, stopping"; exit 0
  fi
  weather_due && fetch_weather
  full=0; [ $((n % FULL_REFRESH_EVERY)) -eq 0 ] && full=1
  draw $full
  n=$((n + 1))
  # ngủ đến đầu phút kế tiếp để đồng hồ chạy đúng phút
  s=$(date +%S); s=${s#0}
  sleep $(( REFRESH_MIN * 60 - s ))
done
