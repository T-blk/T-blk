# Các trang phụ của Kindle Dashboard (được dash.sh nạp bằng ". lib/pages.sh").
#   tin  = Bảng tin: sự kiện kế tiếp, tiến trình ngày, lịch tuần
#   bloc = Lịch bloc (tờ lịch xé): số ngày lớn, âm lịch, can chi, giờ hoàng đạo, ca dao
#   dem  = Ban đêm: đồng hồ lớn, dự báo 5 ngày, chất lượng không khí
# Chỉ dùng ở bố cục dọc; khi xoay ngang chỉ có trang chính.

PAGE=main
page_list() { if [ $W -gt $H ]; then echo main; else echo "${PAGE_LIST:-main tin bloc dem pomo news}"; fi; }
page_next() { # $1 = 1 (trang sau) | -1 (trang trước)
  dir=$1; set -- $(page_list); n=$#; i=1; cur=1
  for p in "$@"; do [ "$p" = "$PAGE" ] && cur=$i; i=$((i + 1)); done
  nx=$(( (cur - 1 + dir + n) % n + 1 )); eval "PAGE=\${$nx}"
  log "page -> $PAGE"
}
auto_page() { # khi không có ai chạm: về trang mặc định, ban đêm tự chuyển trang đêm
  [ "$LAST_TOUCH" = 0 ] || return 0
  pomo_active && { [ "$PAGE" != pomo ] && { PAGE=pomo; LAST_KEY=""; }; return 0; }
  p="${DEFAULT_PAGE:-main}"
  is_night && [ "${NIGHT_PAGE:-dem}" != giu ] && p="${NIGHT_PAGE:-dem}"
  case " $(page_list) " in *" $p "*) ;; *) p=main ;; esac
  [ "$p" != "$PAGE" ] && { PAGE="$p"; LAST_KEY=""; log "auto page -> $PAGE"; }
}

# ---------- Dữ liệu phụ ----------
AQI=/tmp/dash_aqi.json
fetch_aqi() {
  due "$AQI" "$WEATHER_MIN" || return 0
  fetch "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$LAT&longitude=$LON&current=us_aqi,pm2_5&timezone=auto" "$AQI" '"current"'
}
aqi_text() { # -> "AQI 62 · Trung bình" hoặc rỗng
  [ -s "$AQI" ] || return 0
  J=$(tr -d '\n\r ' < "$AQI"); C=$(echo "$J" | sed -n 's/.*"current":{\([^}]*\)}.*/\1/p')
  v=$(round "$(jnum "$C" us_aqi)"); [ -n "$v" ] || return 0
  if [ $v -le 50 ]; then t="Tốt"; elif [ $v -le 100 ]; then t="Trung bình"; elif [ $v -le 150 ]; then t="Kém"
  elif [ $v -le 200 ]; then t="Xấu"; elif [ $v -le 300 ]; then t="Rất xấu"; else t="Nguy hại"; fi
  echo "AQI $v · $t"
}
forecast_lines() { # -> "yyyy-mm-dd|code|max|min" cho từng ngày dự báo
  [ -s "$WX" ] || return 0
  tr -d '\n\r ' < "$WX" | awk '
    function arr(s, key,   p, r) { p = index(s, "\"" key "\":["); if (!p) return ""; r = substr(s, p + length(key) + 4); return substr(r, 1, index(r, "]") - 1) }
    { i = index($0, "\"daily\":{"); if (!i) exit; d = substr($0, i)
      n = split(arr(d, "time"), T, ","); split(arr(d, "weather_code"), C, ",")
      split(arr(d, "temperature_2m_max"), X, ","); split(arr(d, "temperature_2m_min"), N, ",")
      for (k = 1; k <= n; k++) { gsub(/"/, "", T[k]); printf "%s|%s|%.0f|%.0f\n", T[k], C[k], X[k], N[k] } }'
}
almanac() { # -> AL_LD AL_LM AL_LY AL_LEAP AL_YR AL_MO AL_DAY AL_HRS AL_TK
  r=$(awk -v MODE=almanac -v D="$D" -v M="$M" -v Y="$Y" -f "$DIR/lib/lunar.awk")
  AL_LD=$(echo "$r" | cut -d'|' -f1); AL_LM=$(echo "$r" | cut -d'|' -f2); AL_LY=$(echo "$r" | cut -d'|' -f3)
  AL_LEAP=$(echo "$r" | cut -d'|' -f4); AL_YR=$(echo "$r" | cut -d'|' -f5); AL_MO=$(echo "$r" | cut -d'|' -f6)
  AL_DAY=$(echo "$r" | cut -d'|' -f7); AL_HRS=$(echo "$r" | cut -d'|' -f8); AL_TK=$(echo "$r" | cut -d'|' -f9)
}
quote_today() { n=$(grep -c . "$DIR/lib/quotes.txt"); [ "$n" -gt 0 ] || return 0; sed -n "$(( TD % n + 1 ))p" "$DIR/lib/quotes.txt"; }
bat_icon() { # $1 = % pin
  if [ "$1" -ge 88 ]; then echo "$I_BAT4"; elif [ "$1" -ge 63 ]; then echo "$I_BAT3"; elif [ "$1" -ge 38 ]; then echo "$I_BAT2"
  elif [ "$1" -ge 13 ]; then echo "$I_BAT1"; else echo "$I_BAT0"; fi
}
is_charging() { [ "$(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null)" = 1 ]; }
wifi_connected() { [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ]; }

common_date() {
  Y=$(date +%Y); M=$(date +%m); D=$(date +%d); M=${M#0}; D=${D#0}
  TD=$(epoch_day "$Y" "$M" "$D")
  hh=$(date +%H); mm=$(date +%M); NOWMIN=$(( ${hh#0} * 60 + ${mm#0} ))
}
next_event() { # từ $EV -> NE_SUM NE_WHEN NE_LEFT (rỗng nếu không có)
  NE_SUM=""; NE_WHEN=""; NE_LEFT=""
  line=$(awk -F'|' -v TD="$TD" -v NOW="$NOWMIN" '($2 > TD) || ($2 == TD && $4 == 0 && $3 >= NOW) { print; exit }' "$EV")
  [ -n "$line" ] || return 0
  day=$(echo "$line" | cut -d'|' -f2); min=$(echo "$line" | cut -d'|' -f3); all=$(echo "$line" | cut -d'|' -f4)
  lab=$(echo "$line" | cut -d'|' -f5); NE_SUM=$(echo "$line" | cut -d'|' -f6-); [ -n "$lab" ] && NE_SUM="[$lab] $NE_SUM"
  if [ "$all" = 1 ]; then NE_WHEN="cả ngày"; else NE_WHEN=$(printf '%02d:%02d' $((min / 60)) $((min % 60))); fi
  if [ "$all" = 1 ]; then diff=$(( (day - TD) * 1440 - NOWMIN )); else diff=$(( (day - TD) * 1440 + min - NOWMIN )); fi
  if [ $diff -ge 1440 ]; then NE_LEFT="còn $(( (diff + 720) / 1440 )) ngày"
  elif [ $diff -ge 60 ]; then NE_LEFT="còn $((diff / 60)) giờ $((diff % 60)) phút"
  else NE_LEFT="còn $diff phút"; fi
  [ "$day" = "$TD" ] || NE_WHEN="$(pick "$WD_SHORT" $(( (day + 4) % 7 ))) $(day_dm "$day") · $NE_WHEN"
}

# ---------- Thanh biểu tượng góc trên (trang phụ) ----------
page_icons() { # $1 = y
  y=${1:-14}
  [ "$PAGE" != tin ] && txt 30 $y $(( W - 300 )) "$I_COFFEE" s
  txt 30 $y $(( W - 226 )) "$I_PAGES" s
  txt 30 $y $(( W - 150 )) "$I_GEAR" s
  [ -n "$UPD_AVAIL" ] && box $(( y + 2 )) $(( W - 122 )) 10 10
  txt 30 $y $(( W - 76 )) "$I_HOME" s
}
page_header_tap() { # x -> 0 nếu đã xử lý
  if [ $1 -ge $(( W - 100 )) ]; then go_home "tap Home"
  elif [ $1 -ge $(( W - 172 )) ]; then VIEW=settings
  elif [ $1 -ge $(( W - 250 )) ]; then page_next 1
  elif [ $1 -ge $(( W - 320 )) ] && [ "$PAGE" != tin ]; then VIEW=stpick
  else return 1; fi
  return 0
}
status_icons() { # x y : wifi + pin (+ đang sạc)
  x=$1; y=$2; b=$(battery)
  wifi_connected && { txt 24 $y $x "$I_WIFI" s; x=$(( x + 36 )); }
  [ -n "$b" ] && { txt 24 $y $x "$(bat_icon "$b")" s; x=$(( x + 38 )); }
  is_charging && { txt 22 $y $x "$I_BOLT" s; x=$(( x + 20 )); }
  [ -n "$b" ] && txt 22 $(( y - 1 )) $(( x + 4 )) "$b%"
}

page_events() { # nạp sự kiện từ hôm nay
  f=$TD; t=$(( TD + DAYS_AHEAD )); EV=/tmp/dash_events.txt; events_to "$f" "$t" "$EV"
}

# ---------- Trang Bảng tin ----------
render_tin() {
  common_date; holiday; page_events; next_event
  set_page_clock
  "$FB" -q -b -k >/dev/null 2>&1
  draw_ornaments
  txt 28 22 40 "$(date_text)" b 330
  status_icons 380 26
  page_icons 18
  box 66 40 $(( W - 80 )) 2

  draw_clock
  if parse_weather; then
    tx=470
    [ "$WEATHER_ICON" = 1 ] && { txt 80 84 470 "$WX_ICON" s; tx=566; }
    txt 60 90 $tx "${WX_TEMP}°" b
    txt 24 180 470 "$WX_DESC · ${WX_MIN}–${WX_MAX}°" "" 250
    a=$(aqi_text); [ -n "$a" ] && txt 20 214 470 "$a" "" 250
  fi

  pct=$(( NOWMIN * 100 / 1440 ))
  txt 20 258 40 "Hôm nay đã qua ${pct}%"
  [ -n "$HOLI_TEXT" ] && txt 20 258 330 "$I_CAL" s && txt 20 256 358 "$HOLI_TEXT" b 360 30
  frame 286 40 678 18 2; box 290 44 $(( 670 * pct / 100 )) 10

  frame 324 40 678 116 3
  txt 20 336 60 "SỰ KIỆN KẾ TIẾP" b
  if [ -n "$NE_SUM" ]; then
    txt 44 360 60 "$NE_SUM" b 400 60
    txt 36 364 480 "$NE_WHEN" b 230 50
    txt 20 414 480 "$NE_LEFT" "" 230 30
  else
    txt 30 372 60 "Không có sự kiện sắp tới" "" 620
  fi

  # lịch tuần
  txt 28 458 40 "Tuần này" b
  wd=$(( (TD + 4) % 7 )); if [ "$WEEK_START" = 0 ]; then off=$wd; else off=$(( (wd + 6) % 7 )); fi
  w0=$(( TD - off )); i=0
  awk -F'|' '{print $2}' "$EV" | sort -u > /tmp/dash_evdays.txt
  while [ $i -lt 7 ]; do
    dd=$(( w0 + i )); x=$(( 40 + i * 97 )); c=$(( x + 48 ))
    ctxt 22 500 $c "$(pick "$WD_SHORT" $(( (dd + 4) % 7 )))" b
    n=$(day_dm "$dd"); n=${n%%/*}
    if [ $dd = $TD ]; then RP=72; txt $RP $(( 538 + 17 - RP * 51 / 100 )) $(( c - RP * 35 / 100 )) "$I_RING" s; fi
    ctxt 34 538 $c "$n" b
    grep -qx "$dd" /tmp/dash_evdays.txt && box 598 $(( c - 4 )) 8 8
    i=$((i + 1))
  done
  box 628 40 678 2

  y=642
  awk -F'|' -v TD="$TD" -v NOW="$NOWMIN" '($2 > TD) || ($2 == TD && ($4 == 1 || $3 >= NOW - 60))' "$EV" | head -3 | while IFS='|' read -r key day min all label sum; do
    if [ "$day" = "$TD" ]; then w="Hôm nay"; elif [ "$day" = $((TD + 1)) ]; then w="Ngày mai"; else w="$(pick "$WD_SHORT" $(( (day + 4) % 7 ))) $(day_dm "$day")"; fi
    if [ "$all" = 1 ]; then t="cả ngày"; else t=$(printf '%02d:%02d' $((min / 60)) $((min % 60))); fi
    [ -n "$label" ] && sum="[$label] $sum"
    txt 22 $(( y + 6 )) 40 "$w" b 140
    txt 22 $(( y + 6 )) 182 "$t" "" 110
    txt 32 $y 296 "$sum" "" $(( W - 336 )) 46
    y=$(( y + 60 ))
  done
  NEWS_CARD=""; draw_news_card 826 40 678 186
  refresh "$1"
  log "render tin: done"
}

# ---------- Trang Lịch bloc ----------
render_bloc() {
  common_date; holiday; page_events; next_event; almanac
  set_page_clock
  "$FB" -q -b -k >/dev/null 2>&1
  draw_ornaments
  page_icons 6
  frame 50 40 678 70 3; frame 56 46 666 58 1
  TXTOPT="-m"
  txt 40 58 0 "THÁNG $M · $Y" b
  txt 400 96 0 "$D" b
  txt 56 470 0 "$(pick "CHỦ NHẬT|THỨ HAI|THỨ BA|THỨ TƯ|THỨ NĂM|THỨ SÁU|THỨ BẢY" "$(date +%w)")" b
  TXTOPT=""
  box 556 120 518 2
  nh=""; [ "$AL_LEAP" = 1 ] && nh=" nhuận"
  TXTOPT="-m"
  txt 30 568 0 "Ngày $AL_LD tháng $AL_LM$nh năm $AL_YR"
  txt 26 610 0 "Ngày $AL_DAY · Tháng $AL_MO"
  txt 22 648 0 "Giờ hoàng đạo: $AL_HRS"
  txt 22 680 0 "Tiết khí: $AL_TK"
  TXTOPT=""
  box 718 120 518 2
  q=$(quote_today)
  TXTOPT="-m"
  [ -n "$q" ] && txt 28 730 0 "“$q”" "" "" 84
  [ -n "$HOLI_TEXT" ] && txt 22 820 0 "$HOLI_TEXT" b
  TXTOPT=""

  frame 862 40 678 144 3
  draw_clock
  if parse_weather; then
    tx=390
    [ "$WEATHER_ICON" = 1 ] && { txt 60 872 390 "$WX_ICON" s; tx=462; }
    txt 50 874 $tx "${WX_TEMP}°" b
    txt 22 940 390 "$WX_DESC · mưa ${WX_RAIN}%" "" 320
  fi
  [ -n "$NE_SUM" ] && txt 20 970 60 "Kế tiếp: $NE_SUM · $NE_WHEN ($NE_LEFT)" b 640 30
  refresh "$1"
  log "render bloc: done"
}

# ---------- Trang Ban đêm ----------
render_dem() {
  common_date; lunar_today
  set_page_clock
  "$FB" -q -b -k >/dev/null 2>&1
  page_icons 14
  draw_clock
  TXTOPT="-m"
  txt 40 470 0 "$(pick "$WD_LONG" "$(date +%w)"), $D tháng $M"
  txt 28 526 0 "Âm lịch $L_D/$L_M · $L_CC"
  TXTOPT=""
  forecast_lines | sed -n '2,6p' > /tmp/dash_fc.txt
  i=0
  while IFS='|' read -r dte code mx mn; do
    c=$(( 95 + i * 142 ))
    yy=${dte%%-*}; r=${dte#*-}; mo=${r%%-*}; dd=${r#*-}
    ed=$(epoch_day "$yy" "${mo#0}" "${dd#0}")
    ctxt 26 640 $c "$(pick "$WD_SHORT" $(( (ed + 4) % 7 )))" b
    txt 56 676 $(( c - 32 )) "$(weather_icon "$code" 1)" s
    ctxt 28 760 $c "${mx}°" b
    ctxt 24 798 $c "${mn}°"
    i=$((i + 1))
  done < /tmp/dash_fc.txt
  box 900 80 598 2
  parse_weather >/dev/null 2>&1
  [ -n "$WX_RISE" ] && { txt 26 920 210 "$I_SUNRISE" s; txt 26 918 252 "$WX_RISE"; }
  [ -n "$WX_SET" ] && { txt 26 920 410 "$I_SUNSET" s; txt 26 918 452 "$WX_SET"; }
  a=$(aqi_text); [ -n "$a" ] && { TXTOPT="-m"; txt 24 962 0 "$a"; TXTOPT=""; }
  refresh "$1"
  log "render dem: done"
}

# Vùng đồng hồ của từng trang (dùng cho update_clock mỗi phút)
set_page_clock() {
  CLK_CENTER=0; CLK_FORCE=""
  case "$PAGE" in
    tin)  CLK_X=36; CLK_Y=70; CLK_W=420; CLK_H=180; CLK_PX=150; ANA_X=150; ANA_Y=72 ;;
    bloc) CLK_X=56; CLK_Y=868; CLK_W=320; CLK_H=100; CLK_PX=92; CLK_FORCE=digital ;;
    dem)  CLK_X=0; CLK_Y=150; CLK_W=$W; CLK_H=280; CLK_PX=250; CLK_CENTER=1; CLK_FORCE=digital ;;
    *)    set_layout; CLK_CENTER=0 ;;
  esac
}

# Vuốt: "S x0 y0 x1 y1" (toạ độ dọc gốc)
handle_swipe() {
  to_view "$1" "$2"; ax=$VX; ay=$VY; to_view "$3" "$4"; bx=$VX; by=$VY
  dx=$(( bx - ax )); dy=$(( by - ay )); adx=${dx#-}; ady=${dy#-}
  LAST_TOUCH=$(date +%s)
  log "swipe dx=$dx dy=$dy view=$VIEW page=$PAGE"
  if [ $ady -ge 160 ] && [ $ady -gt $adx ]; then          # vuốt dọc
    [ $dy -lt 0 ] && [ "$VIEW" = main ] && VIEW=stpick         # vuốt lên: chọn trạng thái
    [ $dy -gt 0 ] && [ "$VIEW" = stpick ] && VIEW=main
    return 0
  fi
  [ $adx -ge 120 ] && [ $adx -ge $ady ] || return 0
  case "$VIEW" in
    status) status_swipe $dx ;;
    main) if [ $dx -lt 0 ]; then page_next 1; else page_next -1; fi ;;
    photo) if [ $dx -lt 0 ]; then PHOFF=$((PHOFF + 1)); else PHOFF=$((PHOFF - 1)); fi ;;
    pick) if [ $dx -lt 0 ]; then PICKPAGE=$((PICKPAGE + 1)); else PICKPAGE=$((PICKPAGE - 1)); [ $PICKPAGE -lt 0 ] && PICKPAGE=0; fi ;;
  esac
}
