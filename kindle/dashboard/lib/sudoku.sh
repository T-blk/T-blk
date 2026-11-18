# Sudoku trên Kindle: 4 độ khó, ghi chú (bút chì), xoá, hoàn tác, gợi ý, kiểm tra lỗi, báo lỗi ngay,
# tô sáng các ô cùng số, đếm số còn lại, đồng hồ, lưu ván tự động, kỷ lục từng độ khó.
# Bộ máy luật chơi: lib/sudoku.awk (1 lần gọi mỗi chạm). Chỉ vẽ lại đúng các ô thay đổi.
SU_SAVE="$DIR/sudoku.save"; SU_STATS="$DIR/sudoku.stats"; SU_UNDO=/tmp/dash_sudoku.undo; SU_BANK="$DIR/lib/sudoku.txt"
SU_MODE=game
su_level_name() { case "$1" in 1) echo "Dễ" ;; 2) echo "Vừa" ;; 3) echo "Khó" ;; 4) echo "Rất khó" ;; esac; }
su_fmt() { _m=$(( $1 / 60 )); if [ $_m -ge 60 ]; then echo "$(( _m / 60 )) giờ $(( _m % 60 )) phút"; else echo "$_m phút"; fi; }

su_geom() {
  if [ $W -gt $H ]; then             # NGANG: lưới bên trái, bàn phím số + công cụ bên phải
    CS=72; GX=24; GY=74; LAND=1
    PX0=$(( GX + 9 * CS + 24 )); PBW=$(( (W - PX0 - 24) / 3 )); PBH=86; PY0=$GY
    TX0=$PX0; TY0=$(( PY0 + 3 * PBH + 14 )); TBW=$(( W - PX0 - 24 )); TBH=$(( (H - TY0 - 10) / 5 ))
  else                               # DỌC: lưới trên, hàng số 1-9, hàng công cụ
    CS=78; GX=$(( (W - 9 * CS) / 2 )); GY=92; LAND=0
    PX0=$GX; PBW=$CS; PBH=84; PY0=$(( GY + 9 * CS + 16 ))
    TX0=$GX; TY0=$(( PY0 + PBH + 12 )); TBW=$(( 9 * CS / 5 )); TBH=$(( H - TY0 - 8 ))
  fi
}
su_open() { # vào Sudoku: tiếp tục ván đang chơi, hoặc chọn độ khó
  VIEW=sudoku; SU_T0=$(date +%s)
  if [ -s "$SU_SAVE" ] && grep -q '^DONE 0' "$SU_SAVE"; then SU_MODE=game; else SU_MODE=menu; fi
}
su_elapsed() { _t=$(sed -n 's/^T //p' "$SU_SAVE" 2>/dev/null); echo $(( ${_t:-0} + $(date +%s) - ${SU_T0:-$(date +%s)} )); }
su_leave() { # rời màn hình: lưu thời gian đã chơi
  [ "$SU_MODE" = game ] && [ -s "$SU_SAVE" ] && { _e=$(su_elapsed); sed -i "s/^T .*/T $_e/" "$SU_SAVE" 2>/dev/null; }
  SU_T0=""
}
su_engine() { # hành_động [tham_số] -> /tmp/dash_su.out
  _now=$(su_elapsed); SU_T0=$(date +%s)
  awk -v ACT="$1" -v ARG="${2:-0}" -v NOWT="$_now" -v SAVE="$SU_SAVE" -v UNDO="$SU_UNDO" \
      -v NEWL="$SU_NL" -v NEWP="$SU_NP" -v NEWS="$SU_NS" -v SEED="$SU_SEED" -f "$DIR/lib/sudoku.awk" > /tmp/dash_su.out 2>>"$DIR/dash.log"
}
su_new() { # mức -> ván mới (đề lấy ngẫu nhiên trong kho, rồi xáo trộn)
  SU_SEED=$(( $(date +%s) + $$ ))
  set -- $(awk -F'|' -v L="$1" -v R="$SU_SEED" '$1 == L { a[++n] = $2 " " $3 } END { srand(R); if (n) print a[int(rand() * n) + 1] }' "$SU_BANK")
  [ -n "$2" ] || { log "sudoku: không có đề mức $1"; return 1; }
  SU_NL=$SU_LV_PICK; SU_NP=$1; SU_NS=$2; rm -f "$SU_UNDO"; SU_T0=$(date +%s)
  su_engine new; SU_NP=""; SU_NS=""; SU_MODE=game
  log "sudoku: ván mới mức $SU_LV_PICK"
}

# ---------- Vẽ ----------
su_cell() { # ô nền số kiểu ghi_chú lỗi
  _r=$(( $1 / 9 )); _c=$(( $1 % 9 )); _x=$(( GX + _c * CS )); _y=$(( GY + _r * CS ))
  case "$2" in s) _bg=GRAYD ;; h) _bg=GRAYE ;; *) _bg=WHITE ;; esac
  [ "$6" = 1 ] && _bg=BLACK
  rect $(( _x + 3 )) $(( _y + 3 )) $(( CS - 5 )) $(( CS - 5 )) $_bg
  [ "$2" = s ] && [ "$6" != 1 ] && frame $(( _y + 3 )) $(( _x + 3 )) $(( CS - 5 )) $(( CS - 5 )) 4     # ô đang chọn: viền đậm
  TXBG=$_bg; [ "$_bg" = WHITE ] && TXBG=""
  if [ "$3" != 0 ]; then
    _col=k; [ "$6" = 1 ] && _col=w
    if [ "$4" = g ]; then txcap bold $(( CS * 44 / 100 )) $(( _x + CS / 2 + 1 )) $(( _y + CS * 28 / 100 )) "$3" c $_col
    else txcap light $(( CS * 44 / 100 )) $(( _x + CS / 2 + 1 )) $(( _y + CS * 28 / 100 )) "$3" c $_col; fi
    [ "$6" = 1 ] && [ "$2" = s ] && { rect $(( _x + 6 )) $(( _y + CS - 12 )) $(( CS - 11 )) 4 WHITE; }   # ô lỗi đang chọn: gạch trắng
  elif [ "$5" != 0 ]; then
    # LƯU Ý: không dùng tên biến ngắn kiểu _n ở đây — các hàm vẽ chữ (tx -> twv -> tw_sh) cũng dùng _n, _c, _r, _s…
    # và shell không có biến cục bộ, nên sẽ bị ghi đè giữa vòng lặp (ghi chú hiện sai số).
    SU_NBITS=$5; SU_ND=1; _sw=$(( CS / 3 )); SU_CX=$_x; SU_CY=$_y
    while [ $SU_NBITS -gt 0 ] && [ $SU_ND -le 9 ]; do
      if [ $(( SU_NBITS % 2 )) = 1 ]; then
        txcap semi $(( CS * 17 / 100 )) $(( SU_CX + 2 + ((SU_ND - 1) % 3) * (CS / 3) + CS / 6 )) $(( SU_CY + 7 + ((SU_ND - 1) / 3) * (CS / 3) )) "$SU_ND" c k
      fi
      SU_NBITS=$(( SU_NBITS / 2 )); SU_ND=$(( SU_ND + 1 ))
    done
    _x=$SU_CX; _y=$SU_CY
  fi
  TXBG=""
  # vùng cần làm mới
  [ $_x -lt $SU_RX0 ] && SU_RX0=$_x; [ $_y -lt $SU_RY0 ] && SU_RY0=$_y
  [ $(( _x + CS )) -gt $SU_RX1 ] && SU_RX1=$(( _x + CS )); [ $(( _y + CS )) -gt $SU_RY1 ] && SU_RY1=$(( _y + CS ))
}
su_grid() { # đường kẻ: mảnh giữa các ô, dày giữa các khối 3x3
  _k=0
  while [ $_k -le 9 ]; do
    if [ $(( _k % 3 )) = 0 ]; then
      rect $(( GX + _k * CS - 1 )) $(( GY - 1 )) 4 $(( 9 * CS + 3 )) BLACK; rect $(( GX - 1 )) $(( GY + _k * CS - 1 )) $(( 9 * CS + 3 )) 4 BLACK
    else
      rect $(( GX + _k * CS )) $GY 1 $(( 9 * CS )) GRAY8; rect $GX $(( GY + _k * CS )) $(( 9 * CS )) 1 GRAY8
    fi
    _k=$(( _k + 1 ))
  done
}
su_pad() { # c1..c9: số lượng đã điền mỗi chữ số -> nút số (chữ số đã đủ 9 thì mờ đi)
  _d=1
  for _cn in "$@"; do
    if [ $LAND = 1 ]; then _x=$(( PX0 + ((_d - 1) % 3) * PBW )); _y=$(( PY0 + ((_d - 1) / 3) * PBH ))
    else _x=$(( PX0 + (_d - 1) * PBW )); _y=$PY0; fi
    rect $(( _x + 3 )) $(( _y + 3 )) $(( PBW - 6 )) $(( PBH - 6 )) WHITE
    frame $(( _y + 3 )) $(( _x + 3 )) $(( PBW - 6 )) $(( PBH - 6 )) 2
    if [ "$_cn" -ge 9 ]; then txcap reg 30 $(( _x + PBW / 2 )) $(( _y + 16 )) "$_d" c h
    else
      _f=semi; [ "$SU_NM" = 1 ] && _f=light
      txcap $_f 34 $(( _x + PBW / 2 )) $(( _y + 14 )) "$_d" c k
      tx reg 14 $(( _x + PBW / 2 )) $(( _y + PBH - 26 )) "còn $(( 9 - _cn ))" c s
    fi
    _d=$(( _d + 1 ))
  done
  if [ $LAND = 1 ]; then refresh 0 "top=$PY0,left=$PX0,width=$(( 3 * PBW )),height=$(( 3 * PBH ))"
  else refresh 0 "top=$PY0,left=$PX0,width=$(( 9 * PBW )),height=$PBH"; fi
}
SU_TOOLS="note|$(printf '\357\201\200')|Ghi chú
erase|$(printf '\357\204\255')|Xoá
undo|$(printf '\357\203\242')|Hoàn tác
hint|$(printf '\357\203\253')|Gợi ý
check|$(printf '\357\200\214')|Kiểm tra"
su_tools() {
  _i=0
  echo "$SU_TOOLS" | while IFS='|' read -r _a _ic _lb; do
    if [ $LAND = 1 ]; then _x=$TX0; _y=$(( TY0 + _i * TBH )); _w=$TBW; _h=$TBH
    else _x=$(( TX0 + _i * TBW )); _y=$TY0; _w=$TBW; _h=$TBH; fi
    _on=0; [ "$_a" = note ] && [ "$SU_NM" = 1 ] && _on=1
    if [ $_on = 1 ]; then rect $(( _x + 4 )) $(( _y + 4 )) $(( _w - 8 )) $(( _h - 8 )) BLACK; _c=w; TXBG=BLACK
    else rect $(( _x + 4 )) $(( _y + 4 )) $(( _w - 8 )) $(( _h - 8 )) WHITE; frame $(( _y + 4 )) $(( _x + 4 )) $(( _w - 8 )) $(( _h - 8 )) 2; _c=k; TXBG=""; fi
    _lab=$_lb; [ "$_a" = note ] && { [ $_on = 1 ] && _lab="Ghi chú: Bật" || _lab="Ghi chú: Tắt"; }
    if [ $LAND = 1 ]; then
      tx sym 40 $(( _x + 18 )) $(( _y + _h / 2 - 24 )) "$_ic" l $_c; tx semi 24 $(( _x + 70 )) $(( _y + _h / 2 - 16 )) "$_lab" l $_c $(( _w - 80 ))
    else
      tx sym 46 $(( _x + _w / 2 - 23 )) $(( _y + 8 )) "$_ic" l $_c
      tx semi 19 $(( _x + _w / 2 )) $(( _y + _h - 34 )) "$_lab" c $_c $(( _w - 12 ))
    fi
    TXBG=""; _i=$(( _i + 1 ))
  done
  if [ $LAND = 1 ]; then refresh 0 "top=$TY0,left=$TX0,width=$TBW,height=$(( 5 * TBH ))"
  else refresh 0 "top=$TY0,left=$TX0,width=$(( 5 * TBW )),height=$TBH"; fi
}
su_top() { # lỗi gợi_ý ghi_chú báo_lỗi mức
  SU_MIS=$1; SU_HIN=$2; SU_NM=$3; SU_AUTO=$4; SU_LV=$5
  rect 0 0 $W 78 WHITE
  tx sym 34 30 18 "$I_LEFT" l k
  tx semi 30 74 20 "Sudoku · $(su_level_name $SU_LV)" l k
  _info="$(su_fmt $(su_elapsed))"; [ "$SU_AUTO" = 1 ] && _info="$_info · lỗi $SU_MIS"; [ "$SU_HIN" -gt 0 ] && _info="$_info · gợi ý $SU_HIN"
  tx reg 20 $(( W - 190 )) 30 "$_info" r m 300
  rect $(( W - 170 )) 14 140 50 BLACK; TXBG=BLACK; tx semi 22 $(( W - 100 )) 26 "Ván mới" c w; TXBG=""
  refresh 0 "top=0,left=0,width=$W,height=78"
}
su_apply() { # vẽ theo /tmp/dash_su.out
  SU_RX0=9999; SU_RY0=9999; SU_RX1=0; SU_RY1=0; _pad=""; _top=""; _win=""
  while read -r _t _a _b _c _d _e _f _g _h _i; do
    case "$_t" in
      C) su_cell "$_a" "$_b" "$_c" "$_d" "$_e" "$_f" ;;
      PAD) _pad="$_a $_b $_c $_d $_e $_f $_g $_h $_i" ;;
      TOP) _top="$_a $_b $_c $_d $_e" ;;
      WIN) _win="$_a $_b $_c $_d" ;;
    esac
  done < /tmp/dash_su.out
  [ $SU_RX1 -gt 0 ] && refresh 0 "top=$SU_RY0,left=$SU_RX0,width=$(( SU_RX1 - SU_RX0 )),height=$(( SU_RY1 - SU_RY0 ))"
  if [ -n "$_top" ]; then _onm=$SU_NM; su_top $_top; [ "$_onm" != "$SU_NM" ] && su_tools; fi
  [ -n "$_pad" ] && su_pad $_pad
  [ -n "$_win" ] && { su_win $_win; return 1; }
  return 0
}
su_win() { # giây lỗi gợi_ý mức -> lưu kỷ lục, hiện chúc mừng
  SU_MODE=win; set -- "$@"
  _best=$(awk -v L="$4" '$1 == L { print $2 }' "$SU_STATS" 2>/dev/null); _cnt=$(awk -v L="$4" '$1 == L { print $3 }' "$SU_STATS" 2>/dev/null)
  _rec=0; { [ -z "$_best" ] || [ "$1" -lt "$_best" ]; } && [ "$3" = 0 ] && { _best=$1; _rec=1; }
  { grep -v "^$4 " "$SU_STATS" 2>/dev/null; echo "$4 ${_best:-0} $(( ${_cnt:-0} + 1 ))"; } > "$SU_STATS.tmp"; mv "$SU_STATS.tmp" "$SU_STATS"
  _bx=$(( W / 2 - 280 )); _by=$(( GY + 9 * CS / 2 - 170 ))
  rect $_bx $_by 560 340 WHITE; frame $_by $_bx 560 340 5
  tx sym 64 $(( W / 2 - 32 )) $(( _by + 24 )) "$(printf '\357\202\221')" l k
  tx bold 44 $(( W / 2 )) $(( _by + 104 )) "Hoàn thành!" c k
  tx reg 24 $(( W / 2 )) $(( _by + 170 )) "$(su_level_name $4) · $(su_fmt $1) · lỗi $2 · gợi ý $3" c m 520
  if [ $_rec = 1 ]; then tx semi 24 $(( W / 2 )) $(( _by + 214 )) "Kỷ lục mới!" c k
  elif [ -n "$_best" ] && [ "$_best" -gt 0 ]; then tx reg 22 $(( W / 2 )) $(( _by + 214 )) "Kỷ lục: $(su_fmt $_best)" c m; fi
  tx reg 22 $(( W / 2 )) $(( _by + 276 )) "Chạm để chơi ván mới" c s
  refresh 1 "top=$_by,left=$_bx,width=560,height=340"
  log "sudoku: thắng mức $4 trong $1 giây (lỗi $2, gợi ý $3)"
}
render_sudoku() {
  su_geom
  "$FB" -q -b -k >/dev/null 2>&1
  [ "$SU_MODE" = win ] && SU_MODE=menu
  if [ "$SU_MODE" = menu ]; then render_sumenu; return; fi
  su_grid
  DIFF_SAVE=$DIFF_DRAW; DIFF_DRAW=1          # vẽ hết rồi làm mới 1 lần (nháy) cho sạch
  su_engine full
  su_apply
  DIFF_DRAW=$DIFF_SAVE
  su_tools_fill
  refresh 1
}
su_tools_fill() { DIFF_SAVE2=$DIFF_DRAW; DIFF_DRAW=1; su_tools; DIFF_DRAW=$DIFF_SAVE2; }

# ---------- Màn hình chọn độ khó ----------
render_sumenu() {
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Sudoku" l k
  hl 76 40 $(( W - 40 )) BLACK 2
  _y=104
  if [ -s "$SU_SAVE" ] && grep -q '^DONE 0' "$SU_SAVE"; then
    _l=$(sed -n 's/^L //p' "$SU_SAVE"); _t=$(sed -n 's/^T //p' "$SU_SAVE")
    rect 40 $_y $(( W - 80 )) 96 BLACK; TXBG=BLACK
    tx semi 32 70 $(( _y + 14 )) "Tiếp tục ván đang chơi" l w; tx reg 20 70 $(( _y + 58 )) "$(su_level_name $_l) · đã chơi $(su_fmt ${_t:-0})" l w
    TXBG=""; _y=$(( _y + 116 ))
  fi
  SU_MENU_Y=$_y
  tx semi 22 40 $(( _y + 4 )) "VÁN MỚI — CHỌN ĐỘ KHÓ" l s; _y=$(( _y + 40 ))
  for _l in 1 2 3 4; do
    frame $_y 40 $(( W - 80 )) 104 2
    tx semi 38 70 $(( _y + 16 )) "$(su_level_name $_l)" l k
    case $_l in 1) _d="Nhiều số cho sẵn, hợp để thư giãn" ;; 2) _d="Cần để ý hàng, cột và khối" ;; 3) _d="Cần ghi chú và suy luận" ;; 4) _d="Ít số cho sẵn nhất" ;; esac
    tx reg 20 70 $(( _y + 66 )) "$_d" l m $(( W - 340 ))
    _b=$(awk -v L="$_l" '$1 == L { print $2 " " $3 }' "$SU_STATS" 2>/dev/null)
    if [ -n "$_b" ]; then set -- $_b; _s="thắng $2 ván"; [ "$1" -gt 0 ] && _s="kỷ lục $(su_fmt $1) · $_s"; tx reg 18 $(( W - 70 )) $(( _y + 42 )) "$_s" r s 260; fi
    _y=$(( _y + 120 ))
  done
  _au=$(sed -n 's/^AUTO //p' "$SU_SAVE" 2>/dev/null); [ -n "$_au" ] || _au=1
  SU_AUTO_Y=$_y
  tx reg 26 40 $(( _y + 20 )) "Báo lỗi ngay khi điền sai" l k
  if [ "$_au" = 1 ]; then rect $(( W - 200 )) $(( _y + 8 )) 160 56 BLACK; TXBG=BLACK; tx semi 24 $(( W - 120 )) $(( _y + 22 )) "Bật" c w; TXBG=""
  else frame $(( _y + 8 )) $(( W - 200 )) 160 56 2; tx semi 24 $(( W - 120 )) $(( _y + 22 )) "Tắt" c k; fi
  txw reg 20 40 $(( H - 130 )) "Cách chơi: chạm một ô, rồi chạm số bên dưới. Bật Ghi chú để ghi số nháp nhỏ. Chạm lại đúng số đó để xoá. Ván tự lưu, thoát ra vẫn chơi tiếp được." $(( W - 80 )) 120 m
  refresh 1
}
sumenu_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -le 260 ] && { VIEW=games; }; return; fi
  if [ -s "$SU_SAVE" ] && grep -q '^DONE 0' "$SU_SAVE" && [ $2 -ge 104 ] && [ $2 -lt 200 ]; then SU_MODE=game; SU_T0=$(date +%s); return; fi
  _y=$(( SU_MENU_Y + 40 ))
  for _l in 1 2 3 4; do
    if [ $2 -ge $_y ] && [ $2 -lt $(( _y + 104 )) ]; then
      "$FB" -q -c -m -M -t "regular=$BOLD,px=36" "Đang tạo ván $(su_level_name $_l)…" >/dev/null 2>&1
      SU_LV_PICK=$_l; su_new $_l; return
    fi
    _y=$(( _y + 120 ))
  done
  [ $2 -ge $SU_AUTO_Y ] && [ $2 -lt $(( SU_AUTO_Y + 80 )) ] && su_engine auto
}

# ---------- Chạm ----------
sudoku_tap() { # x y -> GAME_INCR=1 nếu đã tự vẽ phần thay đổi (vòng lặp chính khỏi vẽ lại cả màn hình)
  su_geom; GAME_INCR=""
  case "$SU_MODE" in
    menu) sumenu_tap "$1" "$2"; return ;;
    win) SU_MODE=menu; return ;;
  esac
  if [ $2 -le 80 ]; then
    if [ $1 -le 300 ]; then su_leave; VIEW=games
    elif [ $1 -ge $(( W - 180 )) ]; then su_leave; SU_MODE=menu; fi
    return
  fi
  _act=""
  if [ $1 -ge $GX ] && [ $1 -lt $(( GX + 9 * CS )) ] && [ $2 -ge $GY ] && [ $2 -lt $(( GY + 9 * CS )) ]; then
    _act=sel; _arg=$(( (($2 - GY) / CS) * 9 + ($1 - GX) / CS ))
  elif [ $LAND = 1 ] && [ $1 -ge $PX0 ] && [ $2 -ge $PY0 ] && [ $2 -lt $(( PY0 + 3 * PBH )) ]; then
    _cc=$(( ($1 - PX0) / PBW )); [ $_cc -gt 2 ] && _cc=2; _act=num; _arg=$(( (($2 - PY0) / PBH) * 3 + _cc + 1 ))
  elif [ $LAND = 0 ] && [ $2 -ge $PY0 ] && [ $2 -lt $(( PY0 + PBH + 6 )) ]; then
    _cc=$(( ($1 - PX0) / PBW )); [ $_cc -lt 0 ] && _cc=0; [ $_cc -gt 8 ] && _cc=8; _act=num; _arg=$(( _cc + 1 ))
  elif [ $LAND = 1 ] && [ $1 -ge $TX0 ] && [ $2 -ge $TY0 ]; then
    _k=$(( ($2 - TY0) / TBH + 1 )); _act=$(echo "$SU_TOOLS" | sed -n "${_k}p" | cut -d'|' -f1)
  elif [ $LAND = 0 ] && [ $2 -ge $TY0 ]; then
    _k=$(( ($1 - TX0) / TBW + 1 )); [ $_k -lt 1 ] && _k=1; [ $_k -gt 5 ] && _k=5; _act=$(echo "$SU_TOOLS" | sed -n "${_k}p" | cut -d'|' -f1)
  fi
  [ -n "$_act" ] || { GAME_INCR=1; return; }
  su_engine "$_act" "$_arg"
  su_apply; GAME_INCR=1
}
su_tick() { # mỗi vòng lặp khi đang chơi: cập nhật dòng thời gian (chỉ vùng chữ nhỏ)
  [ "$SU_MODE" = game ] || return 0
  su_geom
  _m=$(( $(su_elapsed) / 60 )); [ "$_m" = "$SU_LASTM" ] && return 0; SU_LASTM=$_m
  set -- $(awk '$1 == "MIS" { m = $2 } $1 == "HIN" { h = $2 } $1 == "NM" { n = $2 } $1 == "AUTO" { a = $2 } $1 == "L" { l = $2 } END { print m + 0, h + 0, n + 0, a + 0, l + 0 }' "$SU_SAVE")
  su_top "$@"
}
