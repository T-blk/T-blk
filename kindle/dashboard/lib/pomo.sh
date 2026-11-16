# Đồng hồ Pomodoro cho Kindle Dashboard (được dash.sh nạp).
# Tập trung POMO_FOCUS phút -> nghỉ POMO_BREAK phút; cứ POMO_LONG_EVERY phiên thì nghỉ dài POMO_LONG phút.
# Hết giờ: nháy màn hình + nháy đèn nền (PW2 không có loa).

: "${POMO_FOCUS:=25}" "${POMO_BREAK:=5}" "${POMO_LONG:=15}" "${POMO_LONG_EVERY:=4}"
POMO_STATE=idle       # idle | focus | break | paused | done_focus | done_break
POMO_KIND=focus       # loại phiên đang chạy hoặc tạm dừng: focus | break | long
POMO_END=0; POMO_LEFT=0; POMO_TOTAL=0
POMO_DAY=""; POMO_COUNT=0; POMO_MIN_TODAY=0

pomo_active() { case "$POMO_STATE" in focus|break|paused|done_focus|done_break) return 0 ;; esac; return 1; }
pomo_running() { [ "$POMO_STATE" = focus ] || [ "$POMO_STATE" = break ]; }
pomo_today() { d=$(date +%Y%m%d); [ "$d" != "$POMO_DAY" ] && { POMO_DAY=$d; POMO_COUNT=0; POMO_MIN_TODAY=0; }; }

pomo_start() { # $1 = focus | break | long
  pomo_today
  POMO_KIND=$1
  case "$1" in focus) mins=$POMO_FOCUS; POMO_STATE=focus ;; long) mins=$POMO_LONG; POMO_STATE=break ;; *) mins=$POMO_BREAK; POMO_STATE=break ;; esac
  POMO_TOTAL=$(( mins * 60 )); POMO_END=$(( $(date +%s) + POMO_TOTAL ))
  log "pomodoro: start $1 ($mins min)"
}
pomo_pause() { POMO_LEFT=$(( POMO_END - $(date +%s) )); [ $POMO_LEFT -lt 0 ] && POMO_LEFT=0; POMO_STATE=paused; }
pomo_resume() {
  POMO_END=$(( $(date +%s) + POMO_LEFT ))
  if [ "$POMO_KIND" = focus ]; then POMO_STATE=focus; else POMO_STATE=break; fi
}
pomo_stop() { POMO_STATE=idle; POMO_KIND=focus; log "pomodoro: stop"; }
pomo_left() { # giây còn lại
  case "$POMO_STATE" in paused) echo $POMO_LEFT ;; focus|break) l=$(( POMO_END - $(date +%s) )); [ $l -lt 0 ] && l=0; echo $l ;; *) echo 0 ;; esac
}

pomo_alert() { # $1 = dòng chữ lớn ; $2 = dòng nhỏ
  l0=$(lipc-get-prop com.lab126.powerd flIntensity 2>/dev/null)
  k=0
  while [ $k -lt 3 ]; do
    "$FB" -q -c -f -m -M -t "regular=$BOLD,px=64" "$1" >/dev/null 2>&1
    lipc-set-prop com.lab126.powerd flIntensity 24 2>/dev/null; sleep 1
    "$FB" -q -c -f -h -m -M -t "regular=$BOLD,px=64" "$1" >/dev/null 2>&1
    lipc-set-prop com.lab126.powerd flIntensity 0 2>/dev/null; sleep 1
    k=$((k + 1))
  done
  [ -n "$l0" ] && lipc-set-prop com.lab126.powerd flIntensity "$l0" 2>/dev/null
  LIGHT_NOW=""
}

pomo_tick() { # gọi mỗi vòng lặp: hết giờ thì chuyển pha + báo
  pomo_running || return 1
  [ $(date +%s) -ge $POMO_END ] || return 1
  pomo_today
  if [ "$POMO_STATE" = focus ]; then
    POMO_COUNT=$((POMO_COUNT + 1)); POMO_MIN_TODAY=$(( POMO_MIN_TODAY + POMO_FOCUS ))
    log "pomodoro: focus done (#$POMO_COUNT)"
    if [ $(( POMO_COUNT % POMO_LONG_EVERY )) = 0 ]; then nxt=long; msg="Nghỉ dài $POMO_LONG phút"; else nxt=break; msg="Nghỉ $POMO_BREAK phút"; fi
    [ "$POMO_SKIP" = 1 ] || pomo_alert "Hết giờ tập trung!" "$msg"
    pomo_start $nxt                       # tự chuyển sang nghỉ
  else
    log "pomodoro: break done"
    [ "$POMO_SKIP" = 1 ] || pomo_alert "Hết giờ nghỉ!" "Chạm BẮT ĐẦU cho phiên mới"
    POMO_STATE=done_break; POMO_KIND=focus
  fi
  PAGE=pomo; VIEW=main
  return 0
}

pomo_sleep_cap() { # giây tối đa nên ngủ (để báo đúng lúc hết giờ)
  pomo_running || { echo 99999; return; }
  l=$(( POMO_END - $(date +%s) )); [ $l -lt 1 ] && l=1; echo $l
}

# ---------- Trang Pomodoro ----------
pomo_buttons() { # -> toạ độ nút: B1 (trái/giữa) và B2 (phải)
  BY=$(( H - 300 )); BH=120
  if [ "$POMO_STATE" = idle ] || [ "$POMO_STATE" = done_break ]; then B1X=$(( W / 2 - 220 )); B1W=440; B2X=-1
  else B1X=60; B1W=$(( W / 2 - 80 )); B2X=$(( W / 2 + 20 )); B2W=$(( W / 2 - 80 )); fi
}
render_pomo() {
  pomo_today
  "$FB" -q -b -k >/dev/null 2>&1
  txt 30 18 40 "$I_HOURGLASS" s; txt 30 18 80 "Pomodoro" b
  page_icons 18
  box 66 40 $(( W - 80 )) 2
  case "$POMO_STATE" in
    focus) st="Đang tập trung" ;; break) [ "$POMO_KIND" = long ] && st="Nghỉ dài" || st="Nghỉ ngắn" ;;
    paused) st="Tạm dừng" ;; done_break) st="Sẵn sàng cho phiên mới" ;; *) st="Sẵn sàng" ;;
  esac
  TXTOPT="-m"
  txt 40 110 0 "$st" b
  left=$(pomo_left)
  if pomo_active && [ "$POMO_STATE" != done_break ]; then
    mn=$(( (left + 59) / 60 )); txt 300 170 0 "$mn" b; txt 40 500 0 "phút"
  else
    txt 300 170 0 "$POMO_FOCUS" b; txt 40 500 0 "phút tập trung"
  fi
  TXTOPT=""
  # thanh tiến trình
  if pomo_active && [ "$POMO_STATE" != done_break ] && [ $POMO_TOTAL -gt 0 ]; then
    done_s=$(( POMO_TOTAL - left )); frame 572 80 598 22 2; box 576 84 $(( 590 * done_s / POMO_TOTAL )) 14
  fi
  # các phiên trong vòng 4
  k=0; inset=$(( POMO_COUNT % POMO_LONG_EVERY )); cx0=$(( W / 2 - (POMO_LONG_EVERY - 1) * 30 ))
  while [ $k -lt $POMO_LONG_EVERY ]; do
    if [ $k -lt $inset ]; then txt 30 618 $(( cx0 + k * 60 - 14 )) "$I_DISC" s; else txt 30 618 $(( cx0 + k * 60 - 14 )) "$I_RING" s; fi
    k=$((k + 1))
  done
  TXTOPT="-m"; txt 24 664 0 "Hôm nay: $POMO_COUNT phiên · $POMO_MIN_TODAY phút tập trung"; TXTOPT=""
  pomo_buttons
  case "$POMO_STATE" in
    idle|done_break) frame $BY $B1X $B1W $BH 5; TXTOPT="-m"; txt 44 $(( BY + 34 )) 0 "BẮT ĐẦU" b; TXTOPT="" ;;
    paused) frame $BY $B1X $B1W $BH 5; txt 36 $(( BY + 38 )) $(( B1X + 40 )) "TIẾP TỤC" b
            frame $BY $B2X $B2W $BH 3; txt 36 $(( BY + 38 )) $(( B2X + 70 )) "DỪNG" b ;;
    *)      frame $BY $B1X $B1W $BH 5; txt 36 $(( BY + 38 )) $(( B1X + 34 )) "TẠM DỪNG" b
            frame $BY $B2X $B2W $BH 3; txt 36 $(( BY + 38 )) $(( B2X + 60 )) "BỎ QUA" b ;;
  esac
  { [ "$POMO_STATE" = idle ] || [ "$POMO_STATE" = done_break ]; } && { TXTOPT="-m"; txt 20 548 0 "(chạm vào số phút để đổi: 25 · 50 · 15 · 45)"; TXTOPT=""; }
  txt 20 $(( H - 130 )) 40 "Tập trung $POMO_FOCUS′ · nghỉ $POMO_BREAK′ · nghỉ dài $POMO_LONG′ sau mỗi $POMO_LONG_EVERY phiên. Hết giờ màn hình và đèn sẽ nháy." "" $(( W - 80 )) 70
  refresh "$1"
}
pomo_tap() { # x y
  pomo_buttons
  in1=0; in2=0
  [ $2 -ge $BY ] && [ $2 -le $(( BY + BH )) ] && [ $1 -ge $B1X ] && [ $1 -le $(( B1X + B1W )) ] && in1=1
  [ $B2X -ge 0 ] && [ $2 -ge $BY ] && [ $2 -le $(( BY + BH )) ] && [ $1 -ge $B2X ] && [ $1 -le $(( B2X + B2W )) ] && in2=1
  if [ $in1 = 0 ] && [ $in2 = 0 ] && [ $2 -ge 160 ] && [ $2 -le 560 ] && { [ "$POMO_STATE" = idle ] || [ "$POMO_STATE" = done_break ]; }; then
    case "$POMO_FOCUS" in 25) POMO_FOCUS=50; POMO_BREAK=10 ;; 50) POMO_FOCUS=15; POMO_BREAK=3 ;; 15) POMO_FOCUS=45; POMO_BREAK=15 ;; *) POMO_FOCUS=25; POMO_BREAK=5 ;; esac
    save_setting POMO_FOCUS $POMO_FOCUS; save_setting POMO_BREAK $POMO_BREAK; return
  fi
  case "$POMO_STATE" in
    idle|done_break) [ $in1 = 1 ] && pomo_start focus ;;
    paused) [ $in1 = 1 ] && pomo_resume; [ $in2 = 1 ] && pomo_stop ;;
    focus|break)
      [ $in1 = 1 ] && pomo_pause
      if [ $in2 = 1 ]; then POMO_END=$(date +%s); POMO_SKIP=1; pomo_tick; POMO_SKIP=0; fi ;;
  esac
}
