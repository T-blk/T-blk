# Ngủ sâu ban đêm: cho Kindle "suspend" thật (gần như không tốn pin), hẹn đồng hồ RTC đánh thức mỗi N phút
# để cập nhật giờ/thời tiết; bấm nút nguồn để dậy ngay. Mặc định TẮT — hãy dùng "Thử ngủ sâu 1 phút" trước.
# Tự tắt nếu máy không hỗ trợ (không ngủ được, hoặc RTC không đánh thức được).
: "${DEEP_SLEEP:=0}" "${DEEP_SLEEP_MIN:=30}"
RTC=/sys/class/rtc/rtc0
DS_OFF=""                      # lý do đã tự tắt trong phiên này

deep_supported() { [ -w /sys/power/state ] && [ -w "$RTC/wakealarm" ] && grep -q mem /sys/power/state 2>/dev/null; }

# deep_sleep GIÂY -> DS_SLEPT (giây đã ngủ), DS_RESULT ok|early|nosleep|nowake
deep_sleep() {
  n=$1; DS_RESULT=nosleep; DS_SLEPT=0
  deep_supported || { DS_RESULT=nosupport; return 1; }
  l0=$(lipc-get-prop com.lab126.powerd flIntensity 2>/dev/null)
  lipc-set-prop com.lab126.powerd flIntensity 0 2>/dev/null
  lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null
  echo 0 > "$RTC/wakealarm" 2>/dev/null
  if ! echo "+$n" > "$RTC/wakealarm" 2>/dev/null; then
    echo "$(( $(cat "$RTC/since_epoch" 2>/dev/null || date +%s) + n ))" > "$RTC/wakealarm" 2>/dev/null || { DS_RESULT=nosupport; return 1; }
  fi
  touch /tmp/dash_sleeping
  log "ngủ sâu $n giây"; sync
  t0=$(date +%s)
  echo mem > /sys/power/state 2>/dev/null
  t1=$(date +%s)
  date +%s > /tmp/dash_woke; rm -f /tmp/dash_sleeping
  echo 0 > "$RTC/wakealarm" 2>/dev/null
  [ -n "$l0" ] && lipc-set-prop com.lab126.powerd flIntensity "$l0" 2>/dev/null; LIGHT_NOW=""
  DS_SLEPT=$(( t1 - t0 ))
  if [ $DS_SLEPT -lt 5 ]; then DS_RESULT=nosleep
  elif [ $DS_SLEPT -gt $(( n + 600 )) ]; then DS_RESULT=nowake        # RTC không đánh thức, phải bấm nút nguồn
  elif [ $DS_SLEPT -lt $(( n - 30 )) ]; then DS_RESULT=early           # bấm nút nguồn để dậy sớm
  else DS_RESULT=ok; fi
  ST_SLEEP=$(( ${ST_SLEEP:-0} + DS_SLEPT ))
  log "dậy sau $DS_SLEPT giây ($DS_RESULT)"
  NEXT_DATA=0
  [ $DS_RESULT = ok ] || [ $DS_RESULT = early ]
}

# Có nên ngủ sâu ở vòng này không?
deep_want() {
  [ "$DEEP_SLEEP" = 1 ] && [ -z "$DS_OFF" ] || return 1
  is_night || return 1
  [ "$CHARGING" = 1 ] && return 1                     # đang sạc thì khỏi
  [ "$REMOTE" = 1 ] && return 1                       # đang nghe lệnh điện thoại
  pomo_running && return 1
  case "$VIEW" in main|status) ;; *) return 1 ;; esac
  [ $(( ${NOWE:-0} - ${LAST_ACT:-0} )) -ge 180 ]          # 3 phút không chạm
}

deep_cycle() { # vẽ dòng báo, ngủ, xử lý kết quả. Trả 0 nếu đã ngủ.
  n=$(( DEEP_SLEEP_MIN * 60 - $(date +%S | sed 's/^0//;s/^$/0/') ))
  wk=$(date -d "@$(( $(date +%s) + n ))" +%H:%M 2>/dev/null)
  rect 0 $(( H - 40 )) $W 40 WHITE
  tx reg 18 $(( W / 2 )) $(( H - 34 )) "Đang ngủ sâu tiết kiệm pin${wk:+ · tự dậy lúc $wk} · bấm nút nguồn để dậy" c s
  refresh 0 "top=$(( H - 40 )),left=0,width=$W,height=40"
  deep_sleep $n
  case "$DS_RESULT" in
    nosleep|nosupport) DS_OFF="máy không vào được chế độ ngủ"; log "ngủ sâu: tự tắt ($DS_OFF)" ;;
    nowake) DS_OFF="đồng hồ hẹn giờ không đánh thức được máy"; DEEP_SLEEP=0; save_setting DEEP_SLEEP 0; log "ngủ sâu: tự tắt ($DS_OFF)" ;;
    early) LAST_ACT=$(date +%s) ;;                    # người dùng bấm nút nguồn: thức ít nhất 3 phút
  esac
  return 0
}

deep_test() { # nút "Thử ngủ sâu 1 phút" trong Cài đặt
  "$FB" -q -c -m -M -t "regular=$BOLD,px=34" "Thử ngủ sâu 60 giây…
Đừng bấm gì, máy sẽ tự dậy." >/dev/null 2>&1
  if ! deep_supported; then MSG_TEXT="Máy này không hỗ trợ ngủ sâu (thiếu /sys/power/state hoặc đồng hồ RTC)."
  else
    deep_sleep 60
    case "$DS_RESULT" in
      ok) MSG_TEXT="Ngủ sâu chạy tốt: máy đã ngủ $DS_SLEPT giây và tự dậy. Có thể bật \"Ngủ sâu ban đêm\"." ;;
      early) MSG_TEXT="Máy ngủ được nhưng dậy sớm ($DS_SLEPT giây) — có thể do bấm nút nguồn. Thử lại không bấm gì." ;;
      nowake) MSG_TEXT="Máy ngủ được nhưng KHÔNG tự dậy (phải bấm nút nguồn). Đừng bật ngủ sâu trên máy này." ;;
      *) MSG_TEXT="Máy không vào được chế độ ngủ ($DS_SLEPT giây). Đừng bật ngủ sâu trên máy này." ;;
    esac
  fi
  log "thử ngủ sâu: $MSG_TEXT"
  MSG_TIME=$(date +%H:%M); MSG_PREV=main; VIEW=msg
}
