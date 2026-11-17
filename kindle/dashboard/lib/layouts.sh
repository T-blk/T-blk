# Bố cục toàn màn hình hiện đại (chỉ chiều dọc). LAYOUT = codien | toigian | thuysi | the | anh | chu | lich
# Mỗi bố cục có các ô: đồng hồ (CB), sự kiện (EB), ảnh (PB) — kiểu của từng ô chọn riêng trong Cài đặt > Giao diện.

layout_active() {
  [ -n "$LAYOUT" ] && [ "$LAYOUT" != codien ] && [ $W -le $H ] && modern_ok
}

# Đặt ô + kiểu mặc định của bố cục. Ô = "x y rộng cao"
lay_setup() {
  CB=""; EB=""; PB=""; CALB=""; CA=l; PMASK=""; LBL_F=semi; LBL_PX=15; LBL_C=s; NOW_BIGF=semi; TXBG=""
  case "$LAYOUT" in
    toigian) LAY_CLOCK=mong; LAY_EVENTS=baygio; LAY_PHOTO=tran
             CB="34 96 690 214"; EB="40 524 678 176" ;;
    thuysi)  LAY_CLOCK=dam; LAY_EVENTS=baygio; LAY_PHOTO=tran
             CB="440 98 278 62"; CA=r; EB="396 234 310 176"; CALB="40 628 718 1010"
             LBL_F=bold; LBL_PX=16; LBL_C=k; NOW_BIGF=black ;;
    the)     LAY_CLOCK=mong; LAY_EVENTS=baygio; LAY_PHOTO=tran
             CB="58 104 470 180"; EB="54 378 296 214"; PB="389 354 341 250"; PMASK=r; CALB="28 624 730 1004" ;;
    anh)     LAY_CLOCK=mong; LAY_EVENTS=gon; LAY_PHOTO=tran
             PB="0 0 758 600"; CB="40 636 390 164"; EB="40 848 678 104" ;;
    chu)     LAY_CLOCK=chu; LAY_EVENTS=cau; LAY_PHOTO=tran
             CB="38 86 690 352"; EB="40 718 678 170" ;;
    lich)    LAY_CLOCK=mong; LAY_EVENTS=moc; LAY_PHOTO=tran
             CB="480 88 238 54"; CA=r; EB="40 726 678 290"; CALB="40 84 718 712" ;;
  esac
  # vùng chạm + vùng đồng hồ cho update_clock
  set -- $CB; CLK_X=${1:-0}; CLK_Y=${2:-0}; CLK_W=${3:-0}; CLK_H=${4:-0}
  set -- $EB; EV_X=${1:-9999}; EV_Y=${2:-9999}; EV_W=${3:-0}; EV_Y2=$(( ${2:-9999} + ${4:-0} ))
  set -- $PB; PH_X=${1:-9999}; PH_Y=${2:-9999}; PH_W=${3:-0}; PH_H=${4:-0}
  set -- $CALB; CX=${1:-9999}; CAL_Y=${2:-9999}; CAL_X2=${3:-0}; CAL_Y2=${4:-0}
}

lay_data() {
  common_date; holiday; lunar_today
  cm=$(( M + MOFF )); cy=$Y
  while [ $cm -gt 12 ]; do cm=$((cm - 12)); cy=$((cy + 1)); done
  while [ $cm -lt 1 ]; do cm=$((cm + 12)); cy=$((cy - 1)); done
  CAL_M=$cm; CAL_YR=$cy
  f=$(epoch_day $cy $cm 1); t=$(( f + 42 )); [ $f -gt $TD ] && f=$TD
  [ $t -lt $(( TD + DAYS_AHEAD )) ] && t=$(( TD + DAYS_AHEAD ))
  EV=/tmp/dash_events.txt; events_to "$f" "$t" "$EV"
  WX_OK=0; parse_weather && WX_OK=1
  BATT=$(battery)
}

lay_toolbar() { # thanh nút ở góc phải trên (to, dễ bấm)
  [ "$ONCE" = 1 ] && return
  set_layout                                   # B_STATUS B_LIGHT B_PAGE B_GEAR B_HOME
  toolbar_icons "${1:-m}"
}
toolbar_icons() { # màu
  c=$1
  bat_top $c
  tx sym 38 $B_STATUS 12 "$I_COFFEE" l $c
  _l=$(light_level)
  if [ -n "$_l" ]; then tx sym 36 $B_LIGHT 13 "$I_BRIGHT" l $c; tx semi 22 $(( B_LIGHT + 42 )) 22 "$_l" l $c; fi
  [ "$(page_list)" != main ] && tx sym 38 $B_PAGE 12 "$I_PAGES" l $c
  tx sym 38 $B_GEAR 12 "$I_GEAR" l $c
  [ -n "$UPD_AVAIL" ] && rect $(( B_GEAR + 36 )) 10 12 12 BLACK
  tx sym 38 $B_HOME 12 "$I_HOME" l $c
}
# % pin, ngay trái nút trạng thái (không nhận chạm)
bat_top() { # màu
  [ -n "$BATT" ] || BATT=$(battery); [ -n "$BATT" ] || return 0
  _bt="$BATT%"; [ "$CHARGING" = 1 ] && _bt="$BATT%+"
  BAT_C=${1:-m}; BAT_BG=$TXBG                  # nhớ màu chữ/nền để lần sau chỉ vẽ lại riêng ô này (bat_fast)
  tx semi 22 $(( B_STATUS - 22 )) 22 "$_bt" r ${1:-m}
}
bat_fast() { # chỉ vẽ lại ô % pin (khỏi vẽ ngầm cả màn hình); trả 1 nếu bố cục không hợp (vd nền là ảnh)
  [ "$VIEW" = main ] && [ "$PAGE" = main ] && [ "$ONCE" != 1 ] && [ -n "$BAT_C" ] || return 1
  [ "$LAYOUT" = anh ] && layout_active && return 1
  set_layout; BATT=$1; _bx0=$(( B_STATUS - 140 ))
  rect $_bx0 12 $(( B_STATUS - 16 - _bx0 )) 44 "${BAT_BG:-WHITE}"
  TXBG=$BAT_BG; bat_top "$BAT_C"; TXBG=""
  refresh 0 "top=12,left=$_bx0,width=$(( B_STATUS - 16 - _bx0 )),height=44"
  log "pin $BATT%: chỉ vẽ lại ô pin"
}
slot() { echo "$1"; }                           # tiện đọc
lunar_short() { nh=""; [ "$L_LEAP" = 1 ] && nh=" nhuận"; echo "$L_D/$L_M$nh"; }
month_days() { # năm tháng -> số ngày
  case $2 in 4|6|9|11) echo 30 ;; 2) if [ $(( $1 % 4 )) = 0 ] && { [ $(( $1 % 100 )) != 0 ] || [ $(( $1 % 400 )) = 0 ]; }; then echo 29; else echo 28; fi ;; *) echo 31 ;; esac
}
first_col() { # epoch-day ngày 1 -> cột (0..6) theo WEEK_START
  c=$(( ($1 + 4) % 7 )); [ "$WEEK_START" != 0 ] && c=$(( (c + 6) % 7 )); echo $c
}
wd_header() { if [ "$WEEK_START" = 0 ]; then echo "CN T2 T3 T4 T5 T6 T7"; else echo "T2 T3 T4 T5 T6 T7 CN"; fi; }
is_sunday_col() { if [ "$WEEK_START" = 0 ]; then [ $1 = 0 ]; else [ $1 = 6 ]; fi; }
weather_line() { [ $WX_OK = 1 ] && echo "$WX_DESC   ${WX_MIN}° / ${WX_MAX}°   mưa ${WX_RAIN}%"; }

# ---------------- 1. Tối giản ----------------
render_l_toigian() {
  tx_fit semi 20 40 26 "$(up "$(pick "$WD_LONG" "$(date +%w)") · $D tháng $M")" $(( B_STATUS - 116 )) m
  lay_toolbar
  w_clock $CB $CA
  lt="Âm lịch $(lunar_short) · $L_CC"; [ -n "$HOLI_TEXT" ] && lt="$lt · $HOLI_TEXT"
  tx light 26 42 330 "$lt" l m 676
  hl 392 40 718
  if [ $WX_OK = 1 ]; then
    [ "$WEATHER_ICON" = 1 ] && tx sym 44 40 414 "$WX_ICON" l k
    tx light 48 100 410 "${WX_TEMP}°" l k
    tx reg 22 210 432 "$(weather_line)" l m 508
  else tx light 28 40 424 "Chưa có thời tiết" l m; fi
  hl 500 40 718
  w_events $EB
  hl 712 40 718
  ev_week 40 734 678 120 0
  q=$(quote_today); [ -n "$q" ] && tx light 24 40 930 "“$q”" l m 540
}

# ---------------- 2. Lưới Thụy Sĩ ----------------
render_l_thuysi() {
  lay_toolbar
  dw=$(tw black $(px_for_cap black 104) "$D")
  txcap black 104 38 94 "$D"
  bx=$(( 38 + dw + 28 ))
  tx bold 34 $bx 86 "$(up "$(pick "$WD_LONG" "$(date +%w)")")" l k $(( 430 - bx ))
  tx reg 26 $bx 130 "Tháng $M, $Y" l m $(( 430 - bx ))
  tx reg 22 $bx 166 "Âm $(lunar_short) $L_CC" l s $(( 430 - bx ))
  w_clock $CB $CA
  [ -n "$HOLI_TEXT" ] && tx semi 16 718 172 "$HOLI_TEXT" r k 280
  hl 214 40 718 BLACK 4
  vl 379 228 606 BLACK 1; hl 418 40 718 BLACK 1
  tx bold 16 56 234 "THỜI TIẾT" l k
  if [ $WX_OK = 1 ]; then
    ix=56; [ "$WEATHER_ICON" = 1 ] && { tx sym 64 56 262 "$WX_ICON" l k; ix=150; }
    txcap black 52 $ix 276 "${WX_TEMP}°"
    tx reg 20 56 360 "$WX_DESC · mưa ${WX_RAIN}%" l m 310
  else tx reg 22 56 290 "Chưa có dữ liệu" l m; fi
  w_events $EB
  a=$(aqi_text)
  if [ -n "$a" ]; then
    v=$(echo "$a" | sed 's/AQI \([0-9]*\).*/\1/'); lvl=${a#*· }
    tx bold 16 56 434 "KHÔNG KHÍ" l k
    txcap black 52 56 470 "$v"; vw=$(tw black $(px_for_cap black 52) "$v")
    tx reg 20 $(( 56 + vw + 16 )) 496 "AQI · $lvl" l m $(( 300 - vw ))
  elif [ $WX_OK = 1 ]; then
    tx bold 16 56 434 "ĐỘ ẨM"; txcap black 52 56 470 "${WX_HUM}%"
  fi
  tx bold 16 396 434 "MẶT TRỜI" l k
  if [ -n "$WX_RISE" ]; then
    tx sym 30 396 470 "$I_SUNRISE" l k; tx bold 40 440 462 "$WX_RISE" l k
    tx sym 30 396 524 "$I_SUNSET" l s; tx bold 40 440 516 "$WX_SET" l s
  fi
  hl 618 40 718 BLACK 4
  cal_swiss 40 636
}
cal_swiss() { # x y : lịch tháng kiểu lưới Thụy Sĩ
  x0=$1; y0=$2; cw=97; rh=48
  tx bold 16 $x0 $y0 "THÁNG $CAL_M · $CAL_YR" l k
  [ $MOFF != 0 ] && tx reg 16 718 $y0 "chạm để về hôm nay" r s
  i=0; for hn in $(wd_header); do c=s; is_sunday_col $i && c=k; tx bold 16 $(( x0 + i * cw )) $(( y0 + 30 )) "$hn" l $c; i=$((i + 1)); done
  fd=$(epoch_day $CAL_YR $CAL_M 1); off=$(first_col $fd); nd=$(month_days $CAL_YR $CAL_M)
  load_evdays
  d=1
  while [ $d -le $nd ]; do
    p=$(( off + d - 1 )); col=$(( p % 7 )); x=$(( x0 + col * cw )); y=$(( y0 + 62 + (p / 7) * rh ))
    if [ $(( fd + d - 1 )) = $TD ]; then box_num $(( x - 8 )) $(( y - 2 )) 56 42 "$d" bold 19
    else f=reg; is_sunday_col $col && f=bold; txcap $f 19 $x $(( y + 10 )) "$d" l k; fi
    is_evday "$(( fd + d - 1 ))" && [ $(( fd + d - 1 )) != $TD ] && rect $(( x + 40 )) $(( y + 10 )) 5 5 GRAY6
    d=$((d + 1))
  done
}

# ---------------- 3. Thẻ ----------------
render_l_the() {
  if [ -f "$DIR/ui/bg_the.png" ]; then image "$DIR/ui/bg_the.png" 0 0; else rect 0 0 $W $H GRAYE; fi
  TXBG=GRAYE
  tx_fit semi 28 44 22 "$(pick "$WD_LONG" "$(date +%w)"), $D tháng $M" $(( B_STATUS - 120 ))
  lay_toolbar d
  TXBG=""
  w_clock $CB $CA
  if [ $WX_OK = 1 ]; then
    [ "$WEATHER_ICON" = 1 ] && tx sym 70 588 120 "$WX_ICON" l k
    tx semi 44 628 214 "${WX_TEMP}°" c k
  fi
  tx reg 22 60 294 "Âm lịch $(lunar_short) · $L_CC" l m 640
  w_events $EB
  w_photo $PB $PMASK
  cal_card 54 646
}
cal_card() { # x y : lịch tháng trong thẻ (chấm sự kiện, hôm nay tròn đen)
  x0=$1; y0=$2; cw=94
  tx semi 28 $x0 $y0 "Tháng $CAL_M" l k; twv semi 28 "Tháng $CAL_M"; mw=$TWV
  tx reg 24 $(( x0 + mw + 12 )) $(( y0 + 3 )) "$CAL_YR" l s
  if [ $MOFF != 0 ]; then tx reg 18 702 $(( y0 + 8 )) "chạm để về hôm nay" r s
  elif [ -n "$HOLI_TEXT" ]; then tx semi 18 702 $(( y0 + 8 )) "$HOLI_TEXT" r m 330; fi
  i=0; for hn in $(wd_header); do tx semi 16 $(( x0 + i * cw + 30 )) $(( y0 + 50 )) "$hn" c s; i=$((i + 1)); done
  fd=$(epoch_day $CAL_YR $CAL_M 1); off=$(first_col $fd); nd=$(month_days $CAL_YR $CAL_M)
  rows=$(( (off + nd + 6) / 7 )); rh=46; [ $rows -ge 6 ] && rh=42
  load_evdays
  d=1
  while [ $d -le $nd ]; do
    p=$(( off + d - 1 )); col=$(( p % 7 )); cx=$(( x0 + col * cw + 30 )); y=$(( y0 + 86 + (p / 7) * rh ))
    ed=$(( fd + d - 1 ))
    if [ $ed = $TD ]; then disc_num $cx $(( y + 12 )) 42 "$d" semi 17
    else c=k; [ $ed -lt $TD ] && c=s; txcap reg 17 $cx $(( y + 3 )) "$d" c $c; fi
    is_evday "$ed" && [ $ed != $TD ] && rect $(( cx - 2 )) $(( y + 26 )) 4 4 GRAY6
    d=$((d + 1))
  done
}

# ---------------- 4. Ảnh ----------------
render_l_anh() {
  w_photo $PB
  lay_toolbar k
  w_clock $CB $CA
  tx semi 32 446 650 "$(pick "$WD_LONG" "$(date +%w)")" l k 272
  tx light 32 446 692 "$D tháng $M" l k 272
  [ $WX_OK = 1 ] && tx reg 22 446 742 "${WX_TEMP}° · $WX_DESC" l m 272
  tx reg 18 446 776 "Âm lịch $(lunar_short)" l s 272
  hl 830 40 718
  w_events $EB
  [ -n "$PHOTO_CAP" ] && tx light 18 40 972 "$PHOTO_CAP" l s 500
}

# ---------------- 5. Chữ ----------------
render_l_chu() {
  tx light 28 40 26 "Bây giờ là" l s
  lay_toolbar
  w_clock $CB $CA
  nh=""; [ "$L_LEAP" = 1 ] && nh=" nhuận"
  lm="mùng $L_D"; [ $L_D -gt 10 ] && lm="ngày $L_D"
  tx reg 22 40 462 "$(pick "$WD_LONG" "$(date +%w)"), ngày $D tháng $M · âm lịch $lm tháng $L_M$nh" l m 678
  hl 520 40 718
  if [ $WX_OK = 1 ]; then
    tx light 40 40 544 "$WX_DESC, ${WX_TEMP} độ." l k 678
    r=$WX_RAIN; [ -z "$r" ] && r=0
    if [ "$r" -ge 50 ]; then s2="Khả năng mưa cao: ${r}%."; elif [ "$r" -ge 20 ]; then s2="Có thể mưa (${r}%)."; else s2="Ít khả năng mưa."; fi
    tx light 40 40 596 "$s2 Từ ${WX_MIN} đến ${WX_MAX} độ." l k 678
  else tx light 40 40 560 "Chưa có tin thời tiết." l m; fi
  hl 692 40 718
  w_events $EB
  ht=$(awk -v D="$D" -v M="$M" -v Y="$Y" -v LD="$L_D" -v LM="$L_M" -v LEAP="$L_LEAP" -f "$DIR/lib/holiday.awk" | cut -d'|' -f2)
  case "$ht" in
    *" · còn "*" ngày") nm=${ht%% · còn *}; n=${ht##* · còn }; n=${n% ngày}; s3="Còn $n ngày nữa là $nm." ;;
    "Hôm nay: "*) s3="Hôm nay là ${ht#Hôm nay: }." ;;
    "") q=$(quote_today); s3=""; [ -n "$q" ] && s3="“$q”" ;;
    *) s3="$ht." ;;
  esac
  tx reg 22 40 912 "$s3" l m 678
}

# ---------------- 6. Lịch ----------------
render_l_lich() {
  lay_toolbar
  tx thin 66 38 76 "Tháng $(pick "$VN_MONTH" $(( CAL_M - 1 )))" l k 440
  w_clock $CB $CA
  [ $WX_OK = 1 ] && tx reg 20 718 140 "${WX_TEMP}° · $WX_DESC" r m 230
  nd=$(month_days $CAL_YR $CAL_M); load_lunar_month $CAL_M $CAL_YR
  eval "lm1=\$LNM_1 lm2=\$LNM_$nd"
  lr="tháng $lm1"; [ "$lm1" != "$lm2" ] && lr="tháng $lm1–$lm2"
  sub="$CAL_YR · $lr âm lịch $L_CC"; [ -n "$HOLI_TEXT" ] && sub="$sub · $HOLI_TEXT"; [ $MOFF != 0 ] && sub="$CAL_YR · chạm tên tháng để về hôm nay"
  tx reg 22 40 166 "$sub" l m 678
  cw=97; i=0
  for hn in $(wd_header); do tx semi 18 $(( 40 + i * cw + cw / 2 )) 214 "$hn" c s; i=$((i + 1)); done
  hl 246 40 718 BLACK 1
  fd=$(epoch_day $CAL_YR $CAL_M 1); off=$(first_col $fd)
  rows=$(( (off + nd + 6) / 7 )); rh=$(( 460 / rows )); [ $rh -gt 84 ] && rh=84
  load_evdays
  [ "$SHOW_LUNAR" = 1 ] && load_lunar_month $CAL_M $CAL_YR
  r=1; while [ $r -le $rows ]; do hl $(( 246 + r * rh )) 40 718 GRAYC 1; r=$((r + 1)); done
  d=1
  while [ $d -le $nd ]; do
    p=$(( off + d - 1 )); col=$(( p % 7 )); x=$(( 40 + col * cw )); y=$(( 246 + (p / 7) * rh ))
    ed=$(( fd + d - 1 ))
    if [ $ed = $TD ]; then disc_num $(( x + 34 )) $(( y + 30 )) 48 "$d" semi 19
    else f=reg; is_sunday_col $col && f=semi; c=k; [ $ed -lt $TD ] && c=m; txcap $f 20 $(( x + 14 )) $(( y + 20 )) "$d" l $c; fi
    if [ "$SHOW_LUNAR" = 1 ]; then
      eval "ld=\$LND_$d lmo=\$LNM_$d"; lt=$ld; [ "$ld" = 1 ] && lt="1/$lmo"
      tx reg 14 $(( x + 16 )) $(( y + rh - 26 )) "$lt" l s
    fi
    is_evday "$ed" && dot $(( x + 82 )) $(( y + 18 )) 7 k
    d=$((d + 1))
  done
  w_events $EB
}

render_layout() { # $1 = 1 nháy đen
  set_layout; lay_setup; lay_data             # set_layout trước: cần B_STATUS cho dòng ngày (tx_fit)
  log "render layout $LAYOUT: begin"
  "$FB" -q -b -k >/dev/null 2>&1
  case "$LAYOUT" in the|anh) ;; *) draw_ornaments ;; esac
  PHOTO_CAP=""
  render_l_$LAYOUT
  TXBG=""
  refresh "$1"
  log "render main: done"
}

update_clock_layout() {
  lay_setup
  set -- $CB
  clock_region_redraw $2 $1 $3 $4 w_clock $CB $CA
}
