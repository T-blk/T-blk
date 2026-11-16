#!/bin/sh
# Kindle Dashboard cho Paperwhite 2 (đã jailbreak).
#   sh dash.sh          chạy liên tục (tắt giao diện Kindle, đọc cảm ứng)
#   sh dash.sh --once   vẽ 1 lần, giữ giao diện Kindle (để test)
# Kindle tự vẽ: đồng hồ (4 kiểu), ngày + âm lịch, lịch tháng, sự kiện ICS,
# thời tiết có biểu tượng, ảnh; có trang Cài đặt và trang Chọn ảnh ngay trên máy.
DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$DIR/settings.conf"

load_conf() {
  . "$DIR/dash.conf"
  [ -f "$SETTINGS" ] && . "$SETTINGS"
  : "${NIGHT_START:=22}" "${NIGHT_END:=6}" "${REFRESH_MIN:=1}" "${REFRESH_NIGHT_MIN:=$REFRESH_MIN}" "${NIGHT_INVERT:=0}"
  : "${ORIENTATION:=doc}" "${ROTATE_LAND:=1}" "${LAND_TOUCH_INVERT:=0}" "${IDLE_RESET_MIN:=5}"
  : "${PHOTO_MIN:=60}" "${PHOTO_MODE:=auto}" "${PHOTO_FIXED:=}" "${DAYS_AHEAD:=14}" "${TZ_OFFSET_MIN:=420}"
  : "${CLOCK_STYLE:=so24}" "${DATE_STYLE:=dai}" "${SHOW_LUNAR:=1}" "${TODAY_STYLE:=vong}" "${WEEK_START:=1}"
  : "${WEATHER_ICON:=1}" "${WEATHER_MIN:=30}" "${CALENDAR_MIN:=30}" "${FULL_REFRESH_EVERY:=20}" "${LOW_BATTERY:=5}"
}
load_conf
. "$DIR/lib/icons.sh"

WX=/tmp/dash_weather.json
CALDIR=/tmp/dash_cal
FB=/tmp/dash_fbink
TAPQ=/tmp/dash_taps
REG="$DIR/fonts/NotoSans-Regular.ttf"
BOLD="$DIR/fonts/NotoSans-Bold.ttf"
SYM="$DIR/fonts/symbols.ttf"
ROTF=/sys/class/graphics/fb0/rotate

log() { echo "$(date '+%F %T') $*"; sync 2>/dev/null; }
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

fetch() { # $1=url $2=file $3=chuỗi bắt buộc có
  if curl -s -k -L -m 30 -o "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (curl): ${1%%\?*}"
  elif wget -q -T 30 -O "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (wget): ${1%%\?*}"
  else log "fetch FAILED: ${1%%\?*}"; rm -f "$2.tmp"; return 1
  fi
  mv "$2.tmp" "$2"
}

due() { [ -s "$1" ] || return 0; [ $(( $(date +%s) - $(date -r "$1" +%s 2>/dev/null || echo 0) )) -ge $(( $2 * 60 )) ]; }

DATA_CHANGED=0
update_data() {
  need=0
  due "$WX" "$WEATHER_MIN" && need=1
  [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN" && need=1
  [ $need = 1 ] || return 0
  wifi_on || { log "no wifi"; return 1; }
  if due "$WX" "$WEATHER_MIN"; then
    q="latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=1"
    fetch "https://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"' || fetch "http://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"'
  fi
  if [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN"; then
    mkdir -p "$CALDIR"; k=0
    for u in $ICS_URL; do
      k=$((k + 1)); label=""
      case "$u" in *=webcal://*|*=http://*|*=https://*) label="${u%%=*}"; u="${u#*=}" ;; esac
      u=$(echo "$u" | sed 's#^webcal://#https://#')
      fetch "$u" "$CALDIR/$k.ics" "BEGIN:VCALENDAR" && echo "$label" > "$CALDIR/$k.label"
    done
    touch "$CALDIR/stamp"
  fi
  DATA_CHANGED=1
}

# ---------- Thời tiết ----------
jnum() { echo "$1" | sed -n "s/.*\"$2\":\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"; }
jarr() { echo "$1" | sed -n "s/.*\"$2\":\[\(-\{0,1\}[0-9][0-9.]*\).*/\1/p"; }
jtime() { echo "$1" | sed -n "s/.*\"$2\":\[\"[0-9-]*T\([0-9:]*\)\".*/\1/p"; }
round() { awk -v x="$1" 'BEGIN{ if (x=="") exit; printf "%d", (x<0 ? x-0.5 : x+0.5) }'; }
weather_desc() {
  case "$1" in
    0) echo "Trời quang" ;; 1) echo "Ít mây" ;; 2) echo "Mây rải rác" ;; 3) echo "Nhiều mây" ;;
    45|48) echo "Sương mù" ;; 51|53|55) echo "Mưa phùn" ;; 56|57) echo "Mưa phùn lạnh" ;;
    61) echo "Mưa nhẹ" ;; 63) echo "Mưa vừa" ;; 65) echo "Mưa to" ;; 66|67) echo "Mưa lạnh" ;;
    71|73|75|77|85|86) echo "Tuyết" ;; 80) echo "Mưa rào nhẹ" ;; 81) echo "Mưa rào" ;; 82) echo "Mưa rào to" ;;
    95) echo "Dông" ;; 96|99) echo "Dông, mưa đá" ;; *) echo "—" ;;
  esac
}
weather_icon() { # $1=code $2=is_day
  case "$1" in
    0) [ "$2" = 0 ] && echo "$I_MOON" || echo "$I_SUN" ;;
    1|2) [ "$2" = 0 ] && echo "$I_PCLOUD_N" || echo "$I_PCLOUD_D" ;;
    3) echo "$I_CLOUD" ;; 45|48) echo "$I_FOG" ;; 51|53|55|56|57) echo "$I_DRIZZLE" ;;
    61|80) echo "$I_SHOWER" ;; 63|65|66|67|81|82) echo "$I_RAIN" ;;
    71|73|75|77|85|86) echo "$I_SNOW" ;; 95|96|99) echo "$I_THUNDER" ;; *) echo "$I_CLOUD" ;;
  esac
}
parse_weather() {
  [ -s "$WX" ] || return 1
  J=$(tr -d '\n\r ' < "$WX")
  CUR=$(echo "$J" | sed -n 's/.*"current":{\([^}]*\)}.*/\1/p')
  WX_TEMP=$(round "$(jnum "$CUR" temperature_2m)")
  WX_HUM=$(jnum "$CUR" relative_humidity_2m)
  code=$(jnum "$CUR" weather_code); isday=$(jnum "$CUR" is_day)
  WX_DESC=$(weather_desc "$code"); WX_ICON=$(weather_icon "$code" "$isday")
  WX_MAX=$(round "$(jarr "$J" temperature_2m_max)")
  WX_MIN=$(round "$(jarr "$J" temperature_2m_min)")
  WX_RAIN=$(jarr "$J" precipitation_probability_max)
  WX_RISE=$(jtime "$J" sunrise); WX_SET=$(jtime "$J" sunset)
  [ -n "$WX_TEMP" ]
}

# ---------- Hướng màn hình ----------
set_rotation() { [ -w "$ROTF" ] && echo "$1" > "$ROTF" 2>/dev/null; }
apply_orientation() {
  ROT=0; [ "$ORIENTATION" = ngang ] && ROT=$ROTATE_LAND
  if [ $((ROT % 2)) = 1 ]; then W=1024; H=758; else W=758; H=1024; fi
}
apply_orientation

# ---------- Vẽ cơ bản ----------
# txt px top left "text" [style] [width] [height]   style: b = đậm, s = biểu tượng
txt() {
  case "$5" in b) f="$BOLD" ;; s) f="$SYM" ;; *) f="$REG" ;; esac
  r=0; [ -n "$6" ] && r=$(( W - $3 - $6 )); [ $r -lt 0 ] && r=0
  bt=0; [ -n "$7" ] && bt=$(( H - $2 - $7 )); [ $bt -lt 0 ] && bt=0
  "$FB" -q -b -O $TXTOPT -t "regular=$f,px=$1,top=$2,left=$3,right=$r,bottom=$bt" "$4" >/dev/null 2>&1
}
# chiều rộng ước lượng của chữ số / chữ ngắn (Noto Sans): ~0.43*px mỗi ký tự số
numw() { echo $(( ${#1} * $2 * 43 / 100 )); }
ctxt() { # px top center_x "text" [style]  (căn giữa theo ước lượng)
  w=$(numw "$4" "$1"); txt "$1" "$2" $(( $3 - w / 2 )) "$4" "$5"
}
box() { "$FB" -q -b -B "${5:-BLACK}" -k "top=$1,left=$2,width=$3,height=$4" >/dev/null 2>&1; }
frame() { box "$1" "$2" "$3" "${5:-3}"; box $(( $1 + $4 - ${5:-3} )) "$2" "$3" "${5:-3}"; box "$1" "$2" "${5:-3}" "$4"; box "$1" $(( $2 + $3 - ${5:-3} )) "${5:-3}" "$4"; }
clear_rect() { box "$1" "$2" "$3" "$4" WHITE; }
refresh() { # $1 = 1 nháy đen; $2 = vùng (top=..,left=..,width=..,height=..)
  inv=""; [ "$NIGHT_INVERT" = 1 ] && is_night && inv="-H"
  fl=""; [ "$1" = 1 ] && fl="-f"
  "$FB" -q $fl $inv -s $2 >/dev/null 2>&1
}
image() { eips -g "$1" -x "$2" -y "$3" >/dev/null 2>&1 || log "eips image failed: $1"; }

WD_LONG="Chủ Nhật|Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm|Thứ Sáu|Thứ Bảy"
WD_SHORT="CN|T2|T3|T4|T5|T6|T7"
pick() { echo "$1" | cut -d'|' -f$(( $2 + 1 )); }

epoch_day() { awk -v y="$1" -v m="$2" -v d="$3" 'BEGIN{y-=(m<=2);era=int((y>=0?y:y-399)/400);yoe=y-era*400;doy=int((153*(m+(m>2?-3:9))+2)/5)+d-1;print era*146097+yoe*365+int(yoe/4)-int(yoe/100)+doy-719468}'; }
day_dm() { awk -v z="$1" 'BEGIN{z+=719468;era=int((z>=0?z:z-146096)/146097);doe=z-era*146097;yoe=int((doe-int(doe/1460)+int(doe/36524)-int(doe/146096))/365);doy=doe-(365*yoe+int(yoe/4)-int(yoe/100));mp=int((5*doy+2)/153);d=doy-int((153*mp+2)/5)+1;m=mp+(mp<10?3:-9);printf "%d/%d",d,m}'; }

# ---------- Trạng thái ----------
MOFF=0; EVPAGE=0; PHOFF=0; VIEW=main; LADJ=0; LAST_TOUCH=0; LIGHT_NOW=""; NIGHT_WAS=""; PICKPAGE=0
LAST_KEY=""; NFULL=0

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

photo_list() { ls "$DIR/photos/${1:+$1/}"*.png 2>/dev/null; }
pick_photo() { # $1 = thư mục con -> đường dẫn ảnh hiện tại
  if [ "$PHOTO_MODE" = fixed ] && [ -n "$PHOTO_FIXED" ] && [ -f "$DIR/photos/${1:+$1/}$PHOTO_FIXED" ]; then
    echo "$DIR/photos/${1:+$1/}$PHOTO_FIXED"; return 0
  fi
  pl=$(photo_list "$1"); [ -n "$pl" ] || return 1
  cnt=$(echo "$pl" | wc -l)
  i=$(( ( $(date +%s) / (PHOTO_MIN * 60) + PHOFF ) % cnt )); [ $i -lt 0 ] && i=$(( i + cnt ))
  echo "$pl" | sed -n "$(( i + 1 ))p"
}

# ---------- Bố cục ----------
set_layout() {
  if [ $W -gt $H ]; then          # NGANG 1024x758
    B_LMIN=742; B_LPLUS=806; B_GEAR=878; B_HOME=946
    CLK_X=36; CLK_Y=80; CLK_W=460; CLK_H=200; CLK_PX=170; ANA_X=170; ANA_Y=82
    LUN_Y=280; LUN_X=40
    WXL=land; WX_X=40; WX_Y=316
    DIV="box 460 40 460 2; box 84 512 2 664"
    CX=530; CW=65; CAL_Y=82; CAL_X2=985; RH=50; CAL_PX=38; CAL_LPX=17; HDR_PX=24; HY_OFF=44; GY_OFF=34; LUN_POS=below; CAL_Y2=470
    EV_X=40; EV_Y=472; EV_W=460; EV_N=3; EV_STEP=90; EV_Y2=758
    PH_DIR=land; PH_X=530; PH_Y=480; PH_W=454; PH_H=270
  else                            # DỌC 758x1024
    B_LMIN=470; B_LPLUS=534; B_GEAR=610; B_HOME=678
    CLK_X=30; CLK_Y=82; CLK_W=416; CLK_H=196; CLK_PX=190; ANA_X=128; ANA_Y=82
    LUN_Y=280; LUN_X=40
    WXL=side; WX_X=460; WX_Y=88
    DIV="box 316 40 678 2; box 752 40 678 2"
    CX=40; CW=97; CAL_Y=324; CAL_X2=718; RH=55; CAL_PX=48; CAL_LPX=20; HDR_PX=28; HY_OFF=48; GY_OFF=40; LUN_POS=right; CAL_Y2=750
    EV_X=40; EV_Y=764; EV_W=678; EV_N=3; EV_STEP=82; EV_Y2=1024
    PH_DIR=""; PH_X=420; PH_Y=764; PH_W=298; PH_H=250
  fi
}

date_text() {
  wd=$(pick "$WD_LONG" "$(date +%w)"); ws=$(pick "$WD_SHORT" "$(date +%w)")
  case "$DATE_STYLE" in
    daydu) echo "$wd, ngày $D tháng $M" ;;
    ngan)  echo "$ws · $(date +%d.%m.%Y)" ;;
    iso)   echo "$(date +%Y-%m-%d)" ;;
    *)     echo "$wd, $D/$M/$Y" ;;
  esac
}

lunar_text() {
  set -- $(awk -v MODE=day -v D="$D" -v M="$M" -v Y="$Y" -f "$DIR/lib/lunar.awk" | tr '|' ' ')
  nhuan=""; [ "$4" = 1 ] && nhuan=" nhuận"
  echo "Âm lịch $1/$2$nhuan · năm $5 $6"
}

clock_words() { # giờ phút -> chữ tiếng Việt (2 dòng)
  awk -v h="$1" -v m="$2" 'function so(n,  c,d,s){split("không một hai ba bốn năm sáu bảy tám chín",U," ");
    if(n<10)return U[n+1]; c=int(n/10); d=n%10
    s=(c==1)?"mười":U[c+1]" mươi"
    if(d==0)return s; if(d==1&&c>1)return s" mốt"; if(d==5)return s" lăm"; if(d==4&&c>1)return s" tư"; return s" "U[d+1]}
    BEGIN{ printf "%s giờ\n%s\n", so(h), (m==0?"đúng":so(m)" phút") }'
}

draw_clock() { # vẽ vùng đồng hồ (không refresh)
  hh=$(date +%H); mm=$(date +%M); h=${hh#0}; m=${mm#0}
  case "$CLOCK_STYLE" in
    so12)
      h12=$(( h % 12 )); [ $h12 = 0 ] && h12=12; ap=SA; [ $h -ge 12 ] && ap=CH
      t="$h12:$mm"; txt $CLK_PX $CLK_Y $CLK_X "$t" b
      w=$(( ( (${#t} - 1) * 40 + 18 ) * CLK_PX / 100 )); txt $(( CLK_PX / 4 )) $(( CLK_Y + CLK_PX * 18 / 100 )) $(( CLK_X + w + 14 )) "$ap" b ;;
    kim)
      f="$DIR/clock/$(printf '%02d%02d' $(( h % 12 )) $m).png"
      if [ -f "$f" ]; then image "$f" $ANA_X $ANA_Y; else txt $CLK_PX $CLK_Y $CLK_X "$hh:$mm" b; fi ;;
    chu)
      clock_words "$h" "$m" > /tmp/dash_words
      l1=$(sed -n 1p /tmp/dash_words); l2=$(sed -n 2p /tmp/dash_words)
      txt 60 $(( CLK_Y + 14 )) $(( CLK_X + 10 )) "$l1" b $CLK_W 84
      txt 52 $(( CLK_Y + 96 )) $(( CLK_X + 10 )) "$l2" "" $CLK_W 76 ;;
    *) txt $CLK_PX $CLK_Y $CLK_X "$hh:$mm" b ;;
  esac
}

draw_header() {
  b=$(battery); BATT="$b"
  txt 32 20 40 "$(date_text)" b $(( B_LMIN - 60 ))
  if [ "$ONCE" != 1 ]; then
    l=$(light_level)
    if [ -n "$l" ]; then
      txt 30 20 $B_LMIN "$I_BRIGHT" s; txt 26 22 $(( B_LMIN + 32 )) "–" b
      txt 30 20 $B_LPLUS "$I_BRIGHT" s; txt 26 22 $(( B_LPLUS + 32 )) "+" b
    fi
    txt 34 18 $B_GEAR "$I_GEAR" s
    txt 34 18 $B_HOME "$I_HOME" s
  fi
  box 72 40 $(( W - 80 )) 2
}

draw_weather() {
  pin=""; [ -n "$BATT" ] && pin="Pin $BATT%"
  if ! parse_weather; then
    txt 26 $WX_Y $WX_X "$CITY" "" 260; txt 28 $(( WX_Y + 40 )) $WX_X "Chưa có thời tiết" "" 260
    [ -n "$pin" ] && txt 22 $(( WX_Y + 80 )) $WX_X "$pin"
    return
  fi
  if [ "$WXL" = side ]; then
    ix=$WX_X; tx=$WX_X
    if [ "$WEATHER_ICON" = 1 ]; then txt 92 $WX_Y $WX_X "$WX_ICON" s; tx=$(( WX_X + 104 )); fi
    txt 72 $(( WX_Y + 4 )) $tx "${WX_TEMP}°" b
    txt 24 $(( WX_Y + 90 )) $tx "${WX_MIN}° – ${WX_MAX}°" "" 160
    txt 28 $(( WX_Y + 120 )) $ix "$WX_DESC" "" 258 40
    y2=$(( WX_Y + 158 ))
    txt 22 $y2 $ix "$I_UMBRELLA" s; txt 22 $y2 $(( ix + 28 )) "${WX_RAIN}%"
    txt 22 $y2 $(( ix + 96 )) "$I_HUMID" s; txt 22 $y2 $(( ix + 122 )) "${WX_HUM}%"
    [ -n "$pin" ] && txt 22 $y2 $(( ix + 190 )) "$pin" "" 70
    y3=$(( WX_Y + 190 ))
    [ -n "$WX_RISE" ] && { txt 22 $y3 $ix "$I_SUNRISE" s; txt 22 $y3 $(( ix + 34 )) "$WX_RISE"; }
    [ -n "$WX_SET" ] && { txt 22 $y3 $(( ix + 130 )) "$I_SUNSET" s; txt 22 $y3 $(( ix + 164 )) "$WX_SET"; }
  else
    tx=$WX_X
    if [ "$WEATHER_ICON" = 1 ]; then txt 84 $WX_Y $WX_X "$WX_ICON" s; tx=$(( WX_X + 96 )); fi
    txt 64 $(( WX_Y + 4 )) $tx "${WX_TEMP}°" b
    txt 22 $(( WX_Y + 82 )) $tx "${WX_MIN}° – ${WX_MAX}°"
    rx=300
    txt 26 $WX_Y $rx "$WX_DESC" "" 200
    txt 22 $(( WX_Y + 36 )) $rx "$CITY" "" 200
    txt 22 $(( WX_Y + 68 )) $rx "$I_UMBRELLA" s; txt 22 $(( WX_Y + 68 )) $(( rx + 28 )) "${WX_RAIN}%"
    txt 22 $(( WX_Y + 68 )) $(( rx + 96 )) "$I_HUMID" s; txt 22 $(( WX_Y + 68 )) $(( rx + 122 )) "${WX_HUM}%"
    [ -n "$WX_RISE" ] && { txt 22 $(( WX_Y + 100 )) $rx "$I_SUNRISE" s; txt 22 $(( WX_Y + 100 )) $(( rx + 34 )) "$WX_RISE"; }
    [ -n "$WX_SET" ] && { txt 22 $(( WX_Y + 100 )) $(( rx + 100 )) "$I_SUNSET" s; txt 22 $(( WX_Y + 100 )) $(( rx + 134 )) "$WX_SET"; }
    [ -n "$pin" ] && txt 20 $(( WX_Y + 112 )) $WX_X "$pin"
  fi
}

events() { # KEY|DAY|MIN|ALL|LABEL|SUMMARY từ $1..$2
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
  txt 36 $CAL_Y $CX "Tháng $cm" b
  txt 36 $CAL_Y $(( CX + (${#cm} + 6) * 15 + 14 )) "$cy"
  [ $MOFF != 0 ] && txt 20 $(( CAL_Y + 14 )) $(( CAL_X2 - 200 )) "chạm tiêu đề: về hôm nay" "" 200
  HY=$(( CAL_Y + HY_OFF ))
  if [ "$WEEK_START" = 0 ]; then hdr="CN T2 T3 T4 T5 T6 T7"; else hdr="T2 T3 T4 T5 T6 T7 CN"; fi
  i=0; for hname in $hdr; do ctxt $HDR_PX $HY $(( CX + i * CW + CW / 2 )) "$hname" b; i=$((i + 1)); done
  awk -F'|' '{print $2}' "$EV" | sort -u > /tmp/dash_evdays.txt
  : > /tmp/dash_lunar.txt
  [ "$SHOW_LUNAR" = 1 ] && awk -v MODE=month -v M="$cm" -v Y="$cy" -f "$DIR/lib/lunar.awk" > /tmp/dash_lunar.txt
  GY=$(( HY + GY_OFF ))
  RP=$(( (RH - 4) * 100 / 64 ))
  awk -v Y="$cy" -v M="$cm" -v D="$hl" -v WS="$WEEK_START" -v CX="$CX" -v CW="$CW" -v GY="$GY" -v RH="$RH" \
      -v PX="$CAL_PX" -v LPX="$CAL_LPX" -v LUNPOS="$LUN_POS" -v SHOWLUN="$SHOW_LUNAR" -v TSTYLE="$TODAY_STYLE" \
      -v RP="$RP" -v CFIRST="$CFIRST" -v LUNF=/tmp/dash_lunar.txt -v EVF=/tmp/dash_evdays.txt \
      -f "$DIR/lib/calcells.awk" > /tmp/dash_cells.txt
  while IFS='|' read -r k a1 a2 a3 a4 a5; do
    case "$k" in
      T) case "$a5" in RING) a5="$I_RING" ;; DISC) a5="$I_DISC" ;; esac
         if [ "$a4" = w ]; then TXTOPT="-C WHITE"; txt "$a1" "$a2" "$a3" "$a5" b; TXTOPT=""
         else txt "$a1" "$a2" "$a3" "$a5" "$a4"; fi ;;
      B) box "$a1" "$a2" "$a3" "$a4" ;;
      F) frame "$a1" "$a2" "$a3" "$a4" ;;
    esac
  done < /tmp/dash_cells.txt
  log "calendar drawn ($(wc -l < /tmp/dash_cells.txt) ops)"
}

draw_events() {
  y=$EV_Y; lw=$EV_W; [ -n "$PHOTO" ] && lw=$(( PH_X - EV_X - 20 ))
  if [ -n "$ICS_URL" ]; then
    awk -F'|' -v TD="$TD" '$2 >= TD' "$EV" > /tmp/dash_up.txt
    total=$(wc -l < /tmp/dash_up.txt); pages=$(( (total + EV_N - 1) / EV_N ))
    [ $pages -lt 1 ] && pages=1; [ $EVPAGE -ge $pages ] && EVPAGE=0
    if [ $total = 0 ]; then txt 28 "$y" $EV_X "Không có sự kiện trong $DAYS_AHEAD ngày tới" "" "$lw"; return; fi
    [ $pages -gt 1 ] && txt 20 $(( y + 4 )) $(( EV_X + lw - 44 )) "$((EVPAGE + 1))/$pages" "" 44
    sed -n "$(( EVPAGE * EV_N + 1 )),$(( EVPAGE * EV_N + EV_N ))p" /tmp/dash_up.txt | while IFS='|' read -r key day min all label sum; do
      wd=$(pick "$WD_SHORT" $(( (day + 4) % 7 )))
      if [ "$day" = "$TD" ]; then when="Hôm nay"; elif [ "$day" = $((TD + 1)) ]; then when="Ngày mai"; else when="$wd $(day_dm "$day")"; fi
      if [ "$all" = 1 ]; then when="$when · cả ngày"; else when="$when · $(printf '%02d:%02d' $((min / 60)) $((min % 60)))"; fi
      [ -n "$label" ] && when="[$label] $when"
      txt 24 "$y" $EV_X "$when" b $(( lw - 50 )) 34
      txt 34 $(( y + 30 )) $EV_X "$sum" "" "$lw" 48
      y=$(( y + EV_STEP ))
    done
  else
    txt 28 "$y" $EV_X "Việc cần làm" b; y=$(( y + 44 ))
    grep -v '^#' "$DIR/todo.txt" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -$(( EV_N + 2 )) | while IFS= read -r item; do
      txt 28 "$y" $EV_X "•  $item" "" "$lw" 40; y=$(( y + 44 ))
    done
  fi
}

render_main() { # $1 = 1 nháy đen
  Y=$(date +%Y); M=$(date +%m); D=$(date +%d); M=${M#0}; D=${D#0}
  TD=$(epoch_day "$Y" "$M" "$D")
  set_layout
  PHOTO=$(pick_photo "$PH_DIR")
  cm=$(( M + MOFF )); cy=$Y
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  f=$(epoch_day $cy $cm 1); t=$(( f + 31 )); [ $f -gt $TD ] && f=$TD
  [ $t -lt $(( TD + DAYS_AHEAD )) ] && t=$(( TD + DAYS_AHEAD ))
  EV=/tmp/dash_events.txt; events "$f" "$t" > "$EV"

  log "render main: begin"
  "$FB" -q -b -k >/dev/null 2>&1
  draw_header
  draw_clock
  [ "$SHOW_LUNAR" = 1 ] && txt 24 $LUN_Y $LUN_X "$(lunar_text)" "" $(( CLK_W ))
  draw_weather
  eval "$DIV"
  draw_calendar
  draw_events
  [ -n "$PHOTO" ] && image "$PHOTO" $PH_X $PH_Y
  refresh "$1"
  log "render main: done"
}

update_clock() { # chỉ vẽ lại vùng đồng hồ (nhanh, ít tốn pin)
  set_layout
  clear_rect $CLK_Y $CLK_X $CLK_W $CLK_H
  draw_clock
  refresh 0 "top=$CLK_Y,left=$CLK_X,width=$CLK_W,height=$CLK_H"
}

render_photo() {
  d=full; [ $W -gt $H ] && d=fullland
  p=$(pick_photo "$d")
  "$FB" -q -b -k >/dev/null 2>&1
  if [ -n "$p" ]; then image "$p" 0 0
  else set_layout; p=$(pick_photo "$PH_DIR"); [ -n "$p" ] && image "$p" $(( (W - PH_W) / 2 )) $(( (H - PH_H) / 2 )); fi
  txt 22 $(( H - 34 )) 20 "Chạm trái/phải: ảnh trước/sau · chạm phía trên: quay lại"
  refresh 1
}

# ---------- Trang Cài đặt ----------
# KEY|Nhãn|giá trị1=hiển thị1;giá trị2=hiển thị2;...
SETTINGS_DEF='CLOCK_STYLE|Kiểu giờ|so24=Số 24 giờ;so12=Số 12 giờ (SA/CH);kim=Đồng hồ kim;chu=Bằng chữ
DATE_STYLE|Kiểu ngày|dai=Thứ Hai, 16/11/2026;daydu=Thứ Hai, ngày 16 tháng 11;ngan=T2 · 16.11.2026;iso=2026-11-16
SHOW_LUNAR|Âm lịch|1=Bật;0=Tắt
TODAY_STYLE|Đánh dấu hôm nay|vong=Vòng tròn;khung=Khung vuông;gach=Gạch chân;den=Tròn đen (thử)
WEEK_START|Tuần bắt đầu|1=Thứ Hai;0=Chủ Nhật
WEATHER_ICON|Biểu tượng thời tiết|1=Bật;0=Tắt
ORIENTATION|Hướng màn hình|doc=Dọc;ngang=Ngang (thử)
PHOTO_MODE|Ảnh|auto=Tự đổi;fixed=Cố định
PHOTO_MIN|Đổi ảnh mỗi|1=1 phút;5=5 phút;15=15 phút;30=30 phút;60=1 giờ;180=3 giờ;1440=1 ngày
REFRESH_MIN|Cập nhật giờ mỗi|1=1 phút;2=2 phút;5=5 phút;10=10 phút
LIGHT_DAY|Đèn ban ngày|0=Tắt;2=2;4=4;6=6;8=8;10=10;12=12;16=16;20=20;24=24
LIGHT_NIGHT|Đèn ban đêm|0=Tắt;1=1;2=2;4=4;6=6;8=8
NIGHT_INVERT|Đảo màu ban đêm|0=Tắt;1=Bật (thử)
DAYS_AHEAD|Sự kiện trong|7=7 ngày;14=14 ngày;30=30 ngày
@PICK|Chọn ảnh từ danh sách…|'

save_setting() { # KEY VALUE
  touch "$SETTINGS"
  grep -v "^$1=" "$SETTINGS" > "$SETTINGS.tmp" 2>/dev/null
  echo "$1=\"$2\"" >> "$SETTINGS.tmp"; mv "$SETTINGS.tmp" "$SETTINGS"
  log "setting $1=$2"
}
setting_value() { eval "echo \"\$$1\""; }
setting_display() { # KEY OPTIONS -> hiển thị của giá trị hiện tại
  v=$(setting_value "$1")
  echo "$2" | tr ';' '\n' | while IFS='=' read -r k d; do [ "$k" = "$v" ] && { echo "$d"; break; }; done
}
setting_next() { # KEY OPTIONS -> giá trị kế tiếp
  v=$(setting_value "$1")
  echo "$2" | tr ';' '\n' | awk -F'=' -v v="$v" '{k[NR]=$1} $1==v{p=NR} END{n=(p%NR)+1; print k[n]}'
}
settings_geom() {
  SROW_H=58; SY0=96
  if [ $W -gt $H ]; then SCOLS=2; SCOLW=$(( (W - 80) / 2 )); else SCOLS=1; SCOLW=$(( W - 80 )); fi
  SPER=$(( (H - SY0 - 20) / SROW_H ))
}
render_settings() {
  settings_geom
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_GEAR" s; txt 34 18 92 "Cài đặt" b
  txt 30 22 $(( W - 150 )) "$I_CHECK" s; txt 30 20 $(( W - 112 )) "Xong" b
  box 72 40 $(( W - 80 )) 2
  i=0
  echo "$SETTINGS_DEF" | while IFS='|' read -r key label opts; do
    col=$(( i / SPER )); row=$(( i % SPER ))
    x=$(( 40 + col * SCOLW )); y=$(( SY0 + row * SROW_H ))
    vw=$(( SCOLW * 45 / 100 ))
    txt 26 $(( y + 12 )) $(( x + 4 )) "$label" "" $(( SCOLW - vw - 20 )) 40
    if [ "$key" = "@PICK" ]; then txt 26 $(( y + 12 )) $(( x + SCOLW - 40 )) "$I_RIGHT" s
    else txt 26 $(( y + 12 )) $(( x + SCOLW - vw )) "$(setting_display "$key" "$opts")" b $(( vw - 10 )) 40; fi
    box $(( y + SROW_H - 2 )) $x $(( SCOLW - 16 )) 1
    i=$((i + 1))
  done
  refresh 1
}
settings_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -ge $(( W - 200 )) ] && VIEW=main; return; fi
  settings_geom
  row=$(( ($2 - SY0) / SROW_H )); col=$(( ($1 - 40) / SCOLW )); [ $col -ge $SCOLS ] && return
  [ $row -ge $SPER ] && return
  idx=$(( col * SPER + row + 1 ))
  line=$(echo "$SETTINGS_DEF" | sed -n "${idx}p"); [ -n "$line" ] || return
  key=${line%%|*}; opts=${line##*|}
  if [ "$key" = "@PICK" ]; then VIEW=pick; PICKPAGE=0; return; fi
  nv=$(setting_next "$key" "$opts"); save_setting "$key" "$nv"; eval "$key=\"$nv\""
  if [ "$key" = ORIENTATION ]; then apply_orientation; set_rotation $ROT; fi
  [ "$key" = PHOTO_MODE ] && [ "$nv" = fixed ] && [ -z "$PHOTO_FIXED" ] && { VIEW=pick; PICKPAGE=0; }
}

# ---------- Trang Chọn ảnh ----------
pick_geom() {
  if [ $W -gt $H ]; then PCOLS=6; PROWS=3; PCW=157; PRH=188; PY0=92; else PCOLS=4; PROWS=5; PCW=170; PRH=172; PY0=92; fi
  PPER=$(( PCOLS * PROWS )); PX0=$(( (W - PCOLS * PCW) / 2 ))
}
render_pick() {
  pick_geom
  thumbs=$(photo_list thumb); n=$(echo "$thumbs" | grep -c .)
  pages=$(( (n + PPER - 1) / PPER )); [ $pages -lt 1 ] && pages=1; [ $PICKPAGE -ge $pages ] && PICKPAGE=0
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_IMAGE" s; txt 34 18 92 "Chọn ảnh" b; txt 22 30 270 "trang $((PICKPAGE + 1))/$pages"
  txt 26 22 $(( W - 330 )) "$I_REFRESH" s; txt 26 20 $(( W - 298 )) "Tự đổi" b
  txt 30 22 $(( W - 150 )) "$I_CHECK" s; txt 30 20 $(( W - 112 )) "Xong" b
  box 72 40 $(( W - 80 )) 2
  if [ "$n" = 0 ]; then txt 28 200 40 "Chưa có ảnh. Chạy tools/prepare_photos.py trên máy tính." "" $(( W - 80 )); refresh 1; return; fi
  i=0
  echo "$thumbs" | sed -n "$(( PICKPAGE * PPER + 1 )),$(( PICKPAGE * PPER + PPER ))p" | while read -r p; do
    x=$(( PX0 + (i % PCOLS) * PCW + (PCW - 150) / 2 )); y=$(( PY0 + (i / PCOLS) * PRH + 8 ))
    image "$p" $x $y
    [ "$PHOTO_MODE" = fixed ] && [ "$(basename "$p")" = "$PHOTO_FIXED" ] && frame $(( y - 6 )) $(( x - 6 )) 162 162 5
    i=$((i + 1))
  done
  if [ $pages -gt 1 ]; then
    by=$(( H - 60 ))
    txt 30 $by 40 "$I_LEFT" s; txt 28 $(( by - 2 )) 76 "Trước" b
    txt 28 $(( by - 2 )) $(( W - 160 )) "Sau" b; txt 30 $by $(( W - 90 )) "$I_RIGHT" s
  fi
  refresh 1
}
pick_tap() { # x y
  x=$1; y=$2; pick_geom
  if [ $y -le 80 ]; then
    if [ $x -ge $(( W - 200 )) ]; then VIEW=main
    elif [ $x -ge $(( W - 340 )) ]; then PHOTO_MODE=auto; save_setting PHOTO_MODE auto; VIEW=main; fi
    return
  fi
  if [ $y -ge $(( H - 80 )) ]; then
    if [ $x -lt $(( W / 2 )) ]; then PICKPAGE=$((PICKPAGE - 1)); else PICKPAGE=$((PICKPAGE + 1)); fi
    [ $PICKPAGE -lt 0 ] && PICKPAGE=0
    return
  fi
  col=$(( (x - PX0) / PCW )); row=$(( (y - PY0) / PRH ))
  [ $col -ge 0 ] && [ $col -lt $PCOLS ] && [ $row -ge 0 ] && [ $row -lt $PROWS ] || return
  idx=$(( PICKPAGE * PPER + row * PCOLS + col + 1 ))
  p=$(photo_list thumb | sed -n "${idx}p"); [ -n "$p" ] || return
  PHOTO_FIXED=$(basename "$p"); PHOTO_MODE=fixed
  save_setting PHOTO_FIXED "$PHOTO_FIXED"; save_setting PHOTO_MODE fixed
  VIEW=main
}

# ---------- Chế độ server (tuỳ chọn) ----------
render_server() {
  b=$(battery)
  if wifi_on && wget -q -T 20 -O /tmp/dashboard.png "$SERVER_URL?battery=$b"; then
    [ "$1" = 1 ] && eips -c
    if [ "$1" = 1 ]; then eips -f -g /tmp/dashboard.png; else eips -g /tmp/dashboard.png; fi
  else eips 1 1 "Mat ket noi server $(date +%H:%M)  "; log "server fetch failed: $SERVER_URL"; fi
}
draw() {
  if [ -n "$SERVER_URL" ]; then render_server "$1"; return; fi
  case "$VIEW" in
    photo) render_photo ;; settings) render_settings ;; pick) render_pick ;;
    *) render_main "$1" ;;
  esac
}

# ---------- Chạm ----------
go_home() {
  log "go home ($1)"
  "$FB" -q -c -m -M -t "regular=$BOLD,px=44" "Đang về Home…" >/dev/null 2>&1
  pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  [ "$(cat "$ROTF" 2>/dev/null)" != 0 ] && set_rotation 0
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
  start framework 2>/dev/null || start lab126_gui 2>/dev/null
  rm -f /tmp/dash.pid
  exit 0
}

to_view() { # toạ độ màn hình dọc (touch.sh) -> toạ độ theo hướng hiện tại
  px=$1; py=$2; VX=$px; VY=$py
  [ $((ROT % 2)) = 1 ] || return 0
  a=$ROT; [ "$LAND_TOUCH_INVERT" = 1 ] && a=$(( 4 - ROT ))
  if [ $a = 1 ]; then VX=$py; VY=$(( 757 - px )); else VX=$(( 1023 - py )); VY=$px; fi
}

handle_tap() {
  to_view "$1" "$2"; x=$VX; y=$VY
  LAST_TOUCH=$(date +%s)
  log "tap ($x,$y) view=$VIEW"
  case "$VIEW" in
    settings) settings_tap $x $y; return ;;
    pick) pick_tap $x $y; return ;;
    photo)
      if [ $y -lt 150 ]; then VIEW=main
      elif [ $x -lt $(( W / 2 )) ]; then PHOFF=$((PHOFF - 1)); else PHOFF=$((PHOFF + 1)); fi
      return ;;
  esac
  set_layout
  if [ $y -le 80 ]; then
    if [ $x -ge $(( B_HOME - 10 )) ]; then go_home "tap Home"
    elif [ $x -ge $(( B_GEAR - 10 )) ]; then VIEW=settings
    elif [ $x -ge $(( B_LPLUS - 8 )) ] && [ $x -lt $(( B_LPLUS + 60 )) ]; then LADJ=$((LADJ + 2)); set_light
    elif [ $x -ge $(( B_LMIN - 8 )) ] && [ $x -lt $(( B_LMIN + 60 )) ]; then LADJ=$((LADJ - 2)); set_light
    fi
    return
  fi
  if [ $x -ge $CX ] && [ $x -le $CAL_X2 ] && [ $y -ge $CAL_Y ] && [ $y -le $CAL_Y2 ]; then
    if [ $y -lt $(( CAL_Y + 46 )) ]; then MOFF=0
    elif [ $x -lt $(( (CX + CAL_X2) / 2 )) ]; then MOFF=$((MOFF - 1)); else MOFF=$((MOFF + 1)); fi
    return
  fi
  PHOTO=$(pick_photo "$PH_DIR")
  if [ -n "$PHOTO" ] && [ $x -ge $PH_X ] && [ $y -ge $PH_Y ] && [ $x -le $(( PH_X + PH_W )) ] && [ $y -le $(( PH_Y + PH_H )) ]; then
    VIEW=photo; return
  fi
  if [ $x -ge $EV_X ] && [ $y -ge $EV_Y ] && [ $y -le $EV_Y2 ]; then EVPAGE=$((EVPAGE + 1)); return; fi
  if [ $y -ge $CLK_Y ] && [ $y -le $(( CLK_Y + CLK_H )) ] && [ $x -le $(( CLK_X + CLK_W )) ]; then
    nv=$(setting_next CLOCK_STYLE "so24=;so12=;kim=;chu="); CLOCK_STYLE=$nv; save_setting CLOCK_STYLE "$nv"
  fi
}

idle_reset() {
  [ $LAST_TOUCH = 0 ] && return
  [ $(( $(date +%s) - LAST_TOUCH )) -ge $(( IDLE_RESET_MIN * 60 )) ] || return
  MOFF=0; EVPAGE=0; LAST_TOUCH=0; [ "$VIEW" != main ] && VIEW=main; LAST_KEY=""
}

process_taps() {
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
  log "test: start"
  [ -n "$SERVER_URL" ] || { update_data; log "test: data done"; }
  draw 1; log "drawn once"; exit 0
fi

log "start (pid $$, $(uname -r 2>/dev/null))"
echo $$ > /tmp/dash.pid
rm -f "$TAPQ"
if is_night; then NIGHT_WAS=1; else NIGHT_WAS=0; fi
trap 'WOKE=1' USR1
stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
log "framework stopped"
sleep 2
"$FB" -q -c -m -M -t "regular=$BOLD,px=40" "Đang tải dashboard…" >/dev/null 2>&1
lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
[ "$ROT" != 0 ] && set_rotation "$ROT"
pkill -f "$DIR/touch.sh" 2>/dev/null
sh "$DIR/touch.sh" >> "$DIR/dash.log" 2>&1 &

TAPPED=1
while true; do
  b=$(battery)
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    "$FB" -q -c -m -M -t "regular=$BOLD,px=40" "PIN YẾU – HÃY SẠC KINDLE ($b%)" >/dev/null 2>&1 \
      || { eips -c; eips 10 20 "PIN YEU - HAY SAC KINDLE ($b%)"; }
    log "low battery, stopping"; set_rotation 0; exit 0
  fi
  [ -n "$SERVER_URL" ] || { log "data: update"; update_data; log "data: done"; }
  idle_reset
  set_light
  # vẽ toàn màn hình khi: có chạm, dữ liệu mới, đổi ngày/giờ, mỗi 15 phút; còn lại chỉ vẽ đồng hồ
  key="$(date +%Y%m%d%H)$(( $(date +%M | sed 's/^0//') / 15 ))"
  if [ "$VIEW" != main ] || [ $TAPPED = 1 ] || [ $DATA_CHANGED = 1 ] || [ "$key" != "$LAST_KEY" ] || [ -n "$SERVER_URL" ]; then
    NFULL=$((NFULL + 1)); full=0; [ $((NFULL % FULL_REFRESH_EVERY)) -eq 1 ] && full=1
    [ $TAPPED = 1 ] && [ "$key" = "$LAST_KEY" ] && full=0
    draw $full; LAST_KEY="$key"
  else
    update_clock
  fi
  TAPPED=0; DATA_CHANGED=0
  every=$REFRESH_MIN; is_night && every=$REFRESH_NIGHT_MIN
  s=$(date +%S); s=${s#0}
  sleep $(( every * 60 - s )) & SP=$!
  while :; do
    process_taps && { TAPPED=1; kill $SP 2>/dev/null; break; }
    wait $SP 2>/dev/null && break
    kill -0 $SP 2>/dev/null || { process_taps && TAPPED=1; break; }
  done
  wait $SP 2>/dev/null
done
