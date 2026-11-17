# Thành phần lắp ghép: đồng hồ, sự kiện, ảnh. Mỗi hàm vẽ vào một khung X Y R C (rộng, cao).
# Kiểu lấy từ CLOCK_STYLE / EVENT_STYLE / PHOTO_STYLE; "auto" = theo bố cục (LAY_CLOCK / LAY_EVENTS / LAY_PHOTO).

# ======================= ĐỒNG HỒ =======================
clock_style() { s="$CLOCK_STYLE"; [ -z "$s" ] || [ "$s" = auto ] && s="${LAY_CLOCK:-mong}"; echo "$s"; }

# w_clock X Y R C [căn l|c|r]
w_clock() {
  X=$1; Y0=$2; BW=$3; BH=$4; al=${5:-l}
  set -- $(date '+%H %M'); hh=$1; mm=$2; set -- "$X" "$Y0" "$BW" "$BH"
  h=${hh#0}; m=${mm#0}; [ -z "$h" ] && h=0; [ -z "$m" ] && m=0
  st=$(clock_style)
  case "$st" in
    lat)   [ $BH -ge 100 ] || st=dam ;;
    kim)   [ $BH -ge 190 ] && [ -f "$DIR/clock/0000.png" ] || st=so24 ;;
    kimtg) [ $BH -ge 180 ] && [ -f "$DIR/clockm/0000.png" ] || st=mong ;;
    vong)  [ $BH -ge 180 ] && [ -f "$DIR/ring/00.png" ] || st=mong ;;
    chu)   [ $BH -ge 110 ] || st=mong ;;
  esac
  case "$st" in
    kim|kimtg|vong)
      sz=190; [ $st != kim ] && sz=180
      case "$al" in c) ix=$(( X + (BW - sz) / 2 )) ;; r) ix=$(( X + BW - sz )) ;; *) ix=$X ;; esac
      iy=$(( Y0 + (BH - sz) / 2 ))
      if [ $st = kim ]; then image "$DIR/clock/$(printf '%02d%02d' $(( h % 12 )) $m).png" $ix $iy
      elif [ $st = kimtg ]; then image "$DIR/clockm/$(printf '%02d%02d' $(( h % 12 )) $m).png" $ix $iy
      else
        image "$DIR/ring/$(printf '%02d' $m).png" $ix $iy
        txcap light 38 $(( ix + 90 )) $(( iy + 71 )) "$hh:$mm" c
      fi ;;
    lat)
      th=$BH; tw_=$(( th * 82 / 100 )); gap=$(( th * 10 / 100 ))
      tot=$(( 2 * tw_ + gap )); [ $tot -gt $BW ] && { th=$(( th * BW / tot )); tw_=$(( th * 82 / 100 )); gap=$(( th * 10 / 100 )); tot=$(( 2 * tw_ + gap )); }
      case "$al" in c) x0=$(( X + (BW - tot) / 2 )) ;; r) x0=$(( X + BW - tot )) ;; *) x0=$X ;; esac
      ty=$(( Y0 + (BH - th) / 2 )); ch=$(( th * 50 / 100 ))
      for part in "$hh" "$mm"; do
        rect $x0 $ty $tw_ $th BLACK
        txcap bold $ch $(( x0 + tw_ / 2 )) $(( ty + (th - ch) / 2 )) "$part" c w
        rect $x0 $(( ty + th / 2 - 1 )) $tw_ 3 WHITE
        x0=$(( x0 + tw_ + gap ))
      done ;;
    chu)
      words3 "$h" "$m" > /tmp/dash_words
      l1=$(sed -n 1p /tmp/dash_words); l2=$(sed -n 2p /tmp/dash_words); l3=$(sed -n 3p /tmp/dash_words)
      if [ $BH -ge 240 ]; then n=3; else n=2; l2="$l2 $l3"; l3=""; fi
      lh=$(( BH / n )); px=$(( lh * 96 / 100 ))
      twv semi $px "$l1"; mw=$TWV; twv light $px "$l2"; w2=$TWV; [ $w2 -gt $mw ] && mw=$w2
      [ -n "$l3" ] && { twv light $px "$l3"; w3=$TWV; [ $w3 -gt $mw ] && mw=$w3; }
      [ $mw -gt $BW ] && { px=$(( px * BW / mw )); lh=$(( px * 104 / 100 )); }
      case "$al" in c) ax=$(( X + BW / 2 )) ;; r) ax=$(( X + BW )) ;; *) ax=$X ;; esac
      tx semi $px $ax $Y0 "$l1" $al
      tx light $px $ax $(( Y0 + lh )) "$l2" $al
      [ -n "$l3" ] && tx light $px $ax $(( Y0 + 2 * lh )) "$l3" $al ;;
    *)
      t="$hh:$mm"; lab=""
      case "$st" in
        so24) f=nbold ;; dam) f=black ;; mono) f=mono ;;
        so12) f=light; h12=$(( h % 12 )); [ $h12 = 0 ] && h12=12; t="$h12:$mm"
              lab="SÁNG"; [ $h -ge 11 ] && lab="TRƯA"; [ $h -ge 13 ] && lab="CHIỀU"; [ $h -ge 18 ] && lab="TỐI" ;;
        *) f=thin; [ $BH -lt 130 ] && f=light ;;
      esac
      ch=$(( BH * 78 / 100 ))
      # đo bằng ĐÚNG nét sẽ vẽ (độ tương phản Cao đổi Thin -> Light, rộng hơn) để số không tràn khỏi vùng xoá
      p=$(px_for_cap $f $ch); fkey $f $p; f=$FKEY; twv $f $p "$t"; w=$(( TWV + TWV / 30 )); lw=0
      [ -n "$lab" ] && lw=$(( ch * 70 / 100 ))
      if [ $(( w + lw )) -gt $BW ]; then ch=$(( ch * (BW - lw) / (w + 1) )); [ -n "$lab" ] && lw=$(( ch * 70 / 100 )); p=$(px_for_cap $f $ch); twv $f $p "$t"; w=$(( TWV + TWV / 30 )); fi
      case "$al" in c) lx=$(( X + (BW - w - lw) / 2 )) ;; r) lx=$(( X + BW - w - lw )) ;; *) lx=$X ;; esac
      cy=$(( Y0 + (BH - ch) / 2 ))
      txcap $f $ch $lx $cy "$t"
      [ -n "$lab" ] && txcap semi $(( ch / 7 + 4 )) $(( lx + w + ch / 12 )) $(( cy + ch / 10 )) "$lab" l m ;;
  esac
}

# ======================= SỰ KIỆN =======================
event_style() { s="$EVENT_STYLE"; [ -z "$s" ] || [ "$s" = auto ] && s="${LAY_EVENTS:-danhsach}"; echo "$s"; }

# danh sách sắp tới: DAY|MIN|ALL|DUR|LABEL|SUMMARY (bỏ việc đã xong hôm nay)
ev_upcoming() {
  [ -s "$EV" ] || { : > /tmp/dash_up2.txt; return; }
  awk -F'|' -v TD="$TD" -v NOW="$NOWMIN" '{ split($1, k, ":"); dur = k[2] + 0
      if ($2 > TD || ($2 == TD && ($4 == 1 || $3 + dur > NOW))) { s = $6; for (i = 7; i <= NF; i++) s = s "|" $i; print $2 "|" $3 "|" $4 "|" dur "|" $5 "|" s } }' "$EV" > /tmp/dash_up2.txt
}
hm() { printf '%02d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
day_word() { # DAY -> Hôm nay / Ngày mai / T4 18/11
  if [ "$1" = "$TD" ]; then echo "Hôm nay"; elif [ "$1" = $(( TD + 1 )) ]; then echo "Ngày mai"
  else echo "$(pick "$WD_SHORT" $(( ($1 + 4) % 7 ))) $(day_dm "$1")"; fi
}
left_text() { # phút -> "còn 4 giờ 36 phút"
  l=$1; [ $l -lt 0 ] && l=0
  if [ $l -ge 1440 ]; then echo "còn $(( l / 1440 )) ngày"
  elif [ $l -ge 60 ]; then hr=$(( l / 60 )); mi=$(( l % 60 )); [ $mi = 0 ] && echo "còn $hr giờ" || echo "còn $hr giờ $mi phút"
  else echo "còn $l phút"; fi
}
ev_title() { [ -n "$5" ] && [ "$EV_LABELS" != 0 ] && echo "[$5] $6" || echo "$6"; }   # fields như ev_upcoming
ev_line() { sed -n "${1}p" /tmp/dash_up2.txt; }
ev_split() { # "DAY|MIN|..." -> E_DAY E_MIN E_ALL E_DUR E_LAB E_SUM   (không gọi cut)
  _o=$IFS; IFS='|'; set -f; set -- $1; set +f; IFS=$_o
  E_DAY=$1; E_MIN=$2; E_ALL=$3; E_DUR=$4; E_LAB=$5; shift 5 2>/dev/null; E_SUM="$*"
  [ -n "$E_LAB" ] && E_SUM="[$E_LAB] $E_SUM"
}
ev_when() { # dùng E_* -> "Hôm nay · 19:00"
  if [ "$E_ALL" = 1 ]; then echo "$(day_word $E_DAY) · cả ngày"; else echo "$(day_word $E_DAY) · $(hm $E_MIN)"; fi
}
ev_none() { # X Y R
  if [ -n "$ICS_URL" ]; then tx light 28 $1 $2 "Không có lịch hẹn sắp tới" l m $3
  else tx light 28 $1 $2 "Chưa nối lịch Apple" l m $3; fi
}

w_events() { # X Y R C
  ev_upcoming
  case "$(event_style)" in
    gon) ev_gon "$@" ;; moc) ev_moc "$@" ;; baygio) ev_now "$@" ;; tuan) ev_week "$@" 1 ;;
    cham) ev_dots "$@" ;; dongtg) ev_timeline "$@" ;; cau) ev_sentence "$@" ;; *) ev_list "$@" ;;
  esac
}

ev_pages() { # số dòng/trang -> EVN EVSTART (theo EVPAGE)
  total=$(grep -c . /tmp/dash_up2.txt); per=$1; [ $per -lt 1 ] && per=1
  pages=$(( (total + per - 1) / per )); [ $pages -lt 1 ] && pages=1; [ $EVPAGE -ge $pages ] && EVPAGE=0
  EVSTART=$(( EVPAGE * per + 1 )); EVN=$per; EVTOTAL=$total; EVPAGES=$pages
}

ev_list() { # cổ điển: dòng giờ nhỏ + tiêu đề lớn
  X=$1; Y0=$2; BW=$3; BH=$4; step=80
  ev_pages $(( BH / step ))
  [ $EVTOTAL = 0 ] && { ev_none $X $Y0 $BW; return; }
  [ $EVPAGES -gt 1 ] && tx reg 18 $(( X + BW )) $Y0 "$((EVPAGE + 1))/$EVPAGES" r s
  y=$Y0; i=$EVSTART
  while [ $i -lt $(( EVSTART + EVN )) ]; do
    l=$(ev_line $i); [ -n "$l" ] || break; ev_split "$l"
    tx semi 20 $X $y "$(ev_when)" l m $(( BW - 60 ))
    tx reg 32 $X $(( y + 28 )) "$E_SUM" l k $BW
    y=$(( y + step )); i=$((i + 1))
  done
}

ev_gon() { # gọn: giờ | tiêu đề | ngày (phải)
  X=$1; Y0=$2; BW=$3; BH=$4; fs=24; step=$(( fs * 15 / 10 ))
  ev_pages $(( BH / step ))
  [ $EVTOTAL = 0 ] && { ev_none $X $Y0 $BW; return; }
  tcol=$(( $(tw semi $fs "00:00") + 18 )); y=$Y0; i=$EVSTART
  while [ $i -lt $(( EVSTART + EVN )) ]; do
    l=$(ev_line $i); [ -n "$l" ] || break; ev_split "$l"
    if [ "$E_ALL" = 1 ]; then tx semi $(( fs - 4 )) $X $(( y + 3 )) "cả ngày" l k; else tx semi $fs $X $y "$(hm $E_MIN)"; fi
    dw=$(day_word $E_DAY); dwid=$(tw reg $(( fs - 4 )) "$dw")
    tx reg $fs $(( X + tcol )) $y "$E_SUM" l k $(( BW - tcol - dwid - 20 ))
    tx reg $(( fs - 4 )) $(( X + BW )) $(( y + 3 )) "$dw" r s
    y=$(( y + step )); i=$((i + 1))
  done
}

ev_moc() { # mốc dọc: chấm + đường kẻ, giờ nhỏ, tiêu đề mảnh
  X=$1; Y0=$2; BW=$3; BH=$4; step=72
  ev_pages $(( BH / step ))
  [ $EVTOTAL = 0 ] && { ev_none $X $Y0 $BW; return; }
  y=$Y0; i=$EVSTART; last=$(( EVSTART + EVN - 1 ))
  while [ $i -le $last ]; do
    l=$(ev_line $i); [ -n "$l" ] || break; ev_split "$l"
    [ $i -lt $last ] && [ -n "$(ev_line $((i + 1)))" ] && vl $(( X + 20 )) $(( y + 18 )) $(( y + step + 4 )) GRAYC 2
    if [ "$E_DAY" = "$TD" ]; then dot $(( X + 21 )) $(( y + 10 )) 14 k; else ring $(( X + 21 )) $(( y + 10 )) 14 k; fi
    tx semi 18 $(( X + 46 )) $y "$(ev_when)" l m $(( BW - 46 ))
    tx light 32 $(( X + 46 )) $(( y + 24 )) "$E_SUM" l k $(( BW - 46 ))
    y=$(( y + step )); i=$((i + 1))
  done
}

ev_find_now() { # -> NOWL (đang diễn ra) NEXTL (kế tiếp)
  NOWL=$(awk -F'|' -v TD="$TD" -v N="$NOWMIN" '$1 == TD && $3 == 0 && $2 <= N && $2 + $4 > N { print; exit }' /tmp/dash_up2.txt)
  NEXTL=$(awk -F'|' -v TD="$TD" -v N="$NOWMIN" '!($1 == TD && $3 == 0 && $2 <= N) && !($1 == TD && $3 == 1) { print; exit }' /tmp/dash_up2.txt)
  [ -n "$NEXTL" ] || NEXTL=$(awk -F'|' -v TD="$TD" -v N="$NOWMIN" '!($1 == TD && $3 == 0 && $2 <= N) { print; exit }' /tmp/dash_up2.txt)
}
ev_mins_to() { echo $(( (E_DAY - TD) * 1440 + E_MIN - NOWMIN )); }

ev_now() { # Bây giờ & tiếp theo
  X=$1; Y0=$2; BW=$3; BH=$4
  ev_find_now
  lf=${LBL_F:-semi}; lp=${LBL_PX:-15}; lc=${LBL_C:-s}
  if [ -z "$NOWL$NEXTL" ]; then tx $lf $lp $X $Y0 "TIẾP THEO" l $lc; ev_none $X $(( Y0 + 30 )) $BW; return; fi
  if [ $BW -lt 440 ]; then                                     # khung hẹp (thẻ, ô lưới)
    if [ -n "$NOWL" ]; then ev_split "$NOWL"; lab="ĐANG DIỄN RA"; big="$(hm $E_MIN)–$(hm $(( (E_MIN + E_DUR) % 1440 )))"
      sub=$(left_text $(( E_MIN + E_DUR - NOWMIN )))
    else ev_split "$NEXTL"; lab="TIẾP THEO"
      if [ "$E_ALL" = 1 ]; then big="$(day_word $E_DAY)"; sub="cả ngày"
      else big=$(hm $E_MIN); [ "$E_DAY" != "$TD" ] && sub="$(day_word $E_DAY)" || sub=$(left_text $(ev_mins_to)); fi
    fi
    bf=${NOW_BIGF:-semi}
    tx $lf $lp $X $Y0 "$lab" l $lc
    bc=$(( BH * 22 / 100 )); [ $bc -gt 44 ] && bc=44
    txfit $bf $bc $X $(( Y0 + lp + 18 )) "$big" l k $BW
    ty=$(( Y0 + lp + 18 + bc + bc * 4 / 10 ))
    tx reg 28 $X $ty "$E_SUM" l k $BW
    tx reg 19 $X $(( ty + 42 )) "$sub" l m $BW
    return
  fi
  if [ -n "$NOWL" ] && [ -n "$NEXTL" ]; then                  # hai cột
    cw=$(( BW / 2 - 12 ))
    ev_split "$NOWL"
    rect $X $Y0 6 $(( BH - 10 )) BLACK
    tx semi 15 $(( X + 24 )) $Y0 "ĐANG DIỄN RA" l s
    tx semi 40 $(( X + 24 )) $(( Y0 + 24 )) "$E_SUM" l k $(( cw - 24 ))
    tx reg 19 $(( X + 24 )) $(( Y0 + 82 )) "$(hm $E_MIN) – $(hm $(( (E_MIN + E_DUR) % 1440 ))) · $(left_text $(( E_MIN + E_DUR - NOWMIN )))" l m $(( cw - 24 ))
    ev_split "$NEXTL"; x2=$(( X + BW / 2 + 12 ))
    rect $x2 $Y0 2 $(( BH - 10 )) GRAY9
    tx semi 15 $(( x2 + 18 )) $Y0 "TIẾP THEO" l s
    tx light 40 $(( x2 + 18 )) $(( Y0 + 24 )) "$E_SUM" l k $(( cw - 18 ))
    tx reg 19 $(( x2 + 18 )) $(( Y0 + 82 )) "$(ev_when)" l m $(( cw - 18 ))
    return
  fi
  l="$NOWL"; lab="ĐANG DIỄN RA"; [ -n "$l" ] || { l="$NEXTL"; lab="TIẾP THEO"; }
  ev_split "$l"
  tx semi 17 $X $Y0 "$lab" l s
  fs=58; [ $BH -lt 160 ] && fs=44
  tx light $fs $X $(( Y0 + 28 )) "$E_SUM" l k $BW
  if [ "$lab" = "ĐANG DIỄN RA" ]; then sub="$(hm $E_MIN) – $(hm $(( (E_MIN + E_DUR) % 1440 ))) · $(left_text $(( E_MIN + E_DUR - NOWMIN )))"
  elif [ "$E_ALL" = 1 ]; then sub="$(day_word $E_DAY) · cả ngày"
  elif [ "$E_DAY" = "$TD" ]; then sub="$(hm $E_MIN) · $(left_text $(ev_mins_to))"
  else sub="$(ev_when)"; fi
  tx reg 24 $X $(( Y0 + 28 + fs * 125 / 100 )) "$sub" l m $BW
  # dòng "sau đó" nếu còn chỗ
  if [ $BH -ge 175 ]; then
    n2=$(awk -F'|' -v L="$l" '$0 != L { print; exit }' /tmp/dash_up2.txt)
    [ -n "$n2" ] && { ev_split "$n2"; tx reg 20 $X $(( Y0 + 28 + fs * 125 / 100 + 38 )) "Sau đó: $E_SUM · $(ev_when)" l s $BW; }
  fi
}

week_start_day() { # epoch-day của đầu tuần chứa TD
  wd=$(( (TD + 4) % 7 ))                    # 0 = CN
  if [ "$WEEK_START" = 0 ]; then echo $(( TD - wd )); else echo $(( TD - (wd + 6) % 7 )); fi
}
ev_week() { # dải tuần (+ danh sách gọn bên dưới nếu $5=1 và còn chỗ)
  X=$1; Y0=$2; BW=$3; BH=$4; cw=$(( BW / 7 ))
  ws=$(week_start_day)
  load_evdays
  k=0
  while [ $k -lt 7 ]; do
    d=$(( ws + k )); cx=$(( X + k * cw + cw / 2 ))
    tx semi 17 $cx $Y0 "$(pick "$WD_SHORT" $(( (d + 4) % 7 )))" c s
    dn=$(day_dm $d); dn=${dn%%/*}
    if [ $d = $TD ]; then box_num $(( cx - 30 )) $(( Y0 + 30 )) 60 58 "$dn" semi 22
    else txcap light 22 $cx $(( Y0 + 48 )) "$dn" c k; fi
    is_evday "$d" && dot $cx $(( Y0 + 104 )) 7 m
    k=$((k + 1))
  done
  if [ "$5" = 1 ] && [ $BH -ge 200 ]; then
    hl $(( Y0 + 124 )) $X $(( X + BW ))
    ev_gon $X $(( Y0 + 142 )) $BW $(( BH - 142 ))
  fi
}

ev_dots() { # tháng dạng chấm + ngày lớn
  X=$1; Y0=$2; BW=$3; BH=$4
  ml=$(epoch_day $Y $M 1); nd=$(( $(epoch_day $([ $M = 12 ] && echo $((Y + 1)) || echo $Y) $([ $M = 12 ] && echo 1 || echo $((M + 1))) 1) - ml ))
  off=$(( (ml + 4) % 7 )); [ "$WEEK_START" != 0 ] && off=$(( (off + 6) % 7 ))
  sx=44; sy=$(( (BH - 20) / 6 )); [ $sy -gt 36 ] && sy=36
  i=1
  while [ $i -le $nd ]; do
    p=$(( off + i - 1 )); cx=$(( X + 20 + (p % 7) * sx )); cy=$(( Y0 + 20 + (p / 7) * sy ))
    if [ $i = $D ]; then dot $cx $cy 26 k
    elif [ $i -lt $D ]; then dot $cx $cy 10 s
    else ring $cx $cy 12 k; fi
    i=$((i + 1))
  done
  rx=$(( X + 7 * sx + 30 ))
  txcap thin 88 $rx $(( Y0 + 6 )) "$D"
  doy=$(( TD - $(epoch_day $Y 1 1) + 1 )); ny=$(( $(epoch_day $((Y + 1)) 1 1) - TD - 1 ))
  tx reg 19 $rx $(( Y0 + 112 )) "ngày thứ $doy · còn $ny ngày" l m $(( X + BW - rx ))
  ev_find_now; l="$NOWL"; [ -n "$l" ] || l="$NEXTL"
  if [ -n "$l" ]; then ev_split "$l"
    tx semi 15 $rx $(( Y0 + 150 )) "TIẾP THEO" l s
    tx reg 24 $rx $(( Y0 + 172 )) "$E_SUM" l k $(( X + BW - rx ))
    tx reg 18 $rx $(( Y0 + 206 )) "$(ev_when)" l m $(( X + BW - rx ))
  fi
}

ev_timeline() { # dòng thời gian 6h–24h hôm nay
  X=$1; Y0=$2; BW=$3; BH=$4
  h0=6; h1=24; span=$(( (h1 - h0) * 60 ))
  ly=$(( Y0 + 66 ))                         # trục
  hl $ly $X $(( X + BW )) GRAYC 2
  hh_=$h0
  while [ $hh_ -le $h1 ]; do
    x=$(( X + (hh_ - h0) * 60 * BW / span ))
    rect $x $(( ly - 8 )) 2 18 GRAY9
    tx reg 14 $x $(( ly + 14 )) "${hh_}h" c s
    hh_=$(( hh_ + 3 ))
  done
  lastx=-999; alld=""
  awk -F'|' -v TD="$TD" '$1 == TD' /tmp/dash_up2.txt > /tmp/dash_today.txt
  awk -F'|' -v TD="$TD" '{ split($1,k,":"); if ($2 == TD) print $3 "|" $4 "|" k[2] "|" $5 "|" $6 }' "$EV" > /tmp/dash_today_all.txt
  while IFS='|' read -r mn al du lb sm; do
    if [ "$al" = 1 ]; then alld="$sm"; continue; fi
    s=$mn; e=$(( mn + du )); [ $e -le $s ] && e=$(( s + 30 ))
    [ $e -le $(( h0 * 60 )) ] || [ $s -ge $(( h1 * 60 )) ] && continue
    [ $s -lt $(( h0 * 60 )) ] && s=$(( h0 * 60 )); [ $e -gt $(( h1 * 60 )) ] && e=$(( h1 * 60 ))
    x0=$(( X + (s - h0 * 60) * BW / span )); x1=$(( X + (e - h0 * 60) * BW / span )); [ $(( x1 - x0 )) -lt 8 ] && x1=$(( x0 + 8 ))
    c=BLACK; [ $e -le $NOWMIN ] && c=GRAYA; [ $s -le $NOWMIN ] && [ $e -gt $NOWMIN ] && c=GRAY6
    rect $x0 $(( ly - 20 )) $(( x1 - x0 )) 40 $c
    if [ $x0 -ge $(( lastx + 10 )) ]; then
      tw2=$(( BW - (x0 - X) )); tx semi 18 $x0 $(( ly - 52 )) "$sm" l k $tw2
      lastx=$(( x0 + $(tw semi 18 "$sm") ))
    fi
  done < /tmp/dash_today_all.txt
  if [ $NOWMIN -ge $(( h0 * 60 )) ] && [ $NOWMIN -le $(( h1 * 60 )) ]; then
    nx=$(( X + (NOWMIN - h0 * 60) * BW / span ))
    rect $(( nx - 1 )) $(( ly - 34 )) 3 66 BLACK
    tx semi 14 $nx $(( ly + 34 )) "$(hm $NOWMIN)" c k
  fi
  y=$(( ly + 62 ))
  [ -n "$alld" ] && { tx reg 20 $X $y "Cả ngày: $alld" l m $BW; y=$(( y + 32 )); }
  if [ $(( Y0 + BH - y )) -ge 60 ]; then
    awk -F'|' -v TD="$TD" '$1 != TD' /tmp/dash_up2.txt > /tmp/dash_up3.txt; mv /tmp/dash_up3.txt /tmp/dash_up2.txt
    hl $(( y - 6 )) $X $(( X + BW )); ev_gon $X $(( y + 8 )) $BW $(( Y0 + BH - y - 8 ))
  fi
}

ev_sentence() { # câu văn: "Tối nay lúc 7 giờ, bạn có Night shift."
  X=$1; Y0=$2; BW=$3; BH=$4
  ev_find_now
  if [ -n "$NOWL" ]; then ev_split "$NOWL"; s1="Bây giờ bạn đang có"; s2="$E_SUM."
  elif [ -n "$NEXTL" ]; then ev_split "$NEXTL"
    hr=$(( E_MIN / 60 )); mi=$(( E_MIN % 60 )); h12=$(( hr % 12 )); [ $h12 = 0 ] && h12=12
    at="lúc $h12 giờ"; [ $mi -gt 0 ] && at="lúc $h12 giờ $mi"
    if [ $hr -lt 11 ]; then b="sáng"; elif [ $hr -lt 13 ]; then b="trưa"; elif [ $hr -lt 18 ]; then b="chiều"; else b="tối"; fi
    case "$b" in sáng) bn="Sáng" ;; trưa) bn="Trưa" ;; chiều) bn="Chiều" ;; *) bn="Tối" ;; esac
    if [ "$E_DAY" = "$TD" ]; then pre="$bn nay"
    elif [ "$E_DAY" = $(( TD + 1 )) ]; then pre="Ngày mai"; [ "$E_ALL" = 1 ] || at="$at $b"
    else pre="$(pick "$WD_LONG" $(( (E_DAY + 4) % 7 ))) ($(day_dm $E_DAY))"; [ "$E_ALL" = 1 ] || at="$at $b"; fi
    if [ "$E_ALL" = 1 ]; then [ "$E_DAY" = "$TD" ] && s1="Hôm nay là" || s1="$pre là"; else s1="$pre $at, bạn có"; fi
    s2="$E_SUM."
  else s1="Không có lịch hẹn nào"; s2="trong $DAYS_AHEAD ngày tới."; fi
  tx light 40 $X $Y0 "$s1" l k $BW
  txw semi 40 $X $(( Y0 + 52 )) "$s2" $BW $(( BH - 52 ))
}

# ======================= ẢNH =======================
photo_style() { s="$PHOTO_STYLE"; [ -z "$s" ] || [ "$s" = auto ] && s="${LAY_PHOTO:-tran}"; echo "$s"; }
photo_caption() { # tên file -> chú thích
  c=$(grep -F "$1|" "$DIR/photos/captions.txt" 2>/dev/null | head -1 | cut -d'|' -f2-)
  [ -n "$c" ] && { echo "$c"; return; }
  echo "${1%.png}" | sed 's/_[0-9]*$//; s/_/ /g'
}
# đường dẫn ảnh đúng cỡ (tools/prepare_photos.py tạo sẵn photos/v/RxC[m]/)
photo_variant() { # tên R C mặt_nạ -> đường dẫn hoặc rỗng
  f="$DIR/photos/v/${2}x${3}${4}/$1"; [ -f "$f" ] && echo "$f"
}
# w_photo X Y R C [mặt_nạ khung: r = bo góc (thẻ)]
w_photo() {
  X=$1; Y0=$2; BW=$3; BH=$4; mk=$5
  base=$(pick_photo ""); [ -n "$base" ] || { tx light 22 $(( X + 20 )) $(( Y0 + BH / 2 - 14 )) "Chưa có ảnh" l s; return 1; }
  nm=$(basename "$base"); cap=$(photo_caption "$nm")
  st=$(photo_style); tm=""; [ "$mk" = r ] && tm=t
  case "$st" in
    polaroid) iw=$(( BW - 28 )); ih=$(( BH - 72 )); m="" ;;
    tron) d=$BW; [ $BH -lt $d ] && d=$BH; iw=$(( d - 10 )); ih=$iw; m=c ;;
    nhan) iw=$BW; ih=$(( BH - 50 )); m=$tm ;;
    bia) iw=$BW; ih=$(( BH - 70 )); m=$tm ;;
    *) iw=$BW; ih=$BH; m=$mk ;;
  esac
  f=$(photo_variant "$nm" $iw $ih "$m")
  case "$st" in
    polaroid)
      hl $Y0 $X $(( X + BW )); hl $(( Y0 + BH - 1 )) $X $(( X + BW )); vl $X $Y0 $(( Y0 + BH )); vl $(( X + BW - 1 )) $Y0 $(( Y0 + BH ))
      [ -n "$f" ] && image "$f" $(( X + 14 )) $(( Y0 + 14 )) || image "$base" $(( X + 14 )) $(( Y0 + 14 ))
      tx light 22 $(( X + 16 )) $(( Y0 + BH - 50 )) "$cap" l k $(( BW - 32 )) ;;
    tron)
      [ -n "$f" ] || f="$base"
      image "$f" $(( X + (BW - iw) / 2 )) $(( Y0 + (BH - ih) / 2 )) ;;
    nhan)
      image "${f:-$base}" $X $Y0
      wd=$(pick "$WD_SHORT" "$(date +%w)")
      tx semi 22 $(( X + 14 )) $(( Y0 + ih + 12 )) "$wd · $(date +%d.%m)" l k
      tx light 20 $(( X + BW - 14 )) $(( Y0 + ih + 14 )) "$cap" r m $(( BW / 2 )) ;;
    bia)
      image "${f:-$base}" $X $Y0
      txcap light 30 $(( X + 14 )) $(( Y0 + ih + 20 )) "$D/$M" l k
      inf="$(pick "$WD_LONG" "$(date +%w)")"; [ -n "$WX_TEMP" ] && inf="$inf · ${WX_TEMP}°"
      dx=$(( $(tw light $(px_for_cap light 30) "$D/$M") + 34 ))
      twv light 18 "$cap"; cw_=$TWV; [ $cw_ -gt $(( BW / 3 )) ] && cw_=$(( BW / 3 ))
      tx reg 20 $(( X + dx )) $(( Y0 + ih + 24 )) "$inf" l m $(( BW - dx - cw_ - 30 ))
      tx light 18 $(( X + BW - 14 )) $(( Y0 + ih + 26 )) "$cap" r s $(( BW / 3 )) ;;
    *)
      if [ -n "$f" ]; then image "$f" $X $Y0
      else image "$base" $(( X + (BW - 298) / 2 )) $(( Y0 + (BH - 250) / 2 )); fi ;;
  esac
  PHOTO_CAP="$cap"
  return 0
}
