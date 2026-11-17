# Tự đổi giao diện / trạng thái theo giờ + tự bật "Đang họp" khi lịch Apple có cuộc họp.
# SCHEDULE = 0 | lamviec | hoctap | giadinh | tuychinh (đọc dashboard/lich-giao-dien.txt)
# Mỗi dòng: NGÀY GIỜ:PHÚT VIỆC [THAM SỐ]
#   NGÀY : *  |  T2-T6  |  T7,CN  |  T2,T4,T6 ...
#   VIỆC : layout <codien|toigian|thuysi|the|anh|chu|lich>  ·  page <main|tin|bloc|dem|pomo|news>
#          status <taptrung|hop|goidien|roidi|toilet|cafe|antrua|ngutrua|vengay>  ·  back (thoát trạng thái)
# Chỉ chạy đúng lúc đến giờ; bạn đổi tay thì giữ nguyên tới mốc kế tiếp.

SCHED_FILE="$DIR/lich-giao-dien.txt"
SCHED_LAST=""            # "YYYYMMDD HHMM" mốc đã xử lý gần nhất
AM_KEY=""; ST_AUTO=0; ST_AUTO_END=0

sched_preset() {
  case "$1" in
    lamviec) cat <<'EOT'
T2-T6 06:00 layout toigian
T2-T6 08:30 layout the
T2-T6 12:00 status antrua
T2-T6 13:00 back
T2-T6 17:30 status vengay
T2-T6 19:00 back
* 19:00 layout lich
T7,CN 07:00 layout anh
EOT
    ;;
    hoctap) cat <<'EOT'
* 06:30 layout toigian
T2-T6 07:30 layout lich
T2-T6 19:30 status taptrung
T2-T6 21:30 back
* 21:30 layout chu
EOT
    ;;
    giadinh) cat <<'EOT'
* 06:00 layout anh
* 12:00 layout the
* 18:00 layout anh
* 21:00 layout chu
EOT
    ;;
    tuychinh)
      if [ ! -f "$SCHED_FILE" ]; then
        { echo "# Lịch tự đổi giao diện — sửa file này rồi chọn \"Tuỳ chỉnh\" trong Cài đặt."
          echo "# NGÀY GIỜ VIỆC THAM_SỐ   (NGÀY: * | T2-T6 | T7,CN)   VIỆC: layout | page | status | back"
          sched_preset lamviec; } > "$SCHED_FILE"
      fi
      grep -v '^[[:space:]]*#' "$SCHED_FILE" | sed '/^[[:space:]]*$/d' ;;
  esac
}

day_match() { # "T2-T6" WDAY(0=CN, 1=T2 ... 6=T7)
  [ "$1" = "*" ] && return 0
  _w=$(( $2 + 1 )); [ $_w = 1 ] && _w=8            # T2=2 ... T7=7, CN=8
  _o=$IFS; IFS=','; set -- $1; IFS=$_o
  for _pt in "$@"; do
    case "$_pt" in
      *-*) _a=${_pt%-*}; _b=${_pt#*-}; _a=${_a#T}; _b=${_b#T}; [ "$_a" = CN ] && _a=8; [ "$_b" = CN ] && _b=8
           [ $_w -ge $_a ] && [ $_w -le $_b ] && return 0 ;;
      CN) [ $_w = 8 ] && return 0 ;;
      T*) [ "${_pt#T}" = $_w ] && return 0 ;;
    esac
  done
  return 1
}

sched_do() { # việc tham_số
  log "lịch: $1 $2"
  case "$1" in
    layout) case "$2" in codien|toigian|thuysi|the|anh|chu|lich) LAYOUT=$2; MOFF=0; EVPAGE=0; [ "$VIEW" = main ] && PAGE=main ;; esac ;;
    page) PAGE=$2 ;;
    status) case "$VIEW" in main|status) [ -n "$(status_name "$2")" ] && status_enter "$2" ;; esac ;;
    back) [ "$VIEW" = status ] && status_exit ;;
  esac
  SCHED_HIT=1
}

# Gọi mỗi vòng lặp. Trả 0 nếu có thay đổi (cần vẽ lại).
sched_tick() {
  SCHED_HIT=0
  [ -n "$SCHEDULE" ] && [ "$SCHEDULE" != 0 ] || { sched_meet; return $?; }
  set -- $(date '+%Y%m%d %H%M %w'); today=$1; now=$2; wd=$3
  if [ -z "$SCHED_LAST" ]; then
    # mới bật: chỉ áp dụng bố cục của mốc gần nhất (không bật trạng thái cũ)
    l=$(sched_preset "$SCHEDULE" | while read -r d t a p; do tt=$(echo "$t" | tr -d ':')
          day_match "$d" "$wd" && [ "$tt" -le "$now" ] && [ "$a" = layout ] && echo "$p"; done | tail -1)
    [ -n "$l" ] && sched_do layout "$l"
    SCHED_LAST="$today $now"; sched_meet; return 0
  fi
  last_day=${SCHED_LAST% *}; last=${SCHED_LAST#* }
  [ "$last_day" = "$today" ] || last=-1
  if [ "$now" != "$last" ]; then
    # chạy mọi mốc trong khoảng (last, now] — kể cả khi máy ngủ sâu bỏ lỡ vài phút
    # lịch đã tính sẵn (giờ dạng số) — chỉ đọc lại khi đổi lựa chọn hoặc file tuỳ chỉnh thay đổi
    sk="$SCHEDULE.$(date -r "$SCHED_FILE" +%s 2>/dev/null)"
    [ "$sk" = "$SCHED_KEY" ] && [ -s /tmp/dash_sched.txt ] || {
      sched_preset "$SCHEDULE" | awk '{ t = $2; gsub(":", "", t); $2 = t + 0; print }' > /tmp/dash_sched.txt; SCHED_KEY=$sk; }
    lastn=-1; [ "$last" != -1 ] && lastn=$(( 1$last - 10000 )); nown=$(( 1$now - 10000 ))
    while read -r d tt a p; do
      [ $tt -gt $lastn ] && [ $tt -le $nown ] && day_match "$d" "$wd" && sched_do "$a" "$p"
    done < /tmp/dash_sched.txt
    SCHED_LAST="$today $now"
  fi
  sched_meet
  [ $SCHED_HIT = 1 ]
}

# Tự bật "Đang họp" khi đang có sự kiện có chữ họp / meeting / call / zoom / teams
sched_meet() {
  [ "$AUTO_MEET" = 1 ] || return 1
  [ -s "$EV" ] || return 1
  set -- $(date '+%H %M'); NOWMIN=$(( 1$1 % 100 * 60 + 1$2 % 100 ))
  if [ "$VIEW" = status ] && [ $ST_AUTO = 1 ]; then
    [ $NOWMIN -ge $ST_AUTO_END ] && { log "họp xong -> thoát trạng thái"; status_exit; ST_AUTO=0; SCHED_HIT=1; return 0; }
    return 1
  fi
  [ "$VIEW" = status ] || ST_AUTO=0
  [ "$VIEW" = main ] || return 1
  m=$(awk -F'|' -v TD="$TD" -v N="$NOWMIN" '{ split($1, k, ":"); s = tolower($6)
      if ($2 == TD && $4 == 0 && $3 <= N && $3 + k[2] > N && s ~ /họp|hop |meeting|meet|call|zoom|teams|phỏng vấn|interview/) { print $1 "|" $3 + k[2]; exit } }' "$EV")
  [ -n "$m" ] || return 1
  [ "${m%|*}" = "$AM_KEY" ] && return 1          # bạn đã tự thoát cuộc họp này rồi
  AM_KEY=${m%|*}; ST_AUTO_END=${m#*|}
  log "lịch có cuộc họp -> Đang họp tới $(printf '%02d:%02d' $(( ST_AUTO_END / 60 )) $(( ST_AUTO_END % 60 )))"
  status_enter hop; ST_AUTO=1; SCHED_HIT=1
  return 0
}
