#!/bin/sh
# Kindle Dashboard cho Paperwhite 2 (đã jailbreak).
#   sh dash.sh          chạy liên tục (tắt giao diện Kindle, đọc cảm ứng)
#   sh dash.sh --once   vẽ 1 lần, giữ giao diện Kindle (để test)
# Kindle tự vẽ: đồng hồ, lịch tháng, sự kiện Apple Calendar (ICS), thời tiết, ảnh.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/dash.conf"
: "${NIGHT_START:=22}" "${NIGHT_END:=6}" "${REFRESH_NIGHT_MIN:=$REFRESH_MIN}" "${NIGHT_INVERT:=0}"
: "${ORIENTATION:=doc}" "${ROTATE_LAND:=1}" "${LAND_TOUCH_INVERT:=0}" "${IDLE_RESET_MIN:=5}"
: "${PHOTO_MIN:=60}" "${DAYS_AHEAD:=14}" "${TZ_OFFSET_MIN:=420}"

WX=/tmp/dash_weather.json
CALDIR=/tmp/dash_cal
FB=/tmp/dash_fbink
TAPQ=/tmp/dash_taps
REG="$DIR/fonts/NotoSans-Regular.ttf"
BOLD="$DIR/fonts/NotoSans-Bold.ttf"
ROTF=/sys/class/graphics/fb0/rotate

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
  if curl -s -k -L -m 30 -o "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (curl): ${1%%\?*}"
  elif wget -q -T 30 -O "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (wget): ${1%%\?*}"
  else log "fetch FAILED: ${1%%\?*}"; rm -f "$2.tmp"; return 1
  fi
  mv "$2.tmp" "$2"
}

due() { # $1=file $2=minutes
  [ -s "$1" ] || return 0
  [ $(( $(date +%s) - $(date -r "$1" +%s 2>/dev/null || echo 0) )) -ge $(( $2 * 60 )) ]
}

# ICS_URL: các link cách nhau bằng dấu cách; có thể gắn nhãn: CV=webcal://...  GĐ=webcal://...
update_data() {
  need=0
  due "$WX" "$WEATHER_MIN" && need=1
  [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN" && need=1
  [ $need = 1 ] || return 0
  wifi_on || { log "no wifi"; return 1; }
  if due "$WX" "$WEATHER_MIN"; then
    q="latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
    fetch "https://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"' || fetch "http://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"'
  fi
  if [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN"; then
    mkdir -p "$CALDIR"; k=0
    for u in $ICS_URL; do
      k=$((k + 1)); label=""
      case "$u" in *=webcal://*|*=http://*|*=https://*) label="${u%%=*}"; u="${u#*=}" ;; esac
      u=$(echo "$u" | sed 's#^webcal://#https://#')
      if fetch "$u" "$CALDIR/$k.ics" "BEGIN:VCALENDAR"; then echo "$label" > "$CALDIR/$k.label"; fi
    done
    touch "$CALDIR/stamp"
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

# ---------- Hướng màn hình ----------
ROT=0; [ "$ORIENTATION" = ngang ] && ROT=$ROTATE_LAND
set_rotation() { [ -w "$ROTF" ] && echo "$1" > "$ROTF" 2>/dev/null; }
if [ $((ROT % 2)) = 1 ]; then W=1024; H=758; else W=758; H=1024; fi

# ---------- Vẽ ----------
# txt px top left "text" [b] [width] [height]  -> chữ không tràn khỏi khung width x height
txt() {
  f="$REG"; [ "$5" = b ] && f="$BOLD"
  r=0; [ -n "$6" ] && r=$(( W - $3 - $6 )); [ $r -lt 0 ] && r=0
  bt=0; [ -n "$7" ] && bt=$(( H - $2 - $7 )); [ $bt -lt 0 ] && bt=0
  "$FB" -q -b -O -t "regular=$f,px=$1,top=$2,left=$3,right=$r,bottom=$bt" "$4" >/dev/null 2>&1
}
box() { "$FB" -q -b -B BLACK -k "top=$1,left=$2,width=$3,height=$4" >/dev/null 2>&1; }
frame() { # top left width height  (khung viền 3px)
  box "$1" "$2" "$3" 3; box $(( $1 + $4 - 3 )) "$2" "$3" 3
  box "$1" "$2" 3 "$4"; box "$1" $(( $2 + $3 - 3 )) 3 "$4"
}
refresh() { # $1 = 1 để nháy đen
  inv=""; [ "$NIGHT_INVERT" = 1 ] && is_night && inv="-H"
  if [ "$1" = 1 ]; then "$FB" -q -f $inv -s >/dev/null 2>&1; else "$FB" -q $inv -s >/dev/null 2>&1; fi
}

WD_LONG="Chủ Nhật|Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm|Thứ Sáu|Thứ Bảy"
WD_SHORT="CN|T2|T3|T4|T5|T6|T7"
pick() { echo "$1" | cut -d'|' -f$(( $2 + 1 )); }

epoch_day() { # y m d
  awk -v y="$1" -v m="$2" -v d="$3" 'BEGIN{y-=(m<=2);era=int((y>=0?y:y-399)/400);yoe=y-era*400;doy=int((153*(m+(m>2?-3:9))+2)/5)+d-1;print era*146097+yoe*365+int(yoe/4)-int(yoe/100)+doy-719468}'
}
day_dm() { # epoch-day -> d/m
  awk -v z="$1" 'BEGIN{z+=719468;era=int((z>=0?z:z-146096)/146097);doe=z-era*146097;yoe=int((doe-int(doe/1460)+int(doe/36524)-int(doe/146096))/365);doy=doe-(365*yoe+int(yoe/4)-int(yoe/100));mp=int((5*doy+2)/153);d=doy-int((153*mp+2)/5)+1;m=mp+(mp<10?3:-9);printf "%d/%d",d,m}'
}

# ---------- Trạng thái tương tác ----------
MOFF=0; EVPAGE=0; PHOFF=0; VIEW=main; LADJ=0; LAST_TOUCH=0; LIGHT_NOW=""; NIGHT_WAS=""

is_night() {
  h=$(date +%H); h=${h#0}
  if [ "$NIGHT_START" -gt "$NIGHT_END" ]; then [ "$h" -ge "$NIGHT_START" ] || [ "$h" -lt "$NIGHT_END" ]
  else [ "$h" -ge "$NIGHT_START" ] && [ "$h" -lt "$NIGHT_END" ]; fi
}
light_level() {
  l="$LIGHT_DAY"; is_night && l="$LIGHT_NIGHT"
  [ -z "$l" ] && { echo ""; return; }
  l=$(( l + LADJ )); [ $l -lt 0 ] && l=0; [ $l -gt 24 ] && l=24; echo "$l"
}
set_light() {
  n=0; is_night && n=1
  [ "$n" != "$NIGHT_WAS" ] && { LADJ=0; NIGHT_WAS=$n; }
  l=$(light_level)
  [ -z "$l" ] || [ "$l" = "$LIGHT_NOW" ] && return 0
  if lipc-set-prop com.lab126.powerd flIntensity "$l" 2>/dev/null; then :
  else
    for bl in /sys/class/backlight/*; do
      mx=$(cat "$bl/max_brightness" 2>/dev/null) || continue
      echo $(( l * mx / 24 )) > "$bl/brightness" 2>/dev/null
    done
  fi
  LIGHT_NOW="$l"; log "light -> $l"
}

photo_list() { # $1 = thư mục con ("" | land | full | fullland)
  ls "$DIR/photos/${1:+$1/}"*.png 2>/dev/null
}
pick_photo() { # $1 = thư mục con -> in đường dẫn ảnh hiện tại
  pl=$(photo_list "$1"); [ -n "$pl" ] || return 1
  cnt=$(echo "$pl" | wc -l)
  i=$(( ( $(date +%s) / (PHOTO_MIN * 60) + PHOFF ) % cnt )); [ $i -lt 0 ] && i=$(( i + cnt ))
  echo "$pl" | sed -n "$(( i + 1 ))p"
}

# ---------- Bố cục ----------
set_layout() {
  if [ $W -gt $H ]; then          # NGANG 1024x758
    L_LMIN=640; L_LPLUS=774; L_HOME=884; L_HOMEW=120
    L_CLOCK_PX=170; L_CLOCK_Y=78; L_CLOCK_X=30
    L_WX_Y=300; L_WX_X=40; L_WX_MODE=stack
    CX=530; CW=64; CAL_Y=84; RH=44; CAL_X2=984; CAL_Y2=470
    EV_X=40; EV_Y=480; EV_W=460; EV_N=3; EV_Y2=758
    PH_DIR=land; PH_X=530; PH_Y=478; PH_W=454; PH_H=270
  else                            # DỌC 758x1024
    L_LMIN=372; L_LPLUS=506; L_HOME=578; L_HOMEW=140
    L_CLOCK_PX=200; L_CLOCK_Y=88; L_CLOCK_X=30
    L_WX_Y=96; L_WX_X=450; L_WX_MODE=side
    CX=40; CW=97; CAL_Y=308; RH=40; CAL_X2=718; CAL_Y2=650
    EV_X=40; EV_Y=662; EV_W=678; EV_N=4; EV_Y2=1024
    PH_DIR=""; PH_X=420; PH_Y=664; PH_W=298; PH_H=344
  fi
}

draw_header() {
  b=$(battery)
  txt 40 22 40 "$(pick "$WD_LONG" "$(date +%w)"), $D/$M/$Y" b
  l=$(light_level)
  if [ -n "$l" ] && [ "$ONCE" != 1 ]; then
    frame 14 $L_LMIN 56 53; txt 34 18 $(( L_LMIN + 20 )) "–" b
    txt 24 34 $(( L_LMIN + 64 )) "Đèn $l" "" 70
    frame 14 $L_LPLUS 56 53; txt 34 18 $(( L_LPLUS + 17 )) "+" b
  fi
  if [ "$ONCE" != 1 ]; then
    frame 14 $L_HOME $L_HOMEW 53; txt 28 24 $(( L_HOME + (L_HOMEW - 96) / 2 )) "Về Home" b
  fi
  box 76 40 $(( W - 80 )) 3
  BATT="$b"
}

draw_clock_weather() {
  txt $L_CLOCK_PX $L_CLOCK_Y $L_CLOCK_X "$(date +%H:%M)" b
  pin=""; [ -n "$BATT" ] && pin=" · Pin $BATT%"
  if parse_weather; then
    if [ "$L_WX_MODE" = side ]; then
      txt 26 $L_WX_Y $L_WX_X "$CITY$pin" "" 270
      txt 96 $(( L_WX_Y + 32 )) $L_WX_X "${WX_TEMP}°C" b
      txt 30 $(( L_WX_Y + 126 )) $L_WX_X "$WX_DESC · ${WX_MIN}–${WX_MAX}°" "" 270
      txt 30 $(( L_WX_Y + 160 )) $L_WX_X "Độ ẩm ${WX_HUM}% · Mưa ${WX_RAIN}%" "" 270
    else
      txt 26 $L_WX_Y $L_WX_X "$CITY$pin" "" 460
      txt 84 $(( L_WX_Y + 30 )) $L_WX_X "${WX_TEMP}°C" b
      txt 28 $(( L_WX_Y + 42 )) $(( L_WX_X + 220 )) "$WX_DESC" "" 240
      txt 28 $(( L_WX_Y + 76 )) $(( L_WX_X + 220 )) "${WX_MIN}–${WX_MAX}° · Mưa ${WX_RAIN}%" "" 240
      txt 28 $(( L_WX_Y + 110 )) $(( L_WX_X + 220 )) "Độ ẩm ${WX_HUM}%" "" 240
    fi
  else
    txt 26 $L_WX_Y $L_WX_X "$CITY$pin" "" 300
    txt 30 $(( L_WX_Y + 50 )) $L_WX_X "Chưa có thời tiết" "" 300
  fi
}

events() { # KEY|DAY|MIN|ALL|LABEL|SUMMARY từ FROM..TO
  [ -n "$ICS_URL" ] || return 0
  for f in "$CALDIR"/*.ics; do
    [ -s "$f" ] || continue
    awk -v TODAY="$TD" -v FROM="$1" -v TO="$2" -v TZOFF="$TZ_OFFSET_MIN" \
        -v LABEL="$(cat "${f%.ics}.label" 2>/dev/null)" -f "$DIR/lib/ical.awk" "$f"
  done | sort -n
}

draw_calendar() {
  cy=$Y; cm=$(( M + MOFF ))
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  CFIRST=$(epoch_day $cy $cm 1)
  hl=0; [ $cy = $Y ] && [ $cm = $M ] && hl=$D
  title="Tháng $cm/$cy"; [ $MOFF != 0 ] && title="$title   ‹ chạm tiêu đề: về tháng này"
  txt 34 $CAL_Y $CX "$title" b $(( CAL_X2 - CX ))
  GY=$(( CAL_Y + 48 ))
  i=0; for h in T2 T3 T4 T5 T6 T7 CN; do txt 26 $GY $(( CX + i * CW + CW / 2 - 13 )) "$h" b; i=$((i + 1)); done
  awk -F'|' '{print $2}' "$EV" | sort -u > /tmp/dash_evdays.txt
  awk -v Y="$cy" -v M="$cm" -v D="$hl" -f "$DIR/lib/month.awk" | while IFS='|' read -r row col day today; do
    c=$(( CX + col * CW + CW / 2 )); x=$(( c - 13 )); y=$(( GY + 40 + row * RH ))
    [ $day -lt 10 ] && x=$(( c - 7 ))
    if [ "$today" = 1 ]; then frame $(( y - 2 )) $(( c - 32 )) 64 $(( RH - 2 )); txt 30 "$y" "$x" "$day" b
    else txt 30 "$y" "$x" "$day"; fi
    grep -qx "$(( CFIRST + day - 1 ))" /tmp/dash_evdays.txt && box $(( y + RH - 8 )) $(( c - 8 )) 16 3
  done
}

draw_events() {
  y=$EV_Y; lw=$EV_W; [ -n "$PHOTO" ] && lw=$(( PH_X - EV_X - 20 ))
  if [ -n "$ICS_URL" ]; then
    awk -F'|' -v TD="$TD" '$2 >= TD' "$EV" > /tmp/dash_up.txt
    total=$(wc -l < /tmp/dash_up.txt); pages=$(( (total + EV_N - 1) / EV_N ))
    [ $pages -lt 1 ] && pages=1; [ $EVPAGE -ge $pages ] && EVPAGE=0
    if [ $total = 0 ]; then txt 30 "$y" $EV_X "Không có sự kiện trong $DAYS_AHEAD ngày tới" "" "$lw"; return; fi
    [ $pages -gt 1 ] && txt 22 $(( EV_Y2 - 30 )) $(( EV_X + lw - 120 )) "trang $((EVPAGE + 1))/$pages" "" 120
    sed -n "$(( EVPAGE * EV_N + 1 )),$(( EVPAGE * EV_N + EV_N ))p" /tmp/dash_up.txt | while IFS='|' read -r key day min all label sum; do
      wd=$(pick "$WD_SHORT" $(( (day + 4) % 7 )))
      if [ "$day" = "$TD" ]; then when="Hôm nay"; elif [ "$day" = $((TD + 1)) ]; then when="Ngày mai"; else when="$wd $(day_dm "$day")"; fi
      if [ "$all" = 1 ]; then when="$when · cả ngày"; else when="$when · $(printf '%02d:%02d' $((min / 60)) $((min % 60)))"; fi
      [ -n "$label" ] && when="[$label] $when"
      txt 28 "$y" $EV_X "$when" b "$lw" 40
      txt 36 $(( y + 34 )) $EV_X "$sum" "" "$lw" 52
      y=$(( y + 86 ))
    done
  else
    txt 30 "$y" $EV_X "Việc cần làm" b; y=$(( y + 46 ))
    grep -v '^#' "$DIR/todo.txt" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -$(( EV_N + 2 )) | while IFS= read -r item; do
      txt 28 "$y" $EV_X "•  $item" "" "$lw" 40; y=$(( y + 46 ))
    done
  fi
}

render_main() { # $1 = 1 nháy đen
  Y=$(date +%Y); M=$(date +%m); D=$(date +%d); M=${M#0}; D=${D#0}
  TD=$(epoch_day "$Y" "$M" "$D")
  set_layout
  PHOTO=$(pick_photo "$PH_DIR")
  # khoảng sự kiện: tháng đang xem + DAYS_AHEAD ngày tới
  cm=$(( M + MOFF )); cy=$Y
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  f=$(epoch_day $cy $cm 1); t=$(( f + 31 )); [ $f -gt $TD ] && f=$TD
  [ $t -lt $(( TD + DAYS_AHEAD )) ] && t=$(( TD + DAYS_AHEAD ))
  EV=/tmp/dash_events.txt; events "$f" "$t" > "$EV"

  "$FB" -q -b -k >/dev/null 2>&1
  draw_header
  draw_clock_weather
  if [ $W -gt $H ]; then box 470 40 460 2; box 84 510 2 664; else box 300 40 678 2; fi
  draw_calendar
  [ $W -gt $H ] || box 650 40 678 2
  draw_events
  if [ -n "$PHOTO" ]; then
    eips -g "$PHOTO" -x $PH_X -y $PH_Y >/dev/null 2>&1 || log "eips image failed: $PHOTO"
  fi
  refresh "$1"
}

render_photo() { # xem ảnh toàn màn hình
  d=full; [ $W -gt $H ] && d=fullland
  p=$(pick_photo "$d")
  "$FB" -q -b -k >/dev/null 2>&1
  if [ -n "$p" ]; then eips -g "$p" -x 0 -y 0 >/dev/null 2>&1 || log "eips image failed: $p"
  else
    set_layout; p=$(pick_photo "$PH_DIR")
    [ -n "$p" ] && eips -g "$p" -x $(( (W - PH_W) / 2 )) -y $(( (H - PH_H) / 2 )) >/dev/null 2>&1
  fi
  "$FB" -q -b -O -t "regular=$REG,px=22,top=$(( H - 34 )),left=20" "Chạm trái/phải: ảnh trước/sau · chạm phía trên: quay lại" >/dev/null 2>&1
  refresh 1
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
  if [ -n "$SERVER_URL" ]; then render_server "$1"
  elif [ "$VIEW" = photo ]; then render_photo
  else render_main "$1"; fi
}

# ---------- Chạm ----------
go_home() {
  log "go home ($1)"
  "$FB" -q -c -m -M -t "regular=$BOLD,px=44" "Đang về Home…" >/dev/null 2>&1
  pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  set_rotation 0
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
  start framework 2>/dev/null || start lab126_gui 2>/dev/null
  rm -f /tmp/dash.pid
  exit 0
}

# toạ độ màn hình dọc (do touch.sh gửi) -> toạ độ theo hướng hiện tại
to_view() {
  px=$1; py=$2; VX=$px; VY=$py
  [ $((ROT % 2)) = 1 ] || return 0
  a=$ROT; [ "$LAND_TOUCH_INVERT" = 1 ] && a=$(( 4 - ROT ))
  if [ $a = 1 ]; then VX=$py; VY=$(( 757 - px )); else VX=$(( 1023 - py )); VY=$px; fi
}

handle_tap() {
  to_view "$1" "$2"; x=$VX; y=$VY
  LAST_TOUCH=$(date +%s)
  log "tap ($x,$y) view=$VIEW"
  if [ "$VIEW" = photo ]; then
    if [ $y -lt 150 ]; then VIEW=main
    elif [ $x -lt $(( W / 2 )) ]; then PHOFF=$((PHOFF - 1)); else PHOFF=$((PHOFF + 1)); fi
    return
  fi
  set_layout
  if [ $y -le 90 ]; then
    if [ $x -ge $L_HOME ]; then go_home "tap Home"
    elif [ $x -ge $L_LMIN ] && [ $x -lt $(( L_LMIN + 70 )) ]; then LADJ=$((LADJ - 2)); set_light
    elif [ $x -ge $L_LPLUS ] && [ $x -lt $(( L_LPLUS + 70 )) ]; then LADJ=$((LADJ + 2)); set_light
    fi
    return
  fi
  if [ $x -ge $CX ] && [ $x -le $CAL_X2 ] && [ $y -ge $CAL_Y ] && [ $y -le $CAL_Y2 ]; then
    if [ $y -lt $(( CAL_Y + 44 )) ]; then MOFF=0
    elif [ $x -lt $(( (CX + CAL_X2) / 2 )) ]; then MOFF=$((MOFF - 1)); else MOFF=$((MOFF + 1)); fi
    return
  fi
  PHOTO=$(pick_photo "$PH_DIR")
  if [ -n "$PHOTO" ] && [ $x -ge $PH_X ] && [ $y -ge $PH_Y ] && [ $x -le $(( PH_X + PH_W )) ] && [ $y -le $(( PH_Y + PH_H )) ]; then
    VIEW=photo; return
  fi
  if [ $x -ge $EV_X ] && [ $y -ge $EV_Y ] && [ $y -le $EV_Y2 ]; then EVPAGE=$((EVPAGE + 1)); return; fi
}

idle_reset() {
  [ $LAST_TOUCH = 0 ] && return
  idle=$(( $(date +%s) - LAST_TOUCH ))
  if [ $idle -ge $(( IDLE_RESET_MIN * 60 )) ]; then MOFF=0; EVPAGE=0; VIEW=main; LAST_TOUCH=0; fi
}

process_taps() { # trả về 0 nếu có chạm
  [ -s "$TAPQ" ] || return 1
  mv "$TAPQ" "$TAPQ.work" 2>/dev/null || return 1
  while read -r tx ty; do [ -n "$ty" ] && handle_tap "$tx" "$ty"; done < "$TAPQ.work"
  rm -f "$TAPQ.work"
  return 0
}

# ---------- Chạy ----------
ONCE=0
if [ "$1" = "--once" ]; then
  ONCE=1
  [ -n "$SERVER_URL" ] || update_data
  draw 1; log "drawn once"; exit 0
fi

echo $$ > /tmp/dash.pid
rm -f "$TAPQ"
if is_night; then NIGHT_WAS=1; else NIGHT_WAS=0; fi
trap 'WOKE=1' USR1
stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
sleep 2
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
set_rotation "$ROT"
pkill -f "$DIR/touch.sh" 2>/dev/null
sh "$DIR/touch.sh" >> "$DIR/dash.log" 2>&1 &

n=0
while true; do
  b=$(battery)
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    "$FB" -q -c -m -M -t "regular=$BOLD,px=40" "PIN YẾU – HÃY SẠC KINDLE ($b%)" >/dev/null 2>&1 \
      || { eips -c; eips 10 20 "PIN YEU - HAY SAC KINDLE ($b%)"; }
    log "low battery, stopping"; set_rotation 0; exit 0
  fi
  [ -n "$SERVER_URL" ] || update_data
  idle_reset
  set_light
  full=0; [ $((n % FULL_REFRESH_EVERY)) -eq 0 ] && full=1
  draw $full
  n=$((n + 1))
  every=$REFRESH_MIN; is_night && every=$REFRESH_NIGHT_MIN
  s=$(date +%S); s=${s#0}
  WOKE=0
  sleep $(( every * 60 - s )) & SP=$!
  while :; do
    process_taps && { kill $SP 2>/dev/null; break; }
    wait $SP 2>/dev/null && break            # hết giờ ngủ -> vẽ lại
    kill -0 $SP 2>/dev/null || { process_taps; break; }
    # bị đánh thức bởi USR1 -> vòng lặp xử lý chạm
  done
  wait $SP 2>/dev/null
done
