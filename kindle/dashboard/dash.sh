#!/bin/sh
# Kindle Dashboard cho Paperwhite 2 (đã jailbreak).
#   sh dash.sh          chạy liên tục (tắt giao diện Kindle)
#   sh dash.sh --once   vẽ 1 lần, giữ giao diện Kindle (để test)
# Kindle tự vẽ: đồng hồ, lịch tháng, sự kiện Apple Calendar (ICS), thời tiết, ảnh.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/dash.conf"
W=758; H=1024
WX=/tmp/dash_weather.json
ICS=/tmp/dash_calendar.ics
FB=/tmp/dash_fbink
REG="$DIR/fonts/NotoSans-Regular.ttf"
BOLD="$DIR/fonts/NotoSans-Bold.ttf"

log() { echo "$(date '+%F %T') $*"; }
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

# Tải URL về file: thử curl (https), rồi wget. $1=url $2=file $3=chuỗi bắt buộc có
fetch() {
  if curl -s -k -L -m 30 -o "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (curl): $1"
  elif wget -q -T 30 -O "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (wget): $1"
  else log "fetch FAILED: $1"; rm -f "$2.tmp"; return 1
  fi
  mv "$2.tmp" "$2"
}

due() { # $1=file $2=minutes
  [ -s "$1" ] || return 0
  [ $(( $(date +%s) - $(date -r "$1" +%s 2>/dev/null || echo 0) )) -ge $(( $2 * 60 )) ]
}

update_data() {
  need=0
  due "$WX" "$WEATHER_MIN" && need=1
  [ -n "$ICS_URL" ] && due "$ICS" "$CALENDAR_MIN" && need=1
  [ $need = 1 ] || return 0
  wifi_on || { log "no wifi"; return 1; }
  if due "$WX" "$WEATHER_MIN"; then
    fetch "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1" "$WX" '"current"' \
      || fetch "http://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1" "$WX" '"current"'
  fi
  if [ -n "$ICS_URL" ] && due "$ICS" "$CALENDAR_MIN"; then
    : > "$ICS.all"
    for u in $ICS_URL; do
      u=$(echo "$u" | sed 's#^webcal://#https://#')
      fetch "$u" "$ICS.one" "BEGIN:VCALENDAR" && cat "$ICS.one" >> "$ICS.all"
    done
    [ -s "$ICS.all" ] && mv "$ICS.all" "$ICS"
  fi
}

# ---------- Thời tiết ----------
jnum() { echo "$1" | sed -n "s/.*\"$2\":\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"; }
jarr() { echo "$1" | sed -n "s/.*\"$2\":\[\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"; }
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
parse_weather() {
  [ -s "$WX" ] || return 1
  J=$(tr -d '\n\r ' < "$WX")
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
# txt px top left "text" [b] [width] [height]  -> chữ không tràn khỏi khung width x height
txt() {
  f="$REG"; [ "$5" = b ] && f="$BOLD"
  r=0; [ -n "$6" ] && r=$(( W - $3 - $6 )); [ $r -lt 0 ] && r=0
  bt=0; [ -n "$7" ] && bt=$(( H - $2 - $7 )); [ $bt -lt 0 ] && bt=0
  "$FB" -q -b -O $TXTOPT -t "regular=$f,px=$1,top=$2,left=$3,right=$r,bottom=$bt" "$4" >/dev/null 2>&1
}
box() { # top left width height [COLOR]
  "$FB" -q -b -B "${5:-BLACK}" -k "top=$1,left=$2,width=$3,height=$4" >/dev/null 2>&1
}

WD_LONG="Chủ Nhật|Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm|Thứ Sáu|Thứ Bảy"
WD_SHORT="CN|T2|T3|T4|T5|T6|T7"
pick() { echo "$1" | cut -d'|' -f$(( $2 + 1 )); }

epoch_day() { # y m d
  awk -v y="$1" -v m="$2" -v d="$3" 'BEGIN{y-=(m<=2);era=int((y>=0?y:y-399)/400);yoe=y-era*400;doy=int((153*(m+(m>2?-3:9))+2)/5)+d-1;print era*146097+yoe*365+int(yoe/4)-int(yoe/100)+doy-719468}'
}

events() { # in ra: KEY|DAY|MIN|ALL|SUMMARY cho tháng này + DAYS_AHEAD ngày tới
  [ -n "$ICS_URL" ] && [ -s "$ICS" ] || return 0
  awk -v TODAY="$TD" -v FROM="$MFIRST" -v TO="$ETO" -v TZOFF="$TZ_OFFSET_MIN" -f "$DIR/lib/ical.awk" "$ICS" | sort -n
}

render() { # $1 = 1 để nháy đen (full refresh)
  Y=$(date +%Y); M=$(date +%m); D=$(date +%d); M=${M#0}; D=${D#0}
  TD=$(epoch_day "$Y" "$M" "$D"); MFIRST=$(epoch_day "$Y" "$M" 1)
  ETO=$(( TD + DAYS_AHEAD )); MEND=$(( MFIRST + 31 )); [ $MEND -gt $ETO ] && ETO=$MEND
  EV=/tmp/dash_events.txt; events > "$EV"
  b=$(battery)
  photos=$(ls "$DIR"/photos/*.png 2>/dev/null)
  TXTOPT=""

  "$FB" -q -b -k >/dev/null 2>&1

  # Đầu trang
  txt 40 22 40 "$(pick "$WD_LONG" "$(date +%w)"), $D/$M/$Y" b
  [ -n "$b" ] && txt 30 28 600 "Pin $b%" "" 120
  box 76 40 678 3

  # Đồng hồ + thời tiết
  txt 200 88 30 "$(date +%H:%M)" b
  if parse_weather; then
    txt 30 96 450 "$CITY" "" 270
    txt 96 128 450 "${WX_TEMP}°C" b
    txt 30 222 450 "$WX_DESC · ${WX_MIN}–${WX_MAX}°" "" 270
    txt 30 256 450 "Độ ẩm ${WX_HUM}% · Mưa ${WX_RAIN}%" "" 270
  else
    txt 30 160 450 "Chưa có thời tiết" "" 270
  fi
  box 300 40 678 2

  # Lịch tháng (tuần bắt đầu Thứ Hai)
  CW=97; CX=40; GY=356; RH=40
  txt 34 308 40 "Tháng $M/$Y" b
  i=0; for h in T2 T3 T4 T5 T6 T7 CN; do txt 26 "$GY" $(( CX + i * CW + 35 )) "$h" b; i=$((i + 1)); done
  cut -d'|' -f2 "$EV" | sort -u > /tmp/dash_evdays.txt
  awk -v Y="$Y" -v M="$M" -v D="$D" -f "$DIR/lib/month.awk" | while IFS='|' read -r row col day today; do
    c=$(( CX + col * CW + 48 )); x=$(( c - 13 )); y=$(( GY + 40 + row * RH ))
    [ $day -lt 10 ] && x=$(( c - 7 ))
    if [ "$today" = 1 ]; then
      box $(( y - 2 )) $(( c - 34 )) 68 $(( RH - 2 ))
      TXTOPT="-C WHITE"; txt 30 "$y" "$x" "$day" b; TXTOPT=""
    else
      txt 30 "$y" "$x" "$day"
    fi
    grep -qx "$(( MFIRST + day - 1 ))" /tmp/dash_evdays.txt && box $(( y + RH - 8 )) $(( c - 8 )) 16 3
  done
  box 650 40 678 2

  # Sự kiện (trái) + ảnh (phải)
  LW=678; [ -n "$photos" ] && LW=360
  y=664
  if [ -n "$ICS_URL" ]; then
    txt 30 "$y" 40 "Sắp tới" b; y=$(( y + 46 ))
    awk -F'|' -v TD="$TD" '$2 >= TD' "$EV" | head -5 > /tmp/dash_up.txt
    [ -s /tmp/dash_up.txt ] || txt 26 "$y" 40 "Không có sự kiện trong $DAYS_AHEAD ngày tới" "" "$LW"
    while IFS='|' read -r key day min all sum; do
      dd=$(awk -v z="$day" 'BEGIN{z+=719468;era=int((z>=0?z:z-146096)/146097);doe=z-era*146097;yoe=int((doe-int(doe/1460)+int(doe/36524)-int(doe/146096))/365);doy=doe-(365*yoe+int(yoe/4)-int(yoe/100));mp=int((5*doy+2)/153);d=doy-int((153*mp+2)/5)+1;m=mp+(mp<10?3:-9);printf "%d/%d",d,m}')
      wd=$(pick "$WD_SHORT" $(( (day + 4) % 7 )))
      if [ "$day" = "$TD" ]; then when="Hôm nay"; elif [ "$day" = $((TD + 1)) ]; then when="Ngày mai"; else when="$wd $dd"; fi
      if [ "$all" = 1 ]; then when="$when · cả ngày"; else when="$when · $(printf '%02d:%02d' $((min / 60)) $((min % 60)))"; fi
      txt 22 "$y" 40 "$when" b "$LW" 30
      txt 26 $(( y + 26 )) 40 "$sum" "" "$LW" 36
      y=$(( y + 64 ))
    done < /tmp/dash_up.txt
  else
    txt 30 "$y" 40 "Việc cần làm" b; y=$(( y + 46 ))
    grep -v '^#' "$DIR/todo.txt" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -7 | while IFS= read -r item; do
      txt 28 "$y" 40 "•  $item" "" "$LW" 40
      y=$(( y + 46 ))
    done
  fi

  # Ảnh: đổi theo PHOTO_MIN
  if [ -n "$photos" ]; then
    n=$(echo "$photos" | wc -l)
    idx=$(( ( $(date +%s) / (PHOTO_MIN * 60) ) % n + 1 ))
    p=$(echo "$photos" | sed -n "${idx}p")
    eips -g "$p" -x 420 -y 664 >/dev/null 2>&1 || log "eips image failed: $p"
  fi

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
draw() { if [ -n "$SERVER_URL" ]; then render_server "$1"; else render "$1"; fi; }

if [ "$1" = "--once" ]; then
  [ -n "$SERVER_URL" ] || update_data
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
  [ -n "$SERVER_URL" ] || update_data
  full=0; [ $((n % FULL_REFRESH_EVERY)) -eq 0 ] && full=1
  draw $full
  n=$((n + 1))
  s=$(date +%S); s=${s#0}
  sleep $(( REFRESH_MIN * 60 - s ))
done
