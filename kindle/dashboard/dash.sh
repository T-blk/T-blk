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
  case "$ORIENTATION" in doc|nguoc|ngangtrai|ngangphai) ;; *) ORIENTATION=doc ;; esac
  : "${NIGHT_START:=22}" "${NIGHT_END:=6}" "${REFRESH_MIN:=1}" "${REFRESH_NIGHT_MIN:=$REFRESH_MIN}" "${NIGHT_INVERT:=0}"
  : "${ORIENTATION:=doc}" "${ROTATE_LAND:=1}" "${LAND_TOUCH_INVERT:=0}" "${IDLE_RESET_MIN:=5}"
  : "${PHOTO_MIN:=60}" "${PHOTO_MODE:=auto}" "${PHOTO_FIXED:=}" "${DAYS_AHEAD:=14}" "${TZ_OFFSET_MIN:=420}"
  : "${CLOCK_STYLE:=auto}" "${DATE_STYLE:=dai}" "${SHOW_LUNAR:=1}" "${TODAY_STYLE:=vong}" "${WEEK_START:=1}"
  : "${ORNAMENT:=0}" "${DEFAULT_PAGE:=main}" "${NIGHT_PAGE:=dem}" "${POMO_FOCUS:=25}" "${POMO_BREAK:=5}"
  : "${SCHEDULE:=0}" "${AUTO_MEET:=0}" "${REMOTE:=0}" "${DEEP_SLEEP:=0}" "${DEEP_SLEEP_MIN:=30}"
  : "${CLOCK_CLEAN_MIN:=10}" "${HOME_REPAINT:=chuyen}" "${CONTRAST:=cao}" "${HOME_MODE:=nhanh}" "${WIFI_SAVE:=1}" "${STATUS_DIM:=1}" "${LIGHT_IDLE_MIN:=30}"
  : "${LAYOUT:=codien}" "${EVENT_STYLE:=auto}" "${PHOTO_STYLE:=auto}"
  : "${WEATHER_ICON:=1}" "${WEATHER_MIN:=30}" "${CALENDAR_MIN:=30}" "${FULL_CLEAN:=dem}" "${DIFF_REFRESH:=1}" "${LOW_BATTERY:=5}"
}
load_conf

# ---- Khởi động nhanh: đóng băng giao diện Kindle + hiện "Đang tải" NGAY, trước khi nạp phần còn lại ----
FB=/tmp/dash_fbink
[ -x "$FB" ] && [ ! "$DIR/bin/fbink" -nt "$FB" ] || { cp "$DIR/bin/fbink" "$FB" 2>/dev/null && chmod +x "$FB"; }
# ---- Chỉ cho chạy MỘT dashboard ----
# Trước đây chạm "Dashboard - Bat" 2 lần (Kindle chạy chậm, không báo gì) làm 2 bản chạy cùng lúc, tranh nhau
# màn hình và giao diện Kindle -> đơ. Khoá bằng thư mục (mkdir là thao tác nguyên tử); bản đến sau tự thoát
# NGAY, trước khi đụng tới giao diện Kindle.
LOCKD=/tmp/dash.lock
dash_alive_pid() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null && grep -q "dash.sh" "/proc/$1/cmdline" 2>/dev/null; }
dash_unlock() { [ "$(cat "$LOCKD/pid" 2>/dev/null)" = "$$" ] && rm -rf "$LOCKD"; }
if [ "$1" != "--once" ]; then
  if ! mkdir "$LOCKD" 2>/dev/null; then
    _op=$(cat "$LOCKD/pid" 2>/dev/null)
    if [ "$_op" != "$$" ] && dash_alive_pid "$_op"; then
      echo "$(date '+%F %T') đã có dashboard đang chạy (pid $_op) -> bản này thoát, không làm gì"; exit 0
    fi
    rm -rf "$LOCKD"; mkdir "$LOCKD" 2>/dev/null || { echo "$(date '+%F %T') không lấy được khoá -> thoát"; exit 0; }
  fi
  echo $$ > "$LOCKD/pid"
  echo $(( $(date +%s) + 600 )) > /tmp/dash_alive        # bộ canh gác: hạn báo "còn sống" lần tới
fi
# Thoát vì bất kỳ lý do gì -> trả lại giao diện Kindle (kể cả khi cờ "đóng băng" đã mất), nhả khoá
dash_exit() {
  if [ "$HANDOVER" != 1 ]; then fw_resume; rm -f /tmp/dash_alive; fi
  dash_unlock
}
EARLY=0
if [ "$1" != "--once" ]; then
  . "$DIR/lib/fw.sh"
  case "$ORIENTATION" in nguoc) _w=D ;; ngangtrai) _w=L ;; ngangphai) _w=R ;; *) _w=U ;; esac
  # Giao diện Kindle đang bị đóng băng (T) mà mất cờ -> vẫn là lần chạy trước của dashboard: tiếp quản,
  # KHÔNG học lại góc "đứng thẳng" (màn hình lúc này là dashboard, có thể đang lộn ngược/ngang).
  if ! fw_paused && _cp=$(cvm_pid) && [ "$(proc_state "$_cp")" = T ]; then echo "$_cp" > "$FW_FLAG"; fi
  if fw_paused && [ -n "$(proc_state "$(cat "$FW_FLAG")")" ]; then
    # tiếp quản lần chạy trước (vừa cập nhật / mở lại): giữ nguyên đóng băng, không lộ giao diện Kindle
    [ -s /tmp/dash_lock_orig ] || echo U > /tmp/dash_lock_orig
    _ln=$(cat /tmp/dash_lock_now 2>/dev/null); [ -n "$_ln" ] || _ln=$(cat /tmp/dash_lock_orig)
    [ "$_w" != "$_ln" ] && fw_thaw_do lipc-set-prop com.lab126.winmgr orientationLock "$_w" && _ln=$_w
    EARLY=takeover
  else
    rm -f "$FW_FLAG"
    _lo=$(lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null); [ -n "$_lo" ] || _lo=U
    echo "$_lo" > /tmp/dash_lock_orig; _ln=$_lo
    # Học góc xoay "đứng thẳng" từ màn hình THẬT: lúc mở dashboard, màn hình chính Kindle luôn dọc & đứng thẳng.
    # (Không tin orientationLock: Kindle có thể báo "ngang" trong khi màn hình vẫn dọc.)
    _geo() { "$FB" -e 2>/dev/null | tr ';' '\n' | sed -n "s/^$1=//p" | head -1; }
    _r0=$(_geo currentRota); _vw=$(_geo viewWidth); _vh=$(_geo viewHeight)
    rm -f "$DIR/.rota_up"
    # Chỉ học khi chắc màn hình chính Kindle đứng thẳng: không học nếu Kindle báo đang khoá lộn ngược (D)
    # hoặc dashboard vừa được bản cập nhật khởi động lại (DASH_NOLEARN) mà đã có giá trị cũ.
    if [ ! -s "$DIR/.rota_up2" ] || { [ "$_lo" != D ] && [ -z "$DASH_NOLEARN" ]; }; then
      case "$_r0" in [0-3]) [ -n "$_vw" ] && [ -n "$_vh" ] && [ "$_vw" -lt "$_vh" ] && echo "$_r0" > "$DIR/.rota_up2" ;; esac
    fi
    _ln=U
    if [ "$_w" != U ] || [ "$_lo" != U ]; then
      [ "$_lo" = "$_w" ] && { lipc-set-prop com.lab126.winmgr orientationLock U 2>/dev/null; sleep 1; }   # "đá" để Kindle xoay thật
      lipc-set-prop com.lab126.winmgr orientationLock "$_w" 2>/dev/null
      _k=0; while [ $_k -lt 12 ] && [ "$(_geo currentRota)" = "$_r0" ]; do usleep 500000 2>/dev/null || sleep 1; _k=$((_k + 1)); done
      if [ "$_w" != U ] && [ -n "$_r0" ] && [ "$(_geo currentRota)" = "$_r0" ]; then
        lipc-set-prop com.lab126.winmgr orientationLock U 2>/dev/null
        PENDING_ORIENT=1                    # thử các cách xoay khác sau khi đã vẽ xong màn hình
      elif [ "$_w" != U ]; then _ln=$_w; fi
    fi
    fw_pause
    EARLY=fresh
  fi
  trap 'dash_exit' EXIT    # lỗi khi nạp phần sau -> vẫn trả giao diện Kindle
  if false; then :
  fi
  echo "$_ln" > /tmp/dash_lock_now
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  "$FB" -q -c -m -M -t "regular=$DIR/fonts/NotoSans-Bold.ttf,px=40" "Đang tải dashboard…" >/dev/null 2>&1
fi
. "$DIR/lib/icons.sh"
DASH_VER=$(cat "$DIR/VERSION" 2>/dev/null || echo "?")
. "$DIR/lib/pages.sh"
. "$DIR/lib/news.sh"
. "$DIR/lib/pomo.sh"
. "$DIR/lib/ui.sh"
. "$DIR/lib/widgets.sh"
. "$DIR/lib/layouts.sh"
. "$DIR/lib/status.sh"
. "$DIR/lib/fw.sh"
. "$DIR/lib/diag.sh"
. "$DIR/lib/schedule.sh"
. "$DIR/lib/remote.sh"
. "$DIR/lib/sleep.sh"
modern_ok && mw_load
UPD_AVAIL=""; UPD_NOTES=""; UPD_MSG=""

WX=/tmp/dash_weather.json
CALDIR=/tmp/dash_cal
FB=/tmp/dash_fbink
TAPQ=/tmp/dash_taps
REG="$DIR/fonts/NotoSans-Regular.ttf"
BOLD="$DIR/fonts/NotoSans-Bold.ttf"
SYM="$DIR/fonts/symbols.ttf"
ROTF=/sys/class/graphics/fb0/rotate

# Ghi log không "sync" mỗi dòng (đỡ ghi bộ nhớ flash -> nhẹ máy, đỡ pin). Log quá 300 KB thì cắt bớt.
log() { echo "$(date '+%F %T') $*"; }
log_trim() {
  f="$DIR/dash.log"; [ -f "$f" ] || return 0
  [ $(wc -c < "$f") -gt 307200 ] && { tail -c 102400 "$f" > "$f.tmp" && cat "$f.tmp" > "$f"; rm -f "$f.tmp"; }
  sync 2>/dev/null
}

battery() { lipc-get-prop com.lab126.powerd battLevel 2>/dev/null || gasgauge-info -c 2>/dev/null | tr -d '%'; }

wifi_on() {
  WIFI_USED=1
  [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && return 0
  lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
  lipc-set-prop com.lab126.wifid enable 1 2>/dev/null
  # chờ sự kiện "đã kết nối" thay vì hỏi từng giây (nếu máy có lipc-wait-event)
  if command -v lipc-wait-event >/dev/null 2>&1; then
    lipc-wait-event -s 30 com.lab126.wifid cmConnected >/dev/null 2>&1
    [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && { wifi_ready; return 0; }
  fi
  i=0
  while [ $i -lt 60 ]; do
    [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && { wifi_ready; return 0; }
    usleep 500000 2>/dev/null || sleep 1
    i=$((i + 1))
  done
  return 1
}
wifi_ready() { # vừa kết nối: đợi có địa chỉ mạng/DNS (tối đa 5 giây) để lần tải đầu không hỏng
  command -v nslookup >/dev/null 2>&1 || return 0
  _i=0; while [ $_i -lt 10 ]; do nslookup api.open-meteo.com >/dev/null 2>&1 && return 0; usleep 500000 2>/dev/null || sleep 1; _i=$((_i + 1)); done
}

# Tiết kiệm pin: tắt Wi-Fi khi không cần (bật lại tự động lúc tải thời tiết/lịch/tin, đọc báo, cập nhật)
wifi_save() {
  [ "${WIFI_SAVE:-1}" = 1 ] || return 0
  [ "$REMOTE" = 1 ] && return 0                 # đang nghe lệnh từ điện thoại: giữ Wi-Fi
  lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null && log "wifi off (tiết kiệm pin)"
}

fetch() { # $1=url $2=file $3=chuỗi bắt buộc có
  if curl -s -k -L -m 30 -o "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (curl): ${1%%\?*}"
  elif wget -q -T 30 -O "$2.tmp" "$1" && grep -q "$3" "$2.tmp"; then log "fetch ok (wget): ${1%%\?*}"
  else log "fetch FAILED: ${1%%\?*}"; rm -f "$2.tmp"; return 1
  fi
  mv "$2.tmp" "$2"
}

due() { [ -s "$1" ] || return 0; [ $(( $(date +%s) - $(date -r "$1" +%s 2>/dev/null || echo 0) )) -ge $(( $2 * 60 * ${DUE_PCT:-100} / 100 )) ]; }

# Đồng bộ giờ: đọc header "Date:" (giờ UTC chuẩn) từ máy chủ web, chỉnh đồng hồ Kindle nếu lệch >= 15 giây.
TS_STAMP=/tmp/dash_timesync
time_sync() {
  [ "${TIME_SYNC:-1}" = 1 ] || return 0
  due "$TS_STAMP" "${TIME_SYNC_MIN:-360}" || return 0
  hdr=$(curl -s -k -I -m 15 https://www.google.com 2>/dev/null | grep -i '^date:' | head -1)
  [ -n "$hdr" ] || hdr=$(curl -s -k -I -m 15 https://api.open-meteo.com 2>/dev/null | grep -i '^date:' | head -1)
  [ -n "$hdr" ] || { log "time sync: no Date header"; return 1; }
  # "Date: Mon, 16 Nov 2026 10:09:12 GMT" -> "2026-11-16 10:09:12 <epoch>"
  set -- $(echo "$hdr" | tr -d '\r' | awk '{
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", MN, " "); for (i = 1; i <= 12; i++) if (MN[i] == $4) m = i
    d = $3 + 0; y = $5 + 0; split($6, t, ":")
    yy = y - (m <= 2); era = int(yy / 400); yoe = yy - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
    days = era * 146097 + yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy - 719468
    printf "%04d-%02d-%02d %s %d\n", y, m, d, $6, days * 86400 + t[1] * 3600 + t[2] * 60 + t[3] }')
  [ $# = 3 ] || { log "time sync: cannot parse '$hdr'"; return 1; }
  now=$(date +%s); diff=$(( now - $3 )); ad=${diff#-}
  if [ "$ad" -ge 15 ]; then
    if date -u -s "$1 $2" >/dev/null 2>&1; then
      hwclock -u -w 2>/dev/null
      log "time sync: clock was off by ${diff}s -> set to $1 $2 UTC"; DATA_CHANGED=1
    else log "time sync: date -s failed (off by ${diff}s)"; fi
  else log "time sync: ok (off by ${diff}s)"; fi
  date +%s > "$TS_STAMP"
}

DATA_CHANGED=0
update_data() {
  [ "$NOWE" -lt "${NEXT_DATA:-0}" ] 2>/dev/null && return 0
  NEXT_DATA=$(( ${NOWE:-0} + 120 ))
  DUE_PCT=100
  need=0
  due "$WX" "$WEATHER_MIN" && need=1
  [ "${AUTO_UPDATE_CHECK:-1}" = 1 ] && due /tmp/dash_otacheck 1440 && need=1
  [ -n "$NEWS_FEEDS" ] && due "$NEWS_STAMP" "$NEWS_MIN" && need=1
  [ "${TIME_SYNC:-1}" = 1 ] && due "$TS_STAMP" "${TIME_SYNC_MIN:-360}" && need=1
  [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN" && need=1
  [ $need = 1 ] || return 0
  t0=$(date +%s)
  if ! wifi_on; then
    # không có mạng (đi xa, router tắt...): thử thưa dần 2-4-8-16-32-60 phút, đỡ bật sóng vô ích
    WIFI_FAILS=$(( ${WIFI_FAILS:-0} + 1 )); bk=$(( 2 << (WIFI_FAILS - 1) )); [ $bk -gt 60 ] && bk=60
    NEXT_DATA=$(( t0 + bk * 60 )); log "no wifi (lần $WIFI_FAILS) -> thử lại sau $bk phút"; WIFI_USED=0; wifi_save; return 1
  fi
  WIFI_FAILS=0
  # Đã bật sóng thì tải luôn những thứ sắp đến hạn (>= 70% chu kỳ) -> ít lần bật Wi-Fi hơn
  DUE_PCT=70
  # Tải song song: thời gian bật sóng ngắn lại
  JOBS=""
  time_sync & JOBS="$JOBS $!"
  if [ "${AUTO_UPDATE_CHECK:-1}" = 1 ] && due /tmp/dash_otacheck 1440; then
    ( sh "$DIR/update.sh" --check > /tmp/dash_otaresult 2>/dev/null; date +%s > /tmp/dash_otacheck ) & JOBS="$JOBS $!"
  fi
  if due "$WX" "$WEATHER_MIN"; then
    q="latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=6"
    ( fetch "https://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"' || fetch "http://api.open-meteo.com/v1/forecast?$q" "$WX" '"current"' ) & JOBS="$JOBS $!"
  fi
  fetch_aqi & JOBS="$JOBS $!"
  fetch_news & JOBS="$JOBS $!"
  if [ -n "$ICS_URL" ] && due "$CALDIR/stamp" "$CALENDAR_MIN"; then
    mkdir -p "$CALDIR"; k=0
    for u in $ICS_URL; do
      k=$((k + 1)); label=""
      case "$u" in *=webcal://*|*=http://*|*=https://*) label="${u%%=*}"; u="${u#*=}" ;; esac
      u=$(echo "$u" | sed 's#^webcal://#https://#')
      ( fetch "$u" "$CALDIR/$k.ics" "BEGIN:VCALENDAR" && echo "$label" > "$CALDIR/$k.label" ) & JOBS="$JOBS $!"
    done
    date +%s > "$CALDIR/stamp"
  fi
  # chỉ chờ đúng các lần tải vừa chạy (KHÔNG "wait" trống: sẽ chờ cả bộ đọc cảm ứng chạy mãi -> treo)
  for jp in $JOBS; do wait "$jp" 2>/dev/null; done
  DUE_PCT=100
  if [ -s /tmp/dash_otaresult ]; then
    r=$(cat /tmp/dash_otaresult); rm -f /tmp/dash_otaresult; log "update check: $r"
    case "$r" in available*) r=${r#available }; UPD_AVAIL=${r%%|*}; UPD_NOTES=${r#*|} ;; esac
  fi
  log "data: xong trong $(( $(date +%s) - t0 )) giây"; stat_wifi $(( $(date +%s) - t0 ))
  WIFI_USED=0; wifi_save
  data_sig
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
# Xoay bằng trình quản lý cửa sổ của Kindle (com.lab126.winmgr orientationLock: U/D/L/R),
# đặt TRƯỚC khi tắt giao diện Kindle; KHÔNG ghi thẳng vào /sys (làm rối giao diện khi thoát).
lock_for() { case "$1" in nguoc) echo D ;; ngangtrai) echo L ;; ngangphai) echo R ;; *) echo U ;; esac; }
get_lock() { lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null; }
set_lock() { lipc-set-prop com.lab126.winmgr orientationLock "$1" 2>/dev/null; }
LOCK_NOW=U
fb_geom() { # đọc kích thước + góc xoay THẬT từ FBInk
  viewWidth=""; viewHeight=""; currentRota=""
  eval "$("$FB" -e 2>/dev/null | tr -d '\n')" 2>/dev/null
  if [ -n "$viewWidth" ] && [ -n "$viewHeight" ]; then W=$viewWidth; H=$viewHeight
  elif [ "$LOCK_NOW" = L ] || [ "$LOCK_NOW" = R ]; then W=1024; H=758; else W=758; H=1024; fi
  CUR_ROTA=$currentRota; fb_stride
  rota_sync
  log "geometry ${W}x${H} rota=${currentRota:-?} lock=$LOCK_NOW (chạm theo ${TOUCH_LOCK:-$LOCK_NOW})"
}
# Toạ độ chạm luôn tính theo chiều THẬT của màn hình (góc xoay framebuffer), không theo việc ta "nghĩ" đã xoay:
# ROTA_UP = góc xoay khi màn hình đứng thẳng (lưu trong .rota_up). Lệch 0/2 = dọc/lộn ngược, 1/3 = ngang.
rota_sync() {
  case "$CUR_ROTA" in [0-3]) ;; *) TOUCH_LOCK=""; return ;; esac
  ROTA_UP=$(cat "$DIR/.rota_up2" 2>/dev/null)                # học ở phần khởi động (trước khi xoay)
  case "$ROTA_UP" in [0-3]) ;; *) TOUCH_LOCK=""; return ;; esac
  case $(( (CUR_ROTA - ROTA_UP + 4) % 4 )) in 0) TOUCH_LOCK=U ;; 2) TOUCH_LOCK=D ;; 1) TOUCH_LOCK=R ;; 3) TOUCH_LOCK=L ;; esac
  LOCK_NOW=$TOUCH_LOCK                      # chiều đang dùng = chiều thật của màn hình
}
W=758; H=1024
wait_winmgr() { i=0; while [ $i -lt 90 ]; do [ -n "$(get_lock)" ] && return 0; sleep 1; i=$((i + 1)); done; return 1; }
# Đổi hướng khi giao diện Kindle đang tắt: bật lại, đặt khoá xoay, tắt lại (~30-60 giây)
# ---------- Xoay màn hình ----------
rota_now() { "$FB" -e 2>/dev/null | tr ';' '\n' | sed -n 's/^currentRota=//p' | head -1; }
rota_wait() { # r0 giây -> 0 nếu góc xoay đã khác r0
  _i=0; while [ $_i -lt $(( $2 * 2 )) ]; do [ "$(rota_now)" != "$1" ] && return 0; usleep 500000 2>/dev/null || sleep 1; _i=$((_i + 1)); done; return 1
}
lock_kick() { # đặt khoá xoay; nếu Kindle đang "ghi" sẵn giá trị đó (mà màn hình chưa xoay) thì đặt giá trị khác trước để nó thật sự xoay
  _c=$(get_lock)
  if [ "$_c" = "$1" ]; then [ "$1" = U ] && set_lock D || set_lock U; sleep 1; fi
  set_lock "$1"
}
rot_ok() { # màn hình đã ở đúng kiểu chiều mong muốn chưa (dọc/lộn ngược/ngang)
  fb_geom
  case "$want" in
    U) [ "$TOUCH_LOCK" = U ] ;; D) [ "$TOUCH_LOCK" = D ] ;;
    *) [ "$TOUCH_LOCK" = L ] || [ "$TOUCH_LOCK" = R ] || { [ -z "$TOUCH_LOCK" ] && [ "$W" -gt "$H" ]; } ;;
  esac
}
reorient() { # $1 = doc|nguoc|ngangtrai|ngangphai
  want=$(lock_for "$1"); REORIENT_FAIL=0
  "$FB" -q -c -m -M -t "regular=$BOLD,px=36" "Đang xoay màn hình…" >/dev/null 2>&1
  r0=$(rota_now)
  if fw_paused && [ -w "$ROTF" ] && [ -n "$ROTA_UP" ]; then
    # 0) Dashboard TỰ xoay: đặt góc xoay framebuffer trực tiếp (giao diện Kindle đang đóng băng, không vẽ gì).
    #    Trả lại góc cũ trước khi đánh thức giao diện Kindle (xem fw_resume) -> Kindle không bị ảnh hưởng.
    [ -s /tmp/dash_rota_orig ] || echo "$r0" > /tmp/dash_rota_orig
    case "$want" in U) dl="0" ;; D) dl="2" ;; L) dl="3 1" ;; *) dl="1 3" ;; esac
    for d in $dl; do
      echo $(( (ROTA_UP + d) % 4 )) > "$ROTF" 2>/dev/null; usleep 300000 2>/dev/null || sleep 1
      if rot_ok; then log "xoay -> $want: dashboard tự xoay (rotate=$CUR_ROTA)"; echo "$LOCK_NOW" > /tmp/dash_lock_now; return; fi
    done
    echo "$r0" > "$ROTF" 2>/dev/null; usleep 300000 2>/dev/null || sleep 1; fb_geom
    log "tự xoay không được (rotate $r0) -> nhờ Kindle"
  fi
  if fw_paused; then
    # A) khi giao diện Kindle còn đóng băng (nhanh, không lộ màn hình Kindle)
    ( lock_kick "$want" ) >/dev/null 2>&1 & lp=$!
    rota_wait "$r0" 3; kill $lp 2>/dev/null
    if rot_ok; then log "xoay -> $want: cách A (đóng băng)"; echo "$LOCK_NOW" > /tmp/dash_lock_now; return; fi
    # B) cho giao diện Kindle chạy tạm để nó xoay
    p=$(cat "$FW_FLAG"); kill -CONT "$p" 2>/dev/null; sleep 2
    lock_kick "$want"; rota_wait "$r0" 10
    kill -STOP "$p" 2>/dev/null; sleep 1
    if rot_ok; then log "xoay -> $want: cách B (chạy tạm)"; echo "$LOCK_NOW" > /tmp/dash_lock_now; return; fi
    # C) khởi động lại giao diện Kindle như các bản đầu (~1 phút)
    "$FB" -q -c -m -M -t "regular=$BOLD,px=34" "Đang xoay màn hình…
(khoảng 1 phút, đừng chạm)" >/dev/null 2>&1
    kill -CONT "$p" 2>/dev/null; rm -f "$FW_FLAG"
    stop framework 2>/dev/null || stop lab126_gui 2>/dev/null; sleep 2
  else
    "$FB" -q -c -m -M -t "regular=$BOLD,px=34" "Đang xoay màn hình…
(khoảng 1 phút, đừng chạm)" >/dev/null 2>&1
  fi
  start framework 2>/dev/null || start lab126_gui 2>/dev/null
  if wait_winmgr; then sleep 8; lock_kick "$want"; rota_wait "$r0" 15; else log "winmgr not available: cannot rotate"; fi
  fw_pause; sleep 1
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  if rot_ok; then log "xoay -> $want: cách C (khởi động lại giao diện Kindle)"
  else log "KHÔNG xoay được -> $want (rota $r0 -> $CUR_ROTA)"; REORIENT_FAIL=1; fi
  echo "$LOCK_NOW" > /tmp/dash_lock_now
}

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
  [ "$DIFF_DRAW" = 1 ] && return 0          # đang vẽ ngầm: chỉ ghi vào bộ nhớ màn hình, quét sau (diff_draw)
  inv=""; [ "$NIGHT_INVERT" = 1 ] && is_night && inv="-H"
  fl=""; [ "$1" = 1 ] && fl="-f"
  [ -z "$2" ] && SHOWN_INV="$inv"            # chế độ đảo màu đang hiển thị (để biết khi nào phải quét lại hết)
  "$FB" -q $fl $inv -s $2 >/dev/null 2>&1
}
# ---------- Chỉ quét vùng thật sự thay đổi ----------
# Vẽ toàn bộ vào bộ nhớ màn hình (chưa hiện), so từng dải 32 hàng trước/sau bằng cksum,
# rồi chỉ làm mới các dải khác nhau. Phần không đổi trên màn hình hoàn toàn đứng yên.
FBDEV=${FBDEV:-/dev/fb0}; BAND=32
fb_stride() { # chỉ dùng khi bộ nhớ màn hình xếp đúng theo chiều đang hiển thị (mỗi hàng ~ W điểm ảnh)
  _fs=${FB_SYS:-/sys/class/graphics/fb0}       # (FB_SYS: chỉ đổi khi chạy thử trên máy tính)
  FB_STRIDE=$(cat "$_fs/stride" 2>/dev/null); _bpp=$(cat "$_fs/bits_per_pixel" 2>/dev/null)
  case "$FB_STRIDE$_bpp" in ''|*[!0-9]*) FB_STRIDE=""; return ;; esac
  _row=$(( W * _bpp / 8 )); [ "$FB_STRIDE" -ge $_row ] && [ "$FB_STRIDE" -le $(( _row + 128 )) ] || FB_STRIDE=""
  [ -n "$FB_STRIDE" ] && fb_probe
  log "quét vùng đổi: ${FB_STRIDE:+bật (stride $FB_STRIDE, đảo $FB_FLIP)}${FB_STRIDE:-tắt (bộ nhớ màn hình không khớp chiều xoay)}"
}
fb_probe() { # tô ngầm 4 hàng trên cùng (không làm mới), xem bộ nhớ đổi ở đầu hay cuối -> FB_FLIP; rồi trả lại như cũ
  _b=$(( FB_STRIDE * 4 )); _last=$(( H / 4 - 1 ))
  dd if="$FBDEV" of=/tmp/dash_p0 bs=$_b count=1 2>/dev/null; dd if="$FBDEV" of=/tmp/dash_p1 bs=$_b skip=$_last count=1 2>/dev/null
  _a0=$(cksum < /tmp/dash_p0); _a1=$(cksum < /tmp/dash_p1)
  for _col in BLACK WHITE; do
    "$FB" -q -b -B $_col -k "top=0,left=0,width=$W,height=4" >/dev/null 2>&1
    _c0=$(dd if="$FBDEV" bs=$_b count=1 2>/dev/null | cksum); _c1=$(dd if="$FBDEV" bs=$_b skip=$_last count=1 2>/dev/null | cksum)
    [ "$_c0" != "$_a0" ] || [ "$_c1" != "$_a1" ] && break
  done
  dd if=/tmp/dash_p0 of="$FBDEV" bs=$_b conv=notrunc 2>/dev/null; dd if=/tmp/dash_p1 of="$FBDEV" bs=$_b seek=$_last conv=notrunc 2>/dev/null
  if [ "$_c0" != "$_a0" ]; then FB_FLIP=0
  elif [ "$_c1" != "$_a1" ]; then FB_FLIP=1
  else FB_STRIDE=""; log "quét vùng đổi: không dò được bộ nhớ màn hình -> tắt"; fi
}
fb_sums() { # -> một dòng tổng kiểm tra mỗi dải
  _bs=$(( FB_STRIDE * BAND )); _nb=$(( (H + BAND - 1) / BAND )); _i=0
  while [ $_i -lt $_nb ]; do dd if="$FBDEV" bs=$_bs skip=$_i count=1 2>/dev/null | cksum; _i=$(( _i + 1 )); done
}
diff_draw() { # vẽ lại nhưng chỉ quét các dải đổi; trả 1 nếu không làm được (khi đó gọi draw bình thường)
  [ -n "$FB_STRIDE" ] && [ -r "$FBDEV" ] || return 1
  fb_sums > /tmp/dash_sums_a 2>/dev/null || return 1
  DIFF_FULL=0; DIFF_IMGS=""; DIFF_DRAW=1; draw 0; DIFF_DRAW=0
  _inv=""; [ "$NIGHT_INVERT" = 1 ] && is_night && _inv="-H"
  [ "$_inv" != "$SHOWN_INV" ] && DIFF_FULL=1    # vừa bật/tắt đảo màu ban đêm: nội dung giống nhưng màn hình phải đổi hết
  _hr=${NOW_YMDH:-x}; [ "$_hr" != "$RESYNC_H" ] && { RESYNC_H=$_hr; [ -n "$RESYNC_DONE" ] && DIFF_FULL=1; RESYNC_DONE=1; }   # mỗi giờ 1 lần: đồng bộ lại cả màn hình (không nháy)
  if [ "$DIFF_FULL" = 1 ]; then refresh 0; log "quét: toàn màn hình, không nháy (ảnh nền mới / đảo màu / đồng bộ mỗi giờ)"; return 0; fi
  fb_sums > /tmp/dash_sums_b 2>/dev/null
  _runs=$(awk -v B=$BAND -v H=$H 'NR == FNR { a[FNR] = $0; next }
      { if (a[FNR] != $0) { if (s == "") s = FNR; e = FNR } else if (s != "") { printf "%d:%d ", (s-1)*B, (e-s+1)*B; s = "" } }
      END { if (s != "") printf "%d:%d ", (s-1)*B, (e-s+1)*B }' /tmp/dash_sums_a /tmp/dash_sums_b)
  _tot=0; for _r in $_runs; do _tot=$(( _tot + ${_r#*:} )); done
  if [ $_tot -ge $(( H * 7 / 10 )) ]; then refresh 0; log "quét: gần hết màn hình ($_tot hàng)"; return 0; fi
  [ -z "$_runs$DIFF_IMGS" ] && { log "quét: không có gì đổi"; return 0; }
  for _r in $_runs; do
    _t=${_r%:*}; _h=${_r#*:}; [ $(( _t + _h )) -gt $H ] && _h=$(( H - _t ))
    [ "$FB_FLIP" = 1 ] && _t=$(( H - _t - _h ))    # bộ nhớ xếp ngược chiều màn hình (để lộn ngược)
    _f=0; [ $_h -ge $(( H / 4 )) ] && _f=1      # vùng lớn (ảnh mới…) thì nháy riêng vùng đó cho khỏi bóng mờ
    refresh $_f "top=$_t,left=0,width=$W,height=$_h"
  done
  for _r in $DIFF_IMGS; do                   # vùng ảnh (eips) quét lại lần cuối cho đủ chữ/khung phủ lên
    set -- $(echo "$_r" | tr ':' ' ')
    _w=$3; _h=$4; [ $(( $2 + _w )) -gt $W ] && _w=$(( W - $2 )); [ $(( $1 + _h )) -gt $H ] && _h=$(( H - $1 ))
    [ $_w -gt 0 ] && [ $_h -gt 0 ] && refresh 0 "top=$1,left=$2,width=$_w,height=$_h"
  done
  log "quét vùng đổi: $_runs${DIFF_IMGS:+ · ảnh:$DIFF_IMGS}"
  return 0
}
# Nháy sạch toàn màn hình định kỳ (chống bóng mờ tích luỹ): mặc định 1 lần lúc 3 giờ sáng
clean_due() {
  case "${FULL_CLEAN:-dem}" in
    0) return 1 ;;
    dem) _d=$(date +%Y%m%d); [ "${NOW_YMDH#????????}" = 03 ] && [ "$CLEAN_DAY" != "$_d" ] && { CLEAN_DAY=$_d; return 0; }; return 1 ;;
    *) [ $(( NOWE - ${CLEAN_AT:-0} )) -ge $(( FULL_CLEAN * 3600 )) ] && return 0; return 1 ;;
  esac
}

image() {
  # Ảnh nền toàn màn hình (ui/bg_*): eips luôn tự làm mới vùng ảnh -> khi vẽ ngầm sẽ lộ nền trống, che chữ.
  # Nên lưu bản sao bộ nhớ màn hình ngay sau khi vẽ nền; lần sau chép lại bằng dd (không làm mới gì cả).
  case "$2$3:$1" in 00:*/ui/bg_*)
    if [ -n "$FB_STRIDE" ]; then
      _k="$1|$CUR_ROTA|$W|$FB_STRIDE|$DASH_VER"
      if [ "$DIFF_DRAW" = 1 ] && [ -s /tmp/dash_bg.raw ] && [ "$_k" = "$(cat /tmp/dash_bg.key 2>/dev/null)" ]; then
        dd if=/tmp/dash_bg.raw of="$FBDEV" bs=$FB_STRIDE 2>/dev/null && return 0
      fi
      eips -g "$1" -x 0 -y 0 >/dev/null 2>&1 || log "eips image failed: $1"
      [ "$DIFF_DRAW" = 1 ] && DIFF_FULL=1        # nền đã lộ ra -> phải quét lại toàn màn hình lần này
      dd if="$FBDEV" of=/tmp/dash_bg.raw bs=$FB_STRIDE count=$H 2>/dev/null && echo "$_k" > /tmp/dash_bg.key
      return 0
    fi ;;
  esac
  eips -g "$1" -x "$2" -y "$3" >/dev/null 2>&1 || log "eips image failed: $1"
  # vẽ ngầm: eips đã tự làm mới vùng ảnh khi chữ phủ lên chưa vẽ -> ghi lại vùng để quét lại lúc cuối
  [ "$DIFF_DRAW" = 1 ] && { set -- "$1" "$2" "$3" $(od -An -tu1 -j16 -N8 "$1" 2>/dev/null)
    [ $# -ge 11 ] && DIFF_IMGS="$DIFF_IMGS $3:$2:$(( $5 * 65536 + $6 * 256 + $7 )):$(( $9 * 65536 + ${10} * 256 + ${11} ))"; }
}

WD_LONG="Chủ Nhật|Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm|Thứ Sáu|Thứ Bảy"
WD_SHORT="CN|T2|T3|T4|T5|T6|T7"
pick() { _i=$(( $2 + 1 )); _o=$IFS; IFS='|'; set -- $1; IFS=$_o; eval "echo \"\${$_i}\""; }
# ngày có sự kiện -> EVDAYS=" 20773 20774 ..." (1 lần đọc thay vì grep từng ô ngày)
load_evdays() { EVDAYS=" $(awk -F'|' '{ if (!($2 in s)) { s[$2] = 1; printf "%s ", $2 } }' "$EV" 2>/dev/null)"; }
is_evday() { case "$EVDAYS" in *" $1 "*) return 0 ;; esac; return 1; }
# âm lịch cả tháng -> biến LND_<ngày> LNM_<ngày>
load_lunar_month() { # tháng năm
  [ "$LUNM_KEY" = "$1.$2" ] && return 0; LUNM_KEY="$1.$2"
  while IFS='|' read -r _d _ld _lm; do eval "LND_$_d=$_ld; LNM_$_d=$_lm"; done <<EOT
$(awk -v MODE=month -v M="$1" -v Y="$2" -f "$DIR/lib/lunar.awk")
EOT
}

# Ngày <-> số ngày từ 1970 (thuật toán Howard Hinnant), tính bằng số học của shell, không gọi awk
epoch_day() { _y=$(( $1 - ($2 <= 2) )); _era=$(( _y / 400 )); _yoe=$(( _y - _era * 400 ))
  _mp=$(( $2 > 2 ? $2 - 3 : $2 + 9 )); _doy=$(( (153 * _mp + 2) / 5 + $3 - 1 ))
  echo $(( _era * 146097 + _yoe * 365 + _yoe / 4 - _yoe / 100 + _doy - 719468 )); }
day_dm() { _z=$(( $1 + 719468 )); _era=$(( _z / 146097 )); _doe=$(( _z - _era * 146097 ))
  _yoe=$(( (_doe - _doe / 1460 + _doe / 36524 - _doe / 146096) / 365 )); _doy=$(( _doe - (365 * _yoe + _yoe / 4 - _yoe / 100) ))
  _mp=$(( (5 * _doy + 2) / 153 )); _d=$(( _doy - (153 * _mp + 2) / 5 + 1 )); _m=$(( _mp < 10 ? _mp + 3 : _mp - 9 ))
  echo "$_d/$_m"; }

# ---------- Trạng thái ----------
MOFF=0; EVPAGE=0; PHOFF=0; VIEW=main; LADJ=0; LAST_TOUCH=0; LIGHT_NOW=""; NIGHT_WAS=""; PICKPAGE=0
LAST_KEY=""; NFULL=0

is_night() {
  h=$(date +%H); h=${h#0}
  if [ "$NIGHT_START" -gt "$NIGHT_END" ]; then [ "$h" -ge "$NIGHT_START" ] || [ "$h" -lt "$NIGHT_END" ]
  else [ "$h" -ge "$NIGHT_START" ] && [ "$h" -lt "$NIGHT_END" ]; fi
}
light_level() {
  if [ "${LIGHT_IDLE_MIN:-0}" -gt 0 ] && [ "$CHARGING" != 1 ] && [ -n "$LAST_ACT" ] && [ $(( ${NOWE:-0} - LAST_ACT )) -ge $(( LIGHT_IDLE_MIN * 60 )) ]; then echo 0; return; fi
  [ "$VIEW" = status ] && [ "${STATUS_DIM:-1}" = 1 ] && status_away "$ST_ID" && { echo 0; return; }
  l="$LIGHT_DAY"; is_night && l="$LIGHT_NIGHT"
  [ -z "$l" ] && { echo ""; return; }
  l=$(( l + LADJ )); [ $l -lt 0 ] && l=0; [ $l -gt 24 ] && l=24; echo "$l"
}
# Nút ☀ trên thanh trên cùng: mỗi lần chạm lên một mức, quá mức cao nhất thì về tắt
light_cycle() {
  _cur=$(light_level); [ -n "$_cur" ] || return 0
  _base="$LIGHT_DAY"; is_night && _base="$LIGHT_NIGHT"
  _nx=0; for _v in 2 4 8 12 16 24; do [ $_v -gt $_cur ] && { _nx=$_v; break; }; done
  LADJ=$(( _nx - _base )); LAST_ACT=$(date +%s); set_light
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
    B_STATUS=630; B_LIGHT=706; B_PAGE=790; B_GEAR=866; B_HOME=942
    CLK_X=36; CLK_Y=80; CLK_W=460; CLK_H=200; CLK_PX=170; ANA_X=170; ANA_Y=82
    LUN_Y=280; LUN_X=40
    WXL=land; WX_X=40; WX_Y=316
    DIV="box 460 40 460 2; box 84 512 2 664"
    CX=530; CW=65; CAL_Y=82; CAL_X2=985; RH=50; CAL_PX=38; CAL_LPX=17; HDR_PX=24; HY_OFF=44; GY_OFF=34; LUN_POS=below; CAL_Y2=470
    EV_X=40; EV_Y=472; EV_W=460; EV_N=3; EV_STEP=90; EV_Y2=758
    PH_DIR=land; PH_X=530; PH_Y=480; PH_W=454; PH_H=270; GREET_X=742; GREET_W=243; ORN_TAG=ngang
  else                            # DỌC 758x1024
    B_STATUS=364; B_LIGHT=440; B_PAGE=524; B_GEAR=600; B_HOME=676
    CLK_X=30; CLK_Y=82; CLK_W=416; CLK_H=196; CLK_PX=190; ANA_X=128; ANA_Y=82
    LUN_Y=280; LUN_X=40
    WXL=side; WX_X=460; WX_Y=88
    DIV="box 316 40 678 2; box 752 40 678 2"
    CX=40; CW=97; CAL_Y=324; CAL_X2=718; RH=55; CAL_PX=48; CAL_LPX=20; HDR_PX=28; HY_OFF=48; GY_OFF=40; LUN_POS=right; CAL_Y2=750
    EV_X=40; EV_Y=764; EV_W=678; EV_N=3; EV_STEP=82; EV_Y2=1024
    PH_DIR=""; PH_X=420; PH_Y=764; PH_W=298; PH_H=250; GREET_X=330; GREET_W=388; ORN_TAG=doc
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

lunar_today() { # -> LD LM LY LEAP CANCHI   (tính 1 lần mỗi ngày)
  [ "$LUN_KEY" = "$Y.$M.$D" ] && return 0; LUN_KEY="$Y.$M.$D"
  set -- $(awk -v MODE=day -v D="$D" -v M="$M" -v Y="$Y" -f "$DIR/lib/lunar.awk" | tr '|' ' ')
  L_D=$1; L_M=$2; L_Y=$3; L_LEAP=$4; L_CC="$5 $6"
}
holiday() { # -> HOLI_THEME HOLI_TEXT   (tính 1 lần mỗi ngày)
  [ "$HOLI_KEY" = "$Y.$M.$D.$ORNAMENT" ] && return 0; HOLI_KEY="$Y.$M.$D.$ORNAMENT"
  HOLI_THEME=""; HOLI_TEXT=""
  lunar_today
  r=$(awk -v D="$D" -v M="$M" -v Y="$Y" -v LD="$L_D" -v LM="$L_M" -v LEAP="$L_LEAP" -f "$DIR/lib/holiday.awk")
  HOLI_THEME=${r%%|*}; HOLI_TEXT=${r#*|}           # dòng chúc mừng ngày lễ vẫn hiện khi tắt viền
  [ "$ORNAMENT" = 0 ] && HOLI_THEME=""
  case "$ORNAMENT" in thuong) HOLI_THEME=macdinh ;; hoala|hoanhai|ladeo) HOLI_THEME=$ORNAMENT ;; esac
}
draw_ornaments() {
  [ -n "$HOLI_THEME" ] || return 0
  tag=doc; [ $W -gt $H ] && tag=ngang
  f="$DIR/ornaments/${HOLI_THEME}_${tag}"
  [ -f "${f}_l.png" ] || f="$DIR/ornaments/macdinh_${tag}"
  [ -f "${f}_l.png" ] || return 0
  image "${f}_l.png" 2 0
  image "${f}_r.png" $(( W - 28 )) 0
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
  cs="$CLOCK_STYLE"; [ "$cs" = auto ] && cs=so24
  [ "$CLK_FORCE" = digital ] && case "$cs" in kim|chu|kimtg|vong|lat) cs=so24 ;; esac
  case "$cs" in
    so24|so12|kim|chu) ;;
    *) if modern_ok; then
         CLOCK_STYLE_SAVE="$CLOCK_STYLE"; CLOCK_STYLE=$cs
         if [ "$CLK_CENTER" = 1 ]; then w_clock 40 $CLK_Y $(( W - 80 )) $(( CLK_PX * 80 / 100 )) c; else w_clock $CLK_X $CLK_Y $CLK_W $CLK_H l; fi
         CLOCK_STYLE="$CLOCK_STYLE_SAVE"; return
       fi; cs=so24 ;;
  esac
  if [ "$CLK_CENTER" = 1 ]; then
    TXTOPT="-m"
    if [ "$cs" = so12 ]; then
      h12=$(( h % 12 )); [ $h12 = 0 ] && h12=12; ap="Sáng"; [ $h -ge 12 ] && ap="Chiều"; [ $h -ge 18 ] && ap="Tối"
      txt $CLK_PX $CLK_Y 0 "$h12:$mm" b; txt 30 $(( CLK_Y + CLK_PX * 98 / 100 )) 0 "$ap" b
    else txt $CLK_PX $CLK_Y 0 "$hh:$mm" b; fi
    TXTOPT=""; return
  fi
  case "$cs" in
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
  tx_fit bold 32 40 18 "$(date_text)" $(( B_STATUS - 140 ))
  [ "$ONCE" != 1 ] && toolbar_icons s
  box 72 40 $(( W - 80 )) 2
}

draw_weather() {
  pin=""                                     # % pin đã hiện trên thanh trên cùng
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

# Dấu vân tay nội dung màn hình: giống nhau = không cần vẽ lại
data_sig() { # gọi sau khi tải dữ liệu: chỉ giữ phần hiển thị (bỏ dấu thời gian thay đổi mỗi lần tải)
  WX_SIG=""; parse_weather 2>/dev/null && WX_SIG="$WX_TEMP|$WX_DESC|$WX_MIN|$WX_MAX|$WX_RAIN|$WX_HUM|$WX_RISE|$WX_SET"
  CAL_SIG=$(grep -hv -e '^DTSTAMP' -e '^LAST-MODIFIED' -e '^SEQUENCE' "$CALDIR"/*.ics 2>/dev/null | cksum | cut -d' ' -f1)
}
ev_soon() { # có sự kiện đang diễn ra / sắp tới trong 3 giờ -> cập nhật "còn N phút" mỗi 15 phút
  EV_SOON=0; [ -s "$EV" ] || return 0
  set -- $(date '+%H %M'); _nm=$(( 1$1 % 100 * 60 + 1$2 % 100 ))
  awk -F'|' -v TD="$TD" -v N="$_nm" '{ split($1, k, ":") } $2 == TD && $4 == 0 && $3 + k[2] > N && $3 < N + 180 { f = 1 } END { exit !f }' "$EV" && EV_SOON=1
}
screen_sig() {
  _p=""; [ "$PHOTO_MODE" != fixed ] && _p=$(( ${NOWE:-0} / (${PHOTO_MIN:-60} * 60) + PHOFF ))
  _q=""; [ "$EV_SOON" = 1 ] && _q=$(( mnow / 15 ))
  _n=0; is_night && _n=1
  echo "$PAGE|$MOFF|$EVPAGE|${NOW_YMDH%??}|$_n|$WX_SIG|$CAL_SIG|$_p|$_q|$BATT_B$CHARGING|$LOCK_NOW|$UPD_AVAIL|$LAYOUT"
}

# Sự kiện: chỉ đọc lại file .ics khi lịch vừa tải về hoặc khoảng ngày đổi (đỡ tốn CPU mỗi lần vẽ)
events_to() { # FROM TO FILE
  k="$1.$2.$TD.$(cat "$CALDIR/stamp" 2>/dev/null).$ICS_URL"
  [ "$k" = "$EV_KEY" ] && [ -f "$3" ] && return 0
  events "$1" "$2" > "$3"; EV_KEY="$k"
}

draw_calendar() {
  cy=$Y; cm=$(( M + MOFF ))
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  CFIRST=$(epoch_day $cy $cm 1)
  hl=0; [ $cy = $Y ] && [ $cm = $M ] && hl=$D
  txt 36 $CAL_Y $CX "Tháng $cm" b
  txt 36 $CAL_Y $(( CX + (${#cm} + 6) * 15 + 14 )) "$cy"
  if [ $MOFF != 0 ]; then txt 20 $(( CAL_Y + 14 )) $(( CAL_X2 - 200 )) "chạm tiêu đề: về hôm nay" "" 200
  elif [ -n "$HOLI_TEXT" ]; then
    txt 22 $(( CAL_Y + 12 )) $GREET_X "$I_CAL" s
    txt 22 $(( CAL_Y + 12 )) $(( GREET_X + 28 )) "$HOLI_TEXT" b $(( GREET_W - 28 )) 34
  fi
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
      if [ "$all" = 1 ]; then when="$when · cả ngày"; else when="$when · $(hm_range $min ${key#*:})"; fi
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
  if layout_active; then render_layout "$1"; return; fi
  Y=$(date +%Y); M=$(date +%m); D=$(date +%d); M=${M#0}; D=${D#0}
  TD=$(epoch_day "$Y" "$M" "$D")
  set_layout
  PHOTO=$(pick_photo "$PH_DIR")
  cm=$(( M + MOFF )); cy=$Y
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  f=$(epoch_day $cy $cm 1); t=$(( f + 31 )); [ $f -gt $TD ] && f=$TD
  [ $t -lt $(( TD + DAYS_AHEAD )) ] && t=$(( TD + DAYS_AHEAD ))
  EV=/tmp/dash_events.txt; events_to "$f" "$t" "$EV"

  log "render main: begin"
  holiday
  "$FB" -q -b -k >/dev/null 2>&1
  draw_ornaments
  draw_header
  draw_clock
  [ "$SHOW_LUNAR" = 1 ] && txt 24 $LUN_Y $LUN_X "$(lunar_text)" "" $(( CLK_W ))
  draw_weather
  eval "$DIV"
  draw_calendar
  draw_events
  if [ -n "$PHOTO" ]; then
    if [ $W -le $H ] && modern_ok; then LAY_PHOTO=tran; w_photo $PH_X $PH_Y $PH_W $PH_H; else image "$PHOTO" $PH_X $PH_Y; fi
  fi
  refresh "$1"
  log "render main: done"
}

# Vẽ lại vùng đồng hồ chống "bóng ma" e-ink (vd 0 -> 1 còn sót nét của số 0):
#   1) tô trắng + làm mới vùng (xoá nét cũ)  2) vẽ số mới + làm mới  3) cứ CLOCK_CLEAN_MIN phút thì nháy đen
#   riêng vùng đồng hồ một lần cho sạch hẳn (không nháy cả màn hình)
clock_region_redraw() { # top left width height lệnh_vẽ...
  _rt=$(( $1 - 6 )); _rl=$(( $2 - 8 )); _rw=$(( $3 + 16 )); _rh=$(( $4 + 12 )); shift 4   # vùng xoá rộng hơn chữ số một chút
  [ $_rt -lt 0 ] && _rt=0; [ $_rl -lt 0 ] && _rl=0
  _reg="top=$_rt,left=$_rl,width=$_rw,height=$_rh"
  box $_rt $_rl $_rw $_rh WHITE
  _m=$(date +%M); _m=${_m#0}; [ -z "$_m" ] && _m=0
  if [ "${CLOCK_CLEAN_MIN:-10}" -gt 0 ] && [ $(( _m % ${CLOCK_CLEAN_MIN:-10} )) = 0 ]; then
    "$@"; refresh 1 "$_reg"                 # nháy đen riêng vùng giờ: sạch hoàn toàn
  else
    refresh 0 "$_reg"                       # bước 1: xoá trắng
    "$@"; refresh 0 "$_reg"                 # bước 2: số mới
  fi
}
update_clock() { # chỉ vẽ lại vùng đồng hồ (nhanh, ít tốn pin)
  if [ "$PAGE" = main ] && layout_active; then update_clock_layout; return; fi
  set_page_clock
  clock_region_redraw $CLK_Y $CLK_X $CLK_W $CLK_H draw_clock
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
SETTINGS_LOOK='LAYOUT|Bố cục|codien=Cổ điển;toigian=Tối giản;thuysi=Lưới Thụy Sĩ;the=Thẻ;anh=Ảnh lớn;chu=Chữ;lich=Lịch
CLOCK_STYLE|Kiểu đồng hồ|auto=Theo bố cục;mong=Mảnh;dam=Đậm;mono=Kỹ thuật số;lat=Lật số;kimtg=Kim tối giản;vong=Vòng phút;chu=Bằng chữ;so12=12 giờ;so24=Số cổ điển;kim=Kim cổ điển
EVENT_STYLE|Kiểu sự kiện|auto=Theo bố cục;danhsach=Danh sách;gon=Gọn;moc=Mốc dọc;baygio=Bây giờ & tiếp theo;tuan=Dải tuần;cham=Tháng dạng chấm;dongtg=Dòng thời gian;cau=Câu văn
PHOTO_STYLE|Kiểu ảnh|auto=Theo bố cục;tran=Tràn khung;polaroid=Polaroid;tron=Tròn;nhan=Ảnh + nhãn ngày;bia=Ảnh bìa
DATE_STYLE|Kiểu ngày (Cổ điển)|dai=Thứ Hai, 16/11/2026;daydu=Thứ Hai, ngày 16 tháng 11;ngan=T2 · 16.11.2026;iso=2026-11-16
SHOW_LUNAR|Âm lịch|1=Bật;0=Tắt
TODAY_STYLE|Hôm nay (Cổ điển)|vong=Vòng tròn;khung=Khung vuông;gach=Gạch chân;den=Tròn đen (thử)
WEEK_START|Tuần bắt đầu|1=Thứ Hai;0=Chủ Nhật
WEATHER_ICON|Biểu tượng thời tiết|1=Bật;0=Tắt
CLOCK_CLEAN_MIN|Làm sạch vùng giờ (nháy)|10=Mỗi 10 phút;5=Mỗi 5 phút;1=Mỗi phút;0=Không nháy
FULL_CLEAN|Nháy sạch toàn màn hình|dem=1 lần/ngày (3 giờ sáng);6=Mỗi 6 giờ;12=Mỗi 12 giờ;0=Không bao giờ
DIFF_REFRESH|Khi nội dung đổi|1=Chỉ quét vùng đổi;0=Quét toàn màn hình
CONTRAST|Độ tương phản|cao=Cao (rõ trên e-ink);vua=Vừa;nhe=Nhẹ (mảnh như bản thiết kế)
ORNAMENT|Hoa văn trang trí|auto=Theo ngày lễ;hoala=Dây hoa lá;hoanhai=Chuỗi hoa nhỏ;ladeo=Lá dương xỉ;thuong=Hoa văn thường;0=Tắt'
SET_GROUP=main
settings_def() { case "$SET_GROUP" in look) echo "$SETTINGS_LOOK" ;; power) echo "$SETTINGS_POWER" ;; auto) echo "$SETTINGS_AUTO" ;; *) echo "$SETTINGS_DEF" ;; esac; }
group_title() { case "$SET_GROUP" in look) echo "Giao diện" ;; power) echo "Pin & đèn" ;; auto) echo "Tự động theo giờ" ;; esac; }
SETTINGS_POWER='WIFI_SAVE|Tiết kiệm Wi-Fi|1=Bật (tắt Wi-Fi giữa các lần tải);0=Tắt (luôn bật)
LIGHT_IDLE_MIN|Tắt đèn khi không chạm|0=Không;5=Sau 5 phút;15=Sau 15 phút;30=Sau 30 phút;60=Sau 1 giờ
STATUS_DIM|Tắt đèn khi vắng mặt|1=Bật;0=Tắt
LIGHT_DAY|Đèn ban ngày|0=Tắt;2=2;4=4;6=6;8=8;10=10;12=12;16=16;20=20;24=24
LIGHT_NIGHT|Đèn ban đêm|0=Tắt;1=1;2=2;4=4;6=6;8=8
NIGHT_INVERT|Đảo màu ban đêm|0=Tắt;1=Bật (thử)
REFRESH_MIN|Cập nhật giờ mỗi|1=1 phút;2=2 phút;5=5 phút;10=10 phút
HOME_MODE|Thoát về Home|nhanh=Nhanh (~2 giây);antoan=An toàn (~30 giây)
HOME_REPAINT|Khi về Home, làm mới Kindle|chuyen=Chuyển trang (~3 giây);nguon=Thêm ngủ rồi dậy (~7 giây, chắc nhất);0=Không
DEEP_SLEEP|Ngủ sâu ban đêm|0=Tắt;1=Bật (thử nghiệm)
DEEP_SLEEP_MIN|Khi ngủ sâu, dậy mỗi|30=30 phút;60=1 giờ;120=2 giờ
@SLEEPTEST|Thử ngủ sâu 1 phút…|'
SETTINGS_AUTO='SCHEDULE|Tự đổi giao diện theo giờ|0=Tắt;lamviec=Ngày làm việc;hoctap=Học tập;giadinh=Ở nhà;tuychinh=Tuỳ chỉnh (lich-giao-dien.txt)
AUTO_MEET|Tự bật "Đang họp" theo lịch|0=Tắt;1=Bật
@SCHEDVIEW|Xem lịch đang dùng…|'
SETTINGS_DEF='@LOOK|Giao diện…|
@POWER|Pin & đèn…|
@AUTO|Tự động theo giờ…|
@REMOTE|Điều khiển từ điện thoại…|
@DIAG|Chẩn đoán & pin…|
@CALIB|Hiệu chỉnh cảm ứng…|
DEFAULT_PAGE|Trang mặc định|main=Bảng chính;tin=Bảng tin;bloc=Lịch bloc;dem=Ban đêm;pomo=Pomodoro;news=Tin tức
NIGHT_PAGE|Trang ban đêm|dem=Tự chuyển sang Ban đêm;giu=Giữ trang đang xem
ORIENTATION|Hướng màn hình|doc=Dọc (sạc ở dưới);nguoc=Lộn ngược (sạc ở trên);ngangtrai=Ngang (sạc bên trái);ngangphai=Ngang (sạc bên phải)
PHOTO_MODE|Ảnh|auto=Tự đổi;fixed=Cố định
PHOTO_MIN|Đổi ảnh mỗi|1=1 phút;5=5 phút;15=15 phút;30=30 phút;60=1 giờ;180=3 giờ;1440=1 ngày
DAYS_AHEAD|Sự kiện trong|7=7 ngày;14=14 ngày;30=30 ngày
@RECV|Nhận ảnh từ Mac qua Wi-Fi…|
@PICK|Chọn ảnh từ danh sách…|
@UPDATE|Cập nhật phần mềm|'

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
settings_geom() { # hàng cao 72 điểm cho dễ chạm; nhiều mục quá thì chia trang (thanh lật trang ở đáy)
  SROW_H=72; SY0=84
  if [ $W -gt $H ]; then SCOLS=2; SCOLW=$(( (W - 80) / 2 )); else SCOLS=1; SCOLW=$(( W - 80 )); fi
  [ "$SET_GROUP" = "$SPAGE_G" ] || { SPAGE=0; SPAGE_G=$SET_GROUP; }
  STOTAL=$(settings_def | grep -c .)
  SPER=$(( (H - SY0 - 10) / SROW_H ))
  if [ $STOTAL -gt $(( SPER * SCOLS )) ]; then SPER=$(( (H - SY0 - 90) / SROW_H )); fi
  SPP=$(( SPER * SCOLS )); SPAGES=$(( (STOTAL + SPP - 1) / SPP )); [ ${SPAGE:-0} -ge $SPAGES ] && SPAGE=0
  SNAV_Y=$(( H - 80 ))
}
render_settings() {
  settings_geom
  "$FB" -q -b -k >/dev/null 2>&1
  if [ "$SET_GROUP" != main ]; then txt 34 18 40 "$I_LEFT" s; txt 34 18 84 "$(group_title)" b
  else txt 34 18 40 "$I_GEAR" s; txt 34 18 92 "Cài đặt" b; fi
  txt 30 22 $(( W - 150 )) "$I_CHECK" s; txt 30 20 $(( W - 112 )) "Xong" b
  box 72 40 $(( W - 80 )) 2
  i=0
  settings_def | sed -n "$(( SPAGE * SPP + 1 )),$(( SPAGE * SPP + SPP ))p" | while IFS='|' read -r key label opts; do
    col=$(( i / SPER )); row=$(( i % SPER ))
    x=$(( 40 + col * SCOLW )); y=$(( SY0 + row * SROW_H + 8 ))
    vw=$(( SCOLW * 45 / 100 ))
    txt 30 $(( y + 8 )) $(( x + 4 )) "$label" "" $(( SCOLW - vw - 20 )) 44
    if [ "$key" = "@UPDATE" ]; then
      ut="Bản $DASH_VER"; [ -n "$UPD_AVAIL" ] && ut="Có bản mới $UPD_AVAIL"
      txt 30 $(( y + 8 )) $(( x + SCOLW - vw )) "$ut" b $(( vw - 10 )) 44
    elif [ "$key" = "@PICK" ]; then txt 30 $(( y + 8 )) $(( x + SCOLW - 44 )) "$I_RIGHT" s
    elif [ "$key" = "@REMOTE" ]; then
      rt="Tắt"; [ "$REMOTE" = 1 ] && rt="Bật"
      txt 30 $(( y + 8 )) $(( x + SCOLW - vw )) "$rt" b $(( vw - 50 )) 44; txt 30 $(( y + 8 )) $(( x + SCOLW - 44 )) "$I_RIGHT" s
    elif [ "$key" = "@DIAG" ]; then
      batt_rate; dt="Pin ${BATT:-$(battery)}%"; [ -n "$BR_LEFT" ] && dt="$dt · còn $BR_LEFT"
      txt 30 $(( y + 8 )) $(( x + SCOLW - vw )) "$dt" b $(( vw - 50 )) 44; txt 30 $(( y + 8 )) $(( x + SCOLW - 44 )) "$I_RIGHT" s
    elif [ "${key#@}" != "$key" ] && [ "$key" != "@LOOK" ]; then txt 30 $(( y + 8 )) $(( x + SCOLW - 44 )) "$I_RIGHT" s
    elif [ "$key" = "@LOOK" ]; then
      txt 30 $(( y + 8 )) $(( x + SCOLW - vw )) "$(setting_display LAYOUT "$(echo "$SETTINGS_LOOK" | sed -n 1p | cut -d'|' -f3)")" b $(( vw - 50 )) 44
      txt 30 $(( y + 8 )) $(( x + SCOLW - 44 )) "$I_RIGHT" s
    else txt 30 $(( y + 8 )) $(( x + SCOLW - vw )) "$(setting_display "$key" "$opts")" b $(( vw - 10 )) 44; fi
    box $(( y + SROW_H - 10 )) $x $(( SCOLW - 16 )) 1
    i=$((i + 1))
  done
  if [ $SPAGES -gt 1 ]; then                 # thanh lật trang
    box $(( SNAV_Y - 6 )) 40 $(( W - 80 )) 2
    [ $SPAGE -gt 0 ] && txt 32 $(( SNAV_Y + 14 )) 40 "‹ Trang trước" b 260
    txt 26 $(( SNAV_Y + 18 )) $(( W / 2 - 30 )) "$(( SPAGE + 1 ))/$SPAGES" "" 80
    [ $(( SPAGE + 1 )) -lt $SPAGES ] && txt 32 $(( SNAV_Y + 14 )) $(( W - 250 )) "Trang sau ›" b 220
  fi
  refresh 1
}
settings_tap() { # x y
  if [ $2 -le 80 ]; then
    if [ $1 -ge $(( W - 200 )) ]; then VIEW=main; SET_GROUP=main
    elif [ "$SET_GROUP" != main ] && [ $1 -le 300 ]; then SET_GROUP=main; fi
    return
  fi
  settings_geom
  if [ $SPAGES -gt 1 ] && [ $2 -ge $(( SNAV_Y - 10 )) ]; then   # lật trang
    if [ $1 -lt $(( W / 2 )) ]; then [ $SPAGE -gt 0 ] && SPAGE=$(( SPAGE - 1 )); else [ $(( SPAGE + 1 )) -lt $SPAGES ] && SPAGE=$(( SPAGE + 1 )); fi
    return
  fi
  [ $2 -ge $(( SY0 + 8 )) ] || return
  row=$(( ($2 - SY0 - 8) / SROW_H )); col=$(( ($1 - 40) / SCOLW )); [ $col -ge $SCOLS ] && return
  [ $row -ge $SPER ] && return
  idx=$(( SPAGE * SPP + col * SPER + row + 1 ))
  line=$(settings_def | sed -n "${idx}p"); [ -n "$line" ] || return
  key=${line%%|*}; opts=${line##*|}
  case "$key" in
    @LOOK) SET_GROUP=look; return ;; @POWER) SET_GROUP=power; return ;; @AUTO) SET_GROUP=auto; return ;;
    @REMOTE) VIEW=remote; return ;; @DIAG) VIEW=diag; return ;; @CALIB) VIEW=calib; return ;;
    @RECV) recv_start; VIEW=recv; return ;;
    @SLEEPTEST) deep_test; return ;;
    @SCHEDVIEW) MSG_TEXT=$( [ "$SCHEDULE" = 0 ] && echo "Chưa bật lịch tự đổi giao diện." || sched_preset "$SCHEDULE" | sed 's/layout/bố cục/;s/status/trạng thái/;s/back/thoát trạng thái/;s/page/trang/' | tr '\n' ';' | sed 's/;/ · /g'); MSG_TIME=$(date +%H:%M); MSG_PREV=main; VIEW=msg; return ;;
  esac
  if [ "$key" = "@PICK" ]; then VIEW=pick; PICKPAGE=0; return; fi
  if [ "$key" = "@UPDATE" ]; then
    "$FB" -q -c -m -M -t "regular=$BOLD,px=36" "Đang kiểm tra bản mới…" >/dev/null 2>&1
    wifi_on >/dev/null 2>&1
    r=$(sh "$DIR/update.sh" --check 2>/dev/null); date +%s > /tmp/dash_otacheck; log "update check: $r"
    UPD_MSG=""; UPD_AVAIL=""
    case "$r" in
      available*) r=${r#available }; UPD_AVAIL=${r%%|*}; UPD_NOTES=${r#*|} ;;
      uptodate*) UPD_MSG="Bạn đang dùng bản mới nhất ($DASH_VER)." ;;
      *) UPD_MSG="Không kiểm tra được: ${r#error }" ;;
    esac
    VIEW=update; return
  fi
  CH_KEY="$key"; CH_LABEL=$(echo "$line" | cut -d'|' -f2); CH_OPTS="$opts"; VIEW=choose
}

# ---------- Trang chọn giá trị (danh sách) ----------
# Hướng màn hình: lưới 2x2 có hình minh hoạ; các mục khác: danh sách, chạm là chọn.
choose_geom() {
  CH_N=$(echo "$CH_OPTS" | tr ';' '\n' | grep -c .)
  CY0=96
  GAL=0
  if [ "$CH_KEY" = ORIENTATION ]; then
    CCOLS=2; CW2=$(( (W - 80) / 2 )); CRH=$(( (H - CY0 - 30) / 2 )); [ $CRH -gt 330 ] && CRH=330
    CPER=4
  elif [ -f "$DIR/ui/${CH_KEY}_$(echo "$CH_OPTS" | tr ';' '\n' | sed -n 2p | cut -d= -f1).png" ]; then
    GAL=1; CCOLS=2; [ $W -gt $H ] && CCOLS=3
    CW2=$(( (W - 80) / CCOLS )); rows=$(( (CH_N + CCOLS - 1) / CCOLS ))
    CRH=$(( (H - CY0 - 20) / rows )); CPER=$CH_N
  else
    CRH=80; CPER=$(( (H - CY0 - 20) / CRH )); CCOLS=1
    [ $CH_N -gt $CPER ] && CCOLS=2
    CW2=$(( (W - 80) / CCOLS ))
  fi
}
render_choose() {
  choose_geom
  cur=$(setting_value "$CH_KEY")
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_LEFT" s; txt 34 18 80 "$CH_LABEL" b $(( W - 300 ))
  txt 30 20 $(( W - 140 )) "Quay lại" "" 120
  box 72 40 $(( W - 80 )) 2
  i=0
  echo "$CH_OPTS" | tr ';' '\n' | while IFS='=' read -r k d; do
    [ -n "$k" ] || continue
    if [ "$CH_KEY" = ORIENTATION ]; then
      col=$(( i % 2 )); row=$(( i / 2 ))
      x=$(( 40 + col * CW2 )); y=$(( CY0 + 10 + row * CRH ))
      [ "$k" = "$cur" ] && frame $(( y - 4 )) $(( x + 4 )) $(( CW2 - 8 )) $(( CRH - 12 )) 5 || frame $(( y - 4 )) $(( x + 4 )) $(( CW2 - 8 )) $(( CRH - 12 )) 1
      [ -f "$DIR/ui/orient_$k.png" ] && image "$DIR/ui/orient_$k.png" $(( x + (CW2 - 170) / 2 )) $(( y + 14 ))
      txt 26 $(( y + 196 )) $(( x + 20 )) "$d" b $(( CW2 - 40 )) 80
      [ "$k" = "$cur" ] && txt 24 $(( y + 8 )) $(( x + 16 )) "$I_CHECK" s
    elif [ $GAL = 1 ]; then
      col=$(( i % CCOLS )); row=$(( i / CCOLS ))
      x=$(( 40 + col * CW2 )); y=$(( CY0 + row * CRH ))
      if [ "$k" = "$cur" ]; then frame $(( y + 4 )) $(( x + 4 )) $(( CW2 - 8 )) $(( CRH - 8 )) 4; st=b; else frame $(( y + 4 )) $(( x + 4 )) $(( CW2 - 8 )) $(( CRH - 8 )) 1; st=""; fi
      th="$DIR/ui/${CH_KEY}_$k.png"
      if [ -f "$th" ]; then
        set -- $(od -An -tu1 -j16 -N8 "$th" 2>/dev/null)       # kích thước PNG từ IHDR
        if [ $# -ge 8 ]; then tw_=$(( $3 * 256 + $4 )); th_=$(( $7 * 256 + $8 )); else tw_=300; th_=$(( CRH - 60 )); fi
        image "$th" $(( x + (CW2 - tw_) / 2 )) $(( y + 12 + (CRH - 54 - th_) / 2 ))
      else
        txt 34 $(( y + (CRH - 54) / 2 - 10 )) $(( x + 30 )) "Tự động" b $(( CW2 - 60 ))
        txt 22 $(( y + (CRH - 54) / 2 + 36 )) $(( x + 30 )) "mỗi bố cục một kiểu hợp nhất" "" $(( CW2 - 60 )) 64
      fi
      [ "$k" = "$cur" ] && txt 24 $(( y + CRH - 44 )) $(( x + 16 )) "$I_CHECK" s
      txt 24 $(( y + CRH - 46 )) $(( x + 50 )) "$d" "$st" $(( CW2 - 70 )) 36
    else
      col=$(( i / CPER )); row=$(( i % CPER ))
      x=$(( 40 + col * CW2 )); y=$(( CY0 + row * CRH ))
      if [ "$k" = "$cur" ]; then txt 34 $(( y + 18 )) $(( x + 6 )) "$I_DISC" s; st=b; else txt 34 $(( y + 18 )) $(( x + 6 )) "$I_RING" s; st=""; fi
      txt 32 $(( y + 16 )) $(( x + 58 )) "$d" "$st" $(( CW2 - 74 )) 50
      box $(( y + CRH - 2 )) $x $(( CW2 - 16 )) 1
    fi
    i=$((i + 1))
  done
  [ "$CH_KEY" = ORIENTATION ] && txt 22 $(( H - 44 )) 40 "Sau khi xoay, chạm ô giữa màn hình để giữ chiều mới (không chạm sẽ tự quay lại)." "" $(( W - 80 )) 40
  refresh 1
}
choose_tap() { # x y
  if [ $2 -le 80 ]; then VIEW=settings; return; fi
  choose_geom
  if [ "$CH_KEY" = ORIENTATION ]; then
    col=$(( ($1 - 40) / CW2 )); row=$(( ($2 - CY0 - 10) / CRH ))
    [ $col -ge 0 ] && [ $col -lt 2 ] && [ $row -ge 0 ] && [ $row -lt 2 ] || return
    idx=$(( row * 2 + col + 1 ))
  elif [ $GAL = 1 ]; then
    col=$(( ($1 - 40) / CW2 )); row=$(( ($2 - CY0) / CRH ))
    [ $col -ge 0 ] && [ $col -lt $CCOLS ] && [ $row -ge 0 ] || return
    idx=$(( row * CCOLS + col + 1 ))
  else
    col=$(( ($1 - 40) / CW2 )); row=$(( ($2 - CY0) / CRH ))
    [ $col -ge 0 ] && [ $col -lt $CCOLS ] && [ $row -ge 0 ] && [ $row -lt $CPER ] || return
    idx=$(( col * CPER + row + 1 ))
  fi
  [ $idx -le $CH_N ] || return
  nv=$(echo "$CH_OPTS" | tr ';' '\n' | sed -n "${idx}p" | cut -d'=' -f1)
  old=$(setting_value "$CH_KEY")
  [ "$nv" = "$old" ] && { VIEW=settings; return; }
  save_setting "$CH_KEY" "$nv"; eval "$CH_KEY=\"$nv\""; settings_json
  if [ "$CH_KEY" = LAYOUT ]; then             # đổi bố cục -> các phần về kiểu hợp với bố cục đó
    for k in CLOCK_STYLE EVENT_STYLE PHOTO_STYLE; do save_setting $k auto; eval "$k=auto"; done
    VIEW=main; SET_GROUP=main; MOFF=0; EVPAGE=0; return
  fi
  VIEW=settings
  if [ "$CH_KEY" = ORIENTATION ]; then
    PREV_ORIENT="$old"; REORIENT_FAIL=0; reorient "$nv"
    if [ "$REORIENT_FAIL" = 1 ]; then
      save_setting ORIENTATION "$old"; ORIENTATION=$old
      MSG_TEXT="Máy chưa xoay được màn hình sang chiều này. Đã giữ chiều cũ."; MSG_TIME=$(date +%H:%M); MSG_PREV=main; VIEW=msg; return
    fi
    VIEW=confirm; CONFIRM_DEADLINE=$(( $(date +%s) + 25 )); return
  fi
  [ "$CH_KEY" = PHOTO_MODE ] && [ "$nv" = fixed ] && [ -z "$PHOTO_FIXED" ] && { VIEW=pick; PICKPAGE=0; }
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
# ---------- Cập nhật phần mềm ----------
render_update() {
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_REFRESH" s; txt 34 18 92 "Cập nhật phần mềm" b
  txt 30 22 $(( W - 150 )) "$I_CHECK" s; txt 30 20 $(( W - 112 )) "Xong" b
  box 72 40 $(( W - 80 )) 2
  txt 28 110 40 "Bản đang dùng: $DASH_VER"
  if [ -n "$UPD_AVAIL" ]; then
    txt 34 170 40 "Có bản mới: $UPD_AVAIL" b
    txt 26 230 40 "$UPD_NOTES" "" $(( W - 80 )) 300
    cx=$(( W / 2 )); by=$(( H - 300 ))
    frame $by $(( cx - 200 )) 400 120 5
    TXTOPT="-m"; txt 44 $(( by + 32 )) 0 "CÀI ĐẶT" b; TXTOPT=""
    txt 22 $(( by + 140 )) 40 "Mất khoảng 1–2 phút. Cài đặt, link lịch và ảnh được giữ nguyên." "" $(( W - 80 )) 70
    txt 22 $(( by + 200 )) 40 "Nếu bản mới lỗi, máy tự quay lại bản cũ." "" $(( W - 80 )) 40
  else
    txt 30 180 40 "$UPD_MSG" "" $(( W - 80 )) 200
  fi
  refresh 1
}
update_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -ge $(( W - 200 )) ] && VIEW=settings; return; fi
  [ -n "$UPD_AVAIL" ] || return
  by=$(( H - 300 )); cx=$(( W / 2 ))
  if [ $1 -ge $(( cx - 220 )) ] && [ $1 -le $(( cx + 220 )) ] && [ $2 -ge $(( by - 20 )) ] && [ $2 -le $(( by + 140 )) ]; then
    log "user started update to $UPD_AVAIL"
    "$FB" -q -c -m -M -t "regular=$BOLD,px=36" "Đang cập nhật lên bản $UPD_AVAIL…" >/dev/null 2>&1
    rm -f /tmp/dash.pid
    wifi_on >/dev/null 2>&1
    HANDOVER=1                                  # giữ giao diện Kindle đóng băng cho bản mới tiếp quản
    nohup sh "$DIR/update.sh" --install --restart >> "$(dirname "$DIR")/dashboard_update.log" 2>&1 &
    exit 0
  fi
}

# ---------- Xác nhận hướng màn hình ----------
# Nút "Giữ" đặt ở góc trên-trái: nếu chạm lại rơi vào góc đối diện (dưới-phải) nghĩa là toạ độ chạm đang bị lật
# 180° -> tự sửa (lưu lại) rồi xác nhận luôn. Nhờ vậy chiều chạm ở chế độ ngang luôn đúng.
confirm_box() { CBX=40; CBY=110; CBW=$(( W / 2 - 60 )); CBH=$(( H / 2 - 150 )); [ $CBH -gt 300 ] && CBH=300; }
render_confirm() {
  left=$(( CONFIRM_DEADLINE - $(date +%s) )); [ $left -lt 0 ] && left=0
  confirm_box
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 30 40 "Màn hình đã đúng chiều chưa?" b $(( W - 80 ))
  frame $CBY $CBX $CBW $CBH 5
  txt 44 $(( CBY + CBH / 2 - 60 )) $(( CBX + 30 )) "GIỮ" b $(( CBW - 60 ))
  txt 28 $(( CBY + CBH / 2 + 4 )) $(( CBX + 30 )) "chiều này" "" $(( CBW - 60 ))
  txt 26 $(( H - 120 )) 40 "Chạm vào ô GIỮ. Không chạm: tự quay lại sau ${left} giây." "" $(( W - 80 )) 80
  refresh 1
}
confirm_tap() { # x y
  confirm_box
  if [ $1 -ge $CBX ] && [ $1 -le $(( CBX + CBW )) ] && [ $2 -ge $CBY ] && [ $2 -le $(( CBY + CBH )) ]; then
    log "orientation $ORIENTATION confirmed"; VIEW=settings; return
  fi
  mx=$(( W - 1 - $1 )); my=$(( H - 1 - $2 ))
  if [ $mx -ge $CBX ] && [ $mx -le $(( CBX + CBW )) ] && [ $my -ge $CBY ] && [ $my -le $(( CBY + CBH )) ]; then
    if [ $W -gt $H ]; then LAND_TOUCH_INVERT=$(( 1 - ${LAND_TOUCH_INVERT:-0} )); save_setting LAND_TOUCH_INVERT $LAND_TOUCH_INVERT
    else PORT_TOUCH_INVERT=$(( 1 - ${PORT_TOUCH_INVERT:-0} )); save_setting PORT_TOUCH_INVERT $PORT_TOUCH_INVERT; fi
    log "chạm đang bị lật 180° -> đã tự sửa; orientation $ORIENTATION confirmed"; VIEW=settings
  fi
}
# Hiệu chỉnh cảm ứng: chạm 1 lần vào ô góc trên trái. Chạm rơi vào chỗ đối xứng qua tâm -> lật cảm ứng 180°.
render_calib() {
  confirm_box
  "$FB" -q -b -k >/dev/null 2>&1
  frame $CBY $CBX $CBW $CBH 6
  txt 44 $(( CBY + CBH / 2 - 60 )) $(( CBX + 30 )) "CHẠM" b $(( CBW - 60 ))
  txt 28 $(( CBY + CBH / 2 + 4 )) $(( CBX + 30 )) "vào ô này" "" $(( CBW - 60 ))
  txt 30 30 40 "Hiệu chỉnh cảm ứng" b $(( W - 80 ))
  txt 26 $(( H - 200 )) 40 "Chạm vào ô có viền đậm ở góc trên bên trái, đúng chỗ bạn nhìn thấy. Kindle sẽ tự chỉnh hướng cảm ứng cho khớp màn hình." "" $(( W - 80 )) 150
  refresh 1
}
calib_tap() { # x y
  confirm_box
  if [ $1 -ge $CBX ] && [ $1 -le $(( CBX + CBW )) ] && [ $2 -ge $CBY ] && [ $2 -le $(( CBY + CBH )) ]; then
    log "hiệu chỉnh cảm ứng: đã khớp"; VIEW=main; return; fi
  mx=$(( W - 1 - $1 )); my=$(( H - 1 - $2 ))
  if [ $mx -ge $CBX ] && [ $mx -le $(( CBX + CBW )) ] && [ $my -ge $CBY ] && [ $my -le $(( CBY + CBH )) ]; then
    if [ $W -gt $H ]; then LAND_TOUCH_INVERT=$(( 1 - ${LAND_TOUCH_INVERT:-0} )); save_setting LAND_TOUCH_INVERT $LAND_TOUCH_INVERT
    else PORT_TOUCH_INVERT=$(( 1 - ${PORT_TOUCH_INVERT:-0} )); save_setting PORT_TOUCH_INVERT $PORT_TOUCH_INVERT; fi
    log "hiệu chỉnh cảm ứng: chạm bị lật 180° -> đã sửa"; VIEW=main; return
  fi
  log "hiệu chỉnh cảm ứng: chạm ngoài ô ($1,$2), chờ chạm lại"
}
confirm_check() { # hết giờ mà chưa xác nhận -> quay lại hướng cũ
  [ "$VIEW" = confirm ] || return 1
  [ $(date +%s) -ge $CONFIRM_DEADLINE ] || return 1
  log "orientation $ORIENTATION not confirmed -> back to ${PREV_ORIENT:-doc}"
  ORIENTATION="${PREV_ORIENT:-doc}"; save_setting ORIENTATION "$ORIENTATION"
  reorient "$ORIENTATION"; VIEW=settings
  return 0
}

draw() {
  if [ -n "$SERVER_URL" ]; then render_server "$1"; return; fi
  case "$VIEW" in
    photo) render_photo ;; settings) render_settings ;; pick) render_pick ;; confirm) render_confirm ;; calib) render_calib ;; update) render_update ;; choose) render_choose ;;
    reader) render_reader ;; status) render_status ;; stpick) render_stpick ;;
    diag) render_diag ;; remote) render_remote ;; msg) render_msg ;; recv) render_recv ;;
    *) case "$PAGE" in tin) render_tin "$1" ;; bloc) render_bloc "$1" ;; dem) render_dem "$1" ;; pomo) render_pomo "$1" ;; news) render_news "$1" ;; *) render_main "$1" ;; esac ;;
  esac
}

# ---------- Chạm ----------
go_home() {
  log "go home ($1)"
  touch /tmp/dash_stop; rm -f /tmp/dash.pid          # báo bộ đọc cảm ứng dừng hẳn
  msg="Đang về Home…"; fw_paused || msg="Đang về Home… (chờ khoảng 30 giây)"
  "$FB" -q -c -m -M -t "regular=$BOLD,px=44" "$msg" >/dev/null 2>&1
  pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
  log_trim
  remote_stop
  fw_resume; HANDOVER=1
  pkill -f "$DIR/touch.sh" 2>/dev/null; pkill -f "dd if=/dev/input" 2>/dev/null
  rm -f /tmp/dash.pid
  restore_lock_bg
  exit 0
}
restore_lock_bg() { # trả khoá xoay về như lúc bắt đầu, sau khi giao diện Kindle đã chạy lại
  o=$(cat /tmp/dash_lock_orig 2>/dev/null); [ -n "$o" ] || o=U
  [ "$LOCK_NOW" = "$o" ] && return 0
  ( i=0; while [ $i -lt 120 ]; do
      if [ -n "$(lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null)" ]; then
        sleep 2; lipc-set-prop com.lab126.winmgr orientationLock "$o" 2>/dev/null; exit 0; fi
      sleep 1; i=$((i + 1)); done ) >/dev/null 2>&1 &
}

to_view() { # toạ độ cảm ứng (luôn theo chiều dọc gốc) -> toạ độ theo hướng đang hiển thị
  px=$1; py=$2; VX=$px; VY=$py
  tl=${TOUCH_LOCK:-$LOCK_NOW}
  case "$tl" in
    D) VX=$(( 757 - px )); VY=$(( 1023 - py )) ;;
    L|R)
      a=1; [ "$tl" = L ] && a=3; [ "$LAND_TOUCH_INVERT" = 1 ] && a=$(( 4 - a ))
      if [ $a = 1 ]; then VX=$py; VY=$(( 757 - px )); else VX=$(( 1023 - py )); VY=$px; fi ;;
  esac
  case "$tl" in U|D) [ "${PORT_TOUCH_INVERT:-0}" = 1 ] && { VX=$(( 757 - VX )); VY=$(( 1023 - VY )); } ;; esac
}

handle_tap() {
  to_view "$1" "$2"; x=$VX; y=$VY
  LAST_TOUCH=$(date +%s); LAST_ACT=$LAST_TOUCH; NOWE=$LAST_TOUCH; stat_tap
  log "tap ($x,$y) view=$VIEW"
  case "$VIEW" in
    reader) reader_tap $x $y; return ;;
    status) status_tap $x $y; return ;;
    diag) diag_tap $x $y; return ;; remote) remote_tap $x $y; return ;; msg) msg_tap $x $y; return ;; recv) recv_tap $x $y; return ;;
    stpick) stpick_tap $x $y; return ;;
    choose) choose_tap $x $y; return ;;
    update) update_tap $x $y; return ;;
    confirm) confirm_tap $x $y; return ;;
    calib) calib_tap $x $y; return ;;
    settings) settings_tap $x $y; return ;;
    pick) pick_tap $x $y; return ;;
    photo)
      if [ $y -lt 150 ]; then VIEW=main
      elif [ $x -lt $(( W / 2 )) ]; then PHOFF=$((PHOFF - 1)); else PHOFF=$((PHOFF + 1)); fi
      return ;;
  esac

  if [ "$PAGE" != main ]; then
    if [ $y -le 70 ]; then page_header_tap $x; return; fi
    CY_TAP=$y
    case "$PAGE" in
      pomo) pomo_tap $x $y ;;
      news) news_list_tap ;;
      tin) set -- $NEWS_CARD; [ -n "$1" ] && [ $y -ge $1 ] && [ $y -le $(( $1 + $4 )) ] && open_reader "$5" ;;
    esac
    return
  fi
  set_layout; CAL_TH=46
  if layout_active; then lay_setup; [ "$LAYOUT" = lich ] && CAL_TH=120; fi
  if [ $y -le 80 ]; then
    if [ $x -ge $(( B_HOME - 14 )) ]; then go_home "tap Home"
    elif [ $x -ge $(( B_GEAR - 14 )) ]; then VIEW=settings
    elif [ $x -ge $(( B_PAGE - 14 )) ]; then page_next 1
    elif [ $x -ge $(( B_LIGHT - 14 )) ]; then light_cycle
    elif [ $x -ge $(( B_STATUS - 24 )) ]; then VIEW=stpick
    fi
    log "toolbar x=$x (trạng thái $B_STATUS, đèn $B_LIGHT) -> view=$VIEW lock=$LOCK_NOW ${W}x${H}"
    return
  fi
  if [ $x -ge $CX ] && [ $x -le $CAL_X2 ] && [ $y -ge $CAL_Y ] && [ $y -le $CAL_Y2 ]; then
    if [ $y -lt $(( CAL_Y + CAL_TH )) ]; then MOFF=0
    elif [ $x -lt $(( (CX + CAL_X2) / 2 )) ]; then MOFF=$((MOFF - 1)); else MOFF=$((MOFF + 1)); fi
    return
  fi
  PHOTO=$(pick_photo "$PH_DIR")
  if [ -n "$PHOTO" ] && [ $x -ge $PH_X ] && [ $y -ge $PH_Y ] && [ $x -le $(( PH_X + PH_W )) ] && [ $y -le $(( PH_Y + PH_H )) ]; then
    VIEW=photo; return
  fi
  if [ $x -ge $EV_X ] && [ $y -ge $EV_Y ] && [ $y -le $EV_Y2 ]; then EVPAGE=$((EVPAGE + 1)); return; fi
  if [ $y -ge $CLK_Y ] && [ $y -le $(( CLK_Y + CLK_H )) ] && [ $x -ge $CLK_X ] && [ $x -le $(( CLK_X + CLK_W )) ]; then
    if layout_active; then cl="auto=;mong=;dam=;mono=;lat=;kimtg=;vong=;chu=;so12=;so24=;kim="; else cl="so24=;so12=;kim=;chu=;mong=;dam=;mono=;lat=;kimtg=;vong="; fi
    nv=$(setting_next CLOCK_STYLE "$cl"); CLOCK_STYLE=$nv; save_setting CLOCK_STYLE "$nv"
  fi
}

idle_reset() {
  [ $LAST_TOUCH = 0 ] && return
  case "$VIEW" in status) return ;; esac
  lim=$IDLE_RESET_MIN; [ "$VIEW" = reader ] && lim=15
  [ $(( $(date +%s) - LAST_TOUCH )) -ge $(( lim * 60 )) ] || return
  MOFF=0; EVPAGE=0; LAST_TOUCH=0; [ "$VIEW" != main ] && VIEW=main; LAST_KEY=""
}

# Giao diện Kindle đôi khi tự bật lại phía dưới -> tắt lại, nếu không nó cũng nhận chạm (hiện "Application Error")
ensure_fw_stopped() {      # chế độ nhanh: chỉ đọc /proc, không tốn tiến trình
  fw_check || return 1
  log "framework came back -> paused/stopped again"
  sleep 1
  lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
  return 0
}

process_taps() {
  fwb=0; ensure_fw_stopped && fwb=1
  [ -s "$TAPQ" ] || return $(( 1 - fwb ))
  mv "$TAPQ" "$TAPQ.work" 2>/dev/null || return 1
  while read -r tx ty sx1 sy1 sx2; do
    if [ "$tx" = S ]; then handle_swipe "$ty" "$sx1" "$sy1" "$sx2"
    elif [ "$tx" = C ]; then handle_cmd "$ty" "$sx1" "$sy1"
    elif [ -n "$ty" ]; then handle_tap "$tx" "$ty"; fi
  done < "$TAPQ.work"
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
rm -f /tmp/dash_stop
echo $$ > /tmp/dash.pid
rm -f "$TAPQ"
if [ -f "$DIR/start_view" ]; then sv=$(cat "$DIR/start_view"); rm -f "$DIR/start_view"
  case "$sv" in stpick) VIEW=stpick ;; ?*) status_name "$sv" >/dev/null && [ -n "$(status_name "$sv")" ] && status_enter "$sv" ;; esac
fi
if is_night; then NIGHT_WAS=1; else NIGHT_WAS=0; fi
trap 'WOKE=1' USR1
# Thoát vì bất kỳ lý do gì (lỗi, bị dừng) -> luôn trả lại giao diện Kindle đầy đủ (trừ khi giao cho bản cập nhật)
trap 'dash_exit' EXIT
trap 'exit 0' TERM INT
# hướng màn hình + đóng băng giao diện Kindle đã làm ở phần khởi động nhanh phía trên
LOCK_ORIG=$(cat /tmp/dash_lock_orig 2>/dev/null); [ -n "$LOCK_ORIG" ] || LOCK_ORIG=U
LOCK_NOW=$(cat /tmp/dash_lock_now 2>/dev/null); [ -n "$LOCK_NOW" ] || LOCK_NOW=$LOCK_ORIG
if [ "$EARLY" = takeover ]; then log "framework still paused -> take over (lock $LOCK_NOW)"
elif fw_paused; then log "framework paused (pid $(cat "$FW_FLAG"))"; else log "framework stopped"; fi
log "orientation $ORIENTATION: lock $LOCK_ORIG -> $LOCK_NOW"
log "fb rotate at start: $(cat "$ROTF" 2>/dev/null)"
fb_geom
pkill -f "$DIR/touch.sh" 2>/dev/null
sh "$DIR/touch.sh" >> "$DIR/dash.log" 2>&1 &
pkill -f "$DIR/lib/watchdog.sh" 2>/dev/null
DIR="$DIR" sh "$DIR/lib/watchdog.sh" $$ >> "$DIR/dash.log" 2>&1 &     # tự trả lại giao diện Kindle nếu dashboard kẹt
remote_init
# Bỏ viền hoa văn trang trí (một lần, theo yêu cầu): vẫn bật lại được trong Cài đặt > Giao diện
[ -f "$DIR/.mig_noorn" ] || { save_setting ORNAMENT 0; ORNAMENT=0; touch "$DIR/.mig_noorn"; }
# Tự kiểm tra: màn hình phải đúng chiều đã chọn (vd sau khi cập nhật, Kindle lỡ xoay lại) -> xoay lại cho khớp
if [ "$PENDING_ORIENT" != 1 ] && [ -n "$TOUCH_LOCK" ] && [ "$TOUCH_LOCK" != "$(lock_for "$ORIENTATION")" ]; then
  case "$ORIENTATION$TOUCH_LOCK" in ngang*L|ngang*R) ;; *)
    log "khởi động: màn hình đang $TOUCH_LOCK, cài đặt $ORIENTATION -> xoay lại"; PENDING_ORIENT=1 ;; esac
fi
if [ "$PENDING_ORIENT" = 1 ]; then
  log "khởi động: chưa xoay được sang $ORIENTATION -> thử cách khác"
  reorient "$ORIENTATION"
  if [ "$REORIENT_FAIL" = 1 ]; then
    save_setting ORIENTATION doc; ORIENTATION=doc; reorient doc
    echo "Máy chưa xoay được màn hình sang chiều đã chọn — đã giữ chiều dọc." > /tmp/dash_notice
  fi
fi
if [ -s /tmp/dash_notice ]; then MSG_TEXT=$(cat /tmp/dash_notice); rm -f /tmp/dash_notice; MSG_TIME=$(date +%H:%M); MSG_PREV=main; VIEW=msg; fi

# Yêu cầu hiệu chỉnh cảm ứng (từ "Dashboard - Sua xoay cham")
[ -f "$DIR/.calib_req" ] && { rm -f "$DIR/.calib_req"; VIEW=calib; log "mở hiệu chỉnh cảm ứng"; }
TAPPED=1
LAST_ACT=$(date +%s)
while true; do
  set -- $(date '+%Y%m%d%H %M %S %s'); NOW_YMDH=$1; mnow=${2#0}; NOW_SEC=${3#0}; NOWE=$4
  echo $(( NOWE + ${WD_WORK:-600} )) > /tmp/dash_alive    # còn sống; vòng này (tải dữ liệu, vẽ…) phải xong trong 10 phút
  LOOPN=$(( ${LOOPN:-0} + 1 ))
  b=""; if [ $(( LOOPN % 5 )) = 1 ]; then b=$(battery); CHARGING=0; is_charging && CHARGING=1; [ -n "$b" ] && BATT_B=$b; fi   # pin: mỗi 5 vòng
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    "$FB" -q -c -m -M -t "regular=$BOLD,px=40" "PIN YẾU – HÃY SẠC KINDLE ($b%)" >/dev/null 2>&1 \
      || { eips -c; eips 10 20 "PIN YEU - HAY SAC KINDLE ($b%)"; }
    log "low battery, stopping"; exit 0
  fi
  confirm_check && TAPPED=1
  [ $(( LOOPN % 3 )) = 1 ] && ensure_fw_stopped && TAPPED=1   # chạm nào cũng kiểm tra lại, ở đây chỉ cần thưa
  # Lần vẽ đầu tiên: vẽ ngay bằng dữ liệu đã có (không chờ bật Wi-Fi + tải), tải mới ngay sau đó
  if [ "${FIRSTDRAW:-1}" = 1 ]; then FIRSTDRAW=0; QUICKNEXT=1; data_sig; log "vẽ ngay, tải dữ liệu sau"
  else [ "$VIEW" = confirm ] || [ -n "$SERVER_URL" ] || { log "data: update"; update_data; log "data: done"; }; fi
  idle_reset
  pomo_tick && TAPPED=1
  batt_log
  recv_check && TAPPED=1
  sched_tick && TAPPED=1
  [ $(( LOOPN % 60 )) = 0 ] && log_trim
  if [ "$WIFI_USED" = 1 ] && [ "$VIEW" != reader ] && [ "$VIEW" != update ]; then WIFI_USED=0; wifi_save; fi
  [ "$VIEW" = main ] && auto_page
  set_light
  # Chỉ vẽ lại toàn màn hình khi NỘI DUNG thật sự đổi (thời tiết, lịch, ngày, ảnh, pin, trang…) hoặc có chạm;
  # còn lại chỉ vẽ lại ô đồng hồ. Màn hình phụ (Cài đặt, lời nhắn…) chỉ vẽ lại khi chạm.
  key=$(screen_sig)
  case "$PAGE" in tin|news) key="$key.$(( mnow / NEWS_ROTATE_MIN ))" ;; pomo) pomo_running && key="$key.$mnow" ;; esac
  CLEAN_NOW=0; [ "$VIEW" = main ] && clean_due && CLEAN_NOW=1
  if [ "$VIEW" = status ]; then
    key=$(status_key)
    if [ $TAPPED = 1 ] || [ "$key" != "$LAST_KEY" ]; then
      { [ $TAPPED = 0 ] && [ "$LAST_VIEW" = status ] && [ "${DIFF_REFRESH:-1}" = 1 ] && diff_draw; } || draw 0
      LAST_KEY="$key"; LAST_VIEW=$VIEW; [ -z "$DRAWN" ] && { DRAWN=1; log "first draw ok"; rm -f "$DIR/.boot_try"; }; else status_tick; fi
  elif [ "$VIEW" != main ] && [ $TAPPED = 0 ] && [ "$VIEW" = "$LAST_VIEW" ] && [ "$VIEW" != confirm ]; then
    :                                                      # màn hình phụ, không chạm: giữ nguyên, không quét
  elif [ "$VIEW" != main ] || [ $TAPPED = 1 ] || [ "$key" != "$LAST_KEY" ] || [ "$PAGE" != "$LAST_PAGE" ] || [ $CLEAN_NOW = 1 ] || [ -n "$SERVER_URL" ]; then
    [ "$key" != "$LAST_KEY" ] && [ $TAPPED = 0 ] && [ -n "$LAST_KEY" ] && log "nội dung đổi -> vẽ lại"
    LAST_PAGE="$PAGE"
    full=0; [ -z "$LAST_KEY" ] && full=1                    # lần vẽ đầu: nháy sạch 1 lần
    [ $CLEAN_NOW = 1 ] && { full=1; log "nháy sạch định kỳ"; }
    [ $full = 1 ] && CLEAN_AT=$NOWE
    if [ $full = 0 ] && [ $TAPPED = 0 ] && [ "$VIEW" = "$LAST_VIEW" ] && [ "${DIFF_REFRESH:-1}" = 1 ] && [ -z "$SERVER_URL" ] && [ -n "$FB_STRIDE" ] && { update_clock; diff_draw; }; then :   # giờ vẽ sạch trước (xoá trắng rồi vẽ), vùng khác chỉ quét chỗ đổi
    else draw $full; fi
    LAST_KEY="$key"; stat_full; LAST_VIEW=$VIEW
    [ "$VIEW" = main ] && ev_soon
    [ -z "$DRAWN" ] && { DRAWN=1; log "first draw ok"; rm -f "$DIR/.boot_try"; }
  else
    update_clock; stat_part; LAST_VIEW=$VIEW
  fi
  TAPPED=0; DATA_CHANGED=0
  every=$REFRESH_MIN; is_night && every=$REFRESH_NIGHT_MIN
  s=$(date +%S); s=${s#0}; [ -z "$s" ] && s=0; secs=$(( every * 60 - s )); [ "$VIEW" = confirm ] && secs=5
  pc=$(pomo_sleep_cap); [ $pc -lt $secs ] && secs=$pc
  pomo_running && [ $secs -gt 60 ] && secs=60
  [ "$QUICKNEXT" = 1 ] && { QUICKNEXT=0; secs=1; }          # vừa vẽ lần đầu -> tải dữ liệu ngay
  remote_state
  if deep_want; then deep_cycle; TAPPED=1; DATA_CHANGED=1; continue; fi   # ngủ sâu ban đêm (nếu bật)
  echo $(( $(date +%s) + secs + ${WD_SLEEP:-300} )) > /tmp/dash_alive  # sắp ngủ $secs giây
  sleep $secs & SP=$!
  while :; do
    process_taps && { TAPPED=1; kill $SP 2>/dev/null; break; }
    wait $SP 2>/dev/null && break
    kill -0 $SP 2>/dev/null || { process_taps && TAPPED=1; break; }
  done
  wait $SP 2>/dev/null
done
