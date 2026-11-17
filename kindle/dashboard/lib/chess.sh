# Cờ vua trên Kindle: chơi với máy (Dễ/Vừa/Khó, cầm Trắng hoặc Đen) hoặc 2 người, hoàn tác, gợi ý,
# xoay bàn, xin thua, tự lưu ván. Luật + máy: lib/chess.awk. Mỗi chạm chỉ vẽ lại các ô thay đổi.
CH_SAVE="$DIR/chess.save"; CH_MODE=game
ch_glyph() { case "$1" in
  K) printf '\342\231\224' ;; Q) printf '\342\231\225' ;; R) printf '\342\231\226' ;; B) printf '\342\231\227' ;; N) printf '\342\231\230' ;; P) printf '\342\231\231' ;;
  k) printf '\342\231\232' ;; q) printf '\342\231\233' ;; r) printf '\342\231\234' ;; b) printf '\342\231\235' ;; n) printf '\342\231\236' ;; p) printf '\342\231\237' ;; esac; }
ch_geom() {
  if [ $W -gt $H ]; then SQ=84; BX=20; BY=72; CLAND=1; PX0=$(( BX + 8 * SQ + 24 )); PW=$(( W - PX0 - 20 ))
  else SQ=86; BX=$(( (W - 8 * SQ) / 2 )); BY=86; CLAND=0; PX0=$BX; PW=$(( 8 * SQ )); fi
}
ch_engine() { awk -v ACT="$1" -v ARG="${2:-0}" -v SAVE="$CH_SAVE" -v NMODE="$CH_NM" -v NLV="$CH_NL" -v NPC="$CH_NP" -f "$DIR/lib/chess.awk" > /tmp/dash_ch.out 2>>"$DIR/dash.log"; }
ch_open() { VIEW=chess; if [ -s "$CH_SAVE" ] && grep -q '^ST play' "$CH_SAVE"; then CH_MODE=game; else CH_MODE=menu; fi; }
ch_sq() { # ô_máy quân tối chọn đích cuối chiếu gợiý
  _d=$1; [ "$CH_FLIP" = 1 ] && _d=$(( 63 - $1 ))
  _x=$(( BX + (_d % 8) * SQ )); _y=$(( BY + (_d / 8) * SQ ))
  _bg=WHITE; [ "$3" = 1 ] && _bg=GRAYD
  [ "$6" = 1 ] && { [ "$3" = 1 ] && _bg=GRAYB || _bg=GRAYE; }
  [ "$7" = 1 ] && _bg=GRAY8
  rect $_x $_y $SQ $SQ $_bg
  [ "$4" = 1 ] && frame $_y $_x $SQ $SQ 6
  [ "$8" = 1 ] && { frame $(( _y + 2 )) $(( _x + 2 )) $(( SQ - 4 )) $(( SQ - 4 )) 3; frame $(( _y + 8 )) $(( _x + 8 )) $(( SQ - 16 )) $(( SQ - 16 )) 2; }
  if [ "$2" != . ]; then
    _px=$(( SQ * 80 * 2384 / 149600 ))
    tx chess $_px $(( _x + SQ / 2 - _px * 917 / 2384 )) $(( _y + SQ / 10 - _px * 405 / 2384 )) "$(ch_glyph "$2")" l k
  fi
  if [ "$5" = 1 ]; then
    if [ "$2" = . ]; then dot $(( _x + SQ / 2 )) $(( _y + SQ / 2 )) $(( SQ / 4 )) m
    else frame $(( _y + 3 )) $(( _x + 3 )) $(( SQ - 6 )) $(( SQ - 6 )) 4; fi
  fi
  [ $_x -lt $CRX0 ] && CRX0=$_x; [ $_y -lt $CRY0 ] && CRY0=$_y
  [ $(( _x + SQ )) -gt $CRX1 ] && CRX1=$(( _x + SQ )); [ $(( _y + SQ )) -gt $CRY1 ] && CRY1=$(( _y + SQ ))
}
ch_coords() { # chữ a-h, số 1-8 bên lề bàn
  _k=0
  while [ $_k -lt 8 ]; do
    _f=$_k; _rk=$(( 8 - _k )); [ "$CH_FLIP" = 1 ] && { _f=$(( 7 - _k )); _rk=$(( _k + 1 )); }
    _fl=$(echo abcdefgh | cut -c$(( _f + 1 )))
    tx reg 14 $(( BX + _k * SQ + SQ - 12 )) $(( BY + 8 * SQ - 20 )) "$_fl" l s
    tx reg 14 $(( BX + 3 )) $(( BY + _k * SQ + 2 )) "$_rk" l s
    _k=$(( _k + 1 ))
  done
}
ch_status_text() { # lượt trạngthái chiếu chếđộ mức màungười
  _who() { [ "$1" = w ] && echo "Trắng" || echo "Đen"; }
  case "$2" in
    play) if [ "$4" = ai ]; then [ "$1" = "$6" ] && _s="Lượt bạn ($(_who $1))" || _s="Máy đang nghĩ…"; else _s="Lượt $(_who $1)"; fi
          [ "$3" = 1 ] && _s="$_s · Chiếu!" ;;
    mate) _w=b; [ "$1" = b ] && _w=w; _s="Chiếu hết! $(_who $_w) thắng"; [ "$4" = ai ] && { [ "$_w" = "$6" ] && _s="Chiếu hết! Bạn thắng" || _s="Chiếu hết! Máy thắng"; } ;;
    stale) _s="Hết nước đi — hoà" ;; draw50) _s="Hoà (50 nước không ăn quân)" ;; draw3) _s="Hoà (lặp lại 3 lần)" ;; drawmat) _s="Hoà (không đủ quân để chiếu hết)" ;;
    resignw) _s="Trắng xin thua — Đen thắng" ;; resignb) _s="Đen xin thua — Trắng thắng" ;;
    *) _s="$2" ;;
  esac
  echo "$_s"
}
ch_level_name() { case "$1" in 1) echo "Dễ" ;; 2) echo "Vừa" ;; 3) echo "Khó" ;; esac; }
ch_panel() { # TOP: lượt trạngthái chiếu chếđộ mức màungười bịăn_trắng bịăn_đen lật [ghi đè trạng thái]
  CH_FLIP=$9; _st=$(ch_status_text "$1" "$2" "$3" "$4" "$5" "$6"); [ -n "${10}" ] && _st=${10}
  if [ $CLAND = 1 ]; then _sx=$PX0; _sy=$(( BY + 4 )); _sh=150; else _sx=$BX; _sy=$(( BY + 8 * SQ + 8 )); _sh=96; fi
  rect $_sx $_sy $PW $_sh WHITE
  tx semi 28 $_sx $(( _sy + 6 )) "$_st" l k $PW
  _cw=$7; _cb=$8; [ "$_cw" = - ] && _cw=""; [ "$_cb" = - ] && _cb=""
  _cx=$_sx; _cy=$(( _sy + 48 )); [ $CLAND = 1 ] && _cy=$(( _sy + 52 ))
  for _p in $(echo "$_cb" | sed 's/./& /g'); do tx chess 40 $_cx $(( _cy - 6 )) "$(ch_glyph "$(echo $_p | tr 'PNBRQ' 'pnbrq')")" l k; _cx=$(( _cx + 26 )); [ $_cx -gt $(( _sx + PW - 30 )) ] && { _cx=$_sx; _cy=$(( _cy + 34 )); }; done
  [ -n "$_cb" ] && { _cx=$(( _cx + 18 )); }
  for _p in $(echo "$_cw" | sed 's/./& /g'); do tx chess 40 $_cx $(( _cy - 6 )) "$(ch_glyph "$_p")" l k; _cx=$(( _cx + 26 )); [ $_cx -gt $(( _sx + PW - 30 )) ] && { _cx=$_sx; _cy=$(( _cy + 34 )); }; done
  refresh 0 "top=$_sy,left=$_sx,width=$PW,height=$_sh"
  CH_TOP="$*"
}
CH_BTNS="undo|$(printf '\357\203\242')|Hoàn tác
hint|$(printf '\357\203\253')|Gợi ý
flip|$(printf '\357\200\241')|Xoay bàn
resign|$(printf '\357\200\244')|Xin thua"
ch_buttons() {
  _i=0
  echo "$CH_BTNS" | while IFS='|' read -r _a _ic _lb; do
    if [ $CLAND = 1 ]; then _bw=$PW; _bh=88; _x=$PX0; _y=$(( BY + 170 + _i * (_bh + 10) ))
    else _bw=$(( PW / 4 )); _bh=$(( H - BY - 8 * SQ - 112 )); _x=$(( PX0 + _i * _bw )); _y=$(( BY + 8 * SQ + 108 )); fi
    rect $(( _x + 4 )) $_y $(( _bw - 8 )) $_bh WHITE; frame $_y $(( _x + 4 )) $(( _bw - 8 )) $_bh 2
    if [ $CLAND = 1 ]; then tx sym 36 $(( _x + 22 )) $(( _y + _bh / 2 - 22 )) "$_ic" l k; tx semi 26 $(( _x + 76 )) $(( _y + _bh / 2 - 18 )) "$_lb" l k
    else tx sym 40 $(( _x + _bw / 2 - 20 )) $(( _y + 10 )) "$_ic" l k; tx semi 22 $(( _x + _bw / 2 )) $(( _y + _bh - 38 )) "$_lb" c k $(( _bw - 16 )); fi
    _i=$(( _i + 1 ))
  done
}
ch_top() { # thanh trên
  rect 0 0 $W 76 WHITE
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Cờ vua" l k
  _m=$(sed -n 's/^MODE //p' "$CH_SAVE" 2>/dev/null); _l=$(sed -n 's/^LV //p' "$CH_SAVE" 2>/dev/null)
  [ "$_m" = ai ] && tx reg 20 210 30 "với máy · $(ch_level_name $_l)" l m; [ "$_m" = 2p ] && tx reg 20 210 30 "hai người" l m
  rect $(( W - 170 )) 14 140 50 BLACK; TXBG=BLACK; tx semi 22 $(( W - 100 )) 26 "Ván mới" c w; TXBG=""
}
ch_apply() { # vẽ theo /tmp/dash_ch.out; trả 0 nếu đến lượt máy
  CRX0=9999; CRY0=9999; CRX1=0; CRY1=0; _top=""; _ai=1
  _t=$(grep '^TOP ' /tmp/dash_ch.out); [ -n "$_t" ] && { set -- $_t; CH_FLIP=${10}; }
  while read -r _k _a _b _c _d _e _f _g _h; do
    case "$_k" in Q) ch_sq "$_a" "$_b" "$_c" "$_d" "$_e" "$_f" "$_g" "$_h" ;; AI) _ai=0 ;; esac
  done < /tmp/dash_ch.out
  [ $CRX1 -gt 0 ] && refresh 0 "top=$CRY0,left=$CRX0,width=$(( CRX1 - CRX0 )),height=$(( CRY1 - CRY0 ))"
  [ -n "$_t" ] && { set -- $_t; shift; ch_panel "$@"; }
  return $_ai
}
ch_ai_turn() { # máy đi (sau khi đã hiện nước của người)
  ch_engine ai; ch_apply
}
render_chess() {
  ch_geom
  "$FB" -q -b -k >/dev/null 2>&1
  [ "$CH_MODE" = menu ] && { render_chmenu; return; }
  DIFF_SAVE=$DIFF_DRAW; DIFF_DRAW=1
  ch_top; ch_engine full; ch_apply; _need=$?
  ch_coords; ch_buttons
  DIFF_DRAW=$DIFF_SAVE
  refresh 1
  [ $_need = 0 ] && ch_ai_turn
}
chess_tap() { # x y
  ch_geom; GAME_INCR=""
  [ "$CH_MODE" = menu ] && { chmenu_tap "$1" "$2"; return; }
  if [ $2 -le 78 ]; then
    if [ $1 -le 300 ]; then VIEW=games; elif [ $1 -ge $(( W - 180 )) ]; then CH_MODE=menu; fi
    return
  fi
  _act=""
  if [ $1 -ge $BX ] && [ $1 -lt $(( BX + 8 * SQ )) ] && [ $2 -ge $BY ] && [ $2 -lt $(( BY + 8 * SQ )) ]; then
    _d=$(( (($2 - BY) / SQ) * 8 + ($1 - BX) / SQ )); [ "$CH_FLIP" = 1 ] && _d=$(( 63 - _d )); _act=tap; _arg=$_d
  elif [ $CLAND = 1 ] && [ $1 -ge $PX0 ] && [ $2 -ge $(( BY + 170 )) ]; then
    _k=$(( ($2 - BY - 170) / 98 + 1 )); [ $_k -le 4 ] && _act=$(echo "$CH_BTNS" | sed -n "${_k}p" | cut -d'|' -f1)
  elif [ $CLAND = 0 ] && [ $2 -ge $(( BY + 8 * SQ + 104 )) ]; then
    _k=$(( ($1 - PX0) / (PW / 4) + 1 )); [ $_k -lt 1 ] && _k=1; [ $_k -gt 4 ] && _k=4; _act=$(echo "$CH_BTNS" | sed -n "${_k}p" | cut -d'|' -f1)
  fi
  [ -n "$_act" ] || { GAME_INCR=1; return; }
  if [ "$_act" = resign ] && [ "$CH_CONFIRM" != 1 ]; then
    CH_CONFIRM=1; set -- $(grep '^TOP' /tmp/dash_ch.out 2>/dev/null | cut -d' ' -f2-); [ $# -ge 9 ] && ch_panel "$@" "Chạm Xin thua lần nữa để xác nhận"; GAME_INCR=1; return
  fi
  CH_CONFIRM=0
  [ "$_act" = hint ] && { set -- $CH_TOP; [ $# -ge 9 ] && ch_panel $1 $2 $3 $4 $5 $6 $7 $8 $9 "Đang tìm nước hay…"; }
  ch_engine "$_act" "$_arg"
  if [ "$_act" = flip ]; then render_chess_board; GAME_INCR=1; return; fi
  ch_apply && ch_ai_turn
  GAME_INCR=1
}
render_chess_board() { # vẽ lại cả bàn (sau khi xoay)
  DIFF_SAVE=$DIFF_DRAW; DIFF_DRAW=1
  ch_engine full; ch_apply; rect $BX $(( BY + 8 * SQ )) $(( 8 * SQ )) 4 WHITE; ch_coords
  DIFF_DRAW=$DIFF_SAVE
  refresh 0 "top=$BY,left=$BX,width=$(( 8 * SQ )),height=$(( 8 * SQ ))"
}

# ---------- Chọn ván mới ----------
render_chmenu() {
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Cờ vua — ván mới" l k
  hl 76 40 $(( W - 40 )) BLACK 2
  _y=100
  if [ -s "$CH_SAVE" ] && grep -q '^ST play' "$CH_SAVE"; then
    rect 40 $_y $(( W - 80 )) 84 BLACK; TXBG=BLACK; tx semi 30 70 $(( _y + 22 )) "Tiếp tục ván đang chơi" l w; TXBG=""; _y=$(( _y + 104 ))
  fi
  CHM_Y=$_y
  [ -n "$CH_PCOL" ] || CH_PCOL=w
  tx reg 26 40 $(( _y + 18 )) "Bạn cầm quân" l k
  for _c in w b; do _bx=$(( W - 360 )); [ $_c = b ] && _bx=$(( W - 200 ))
    if [ "$CH_PCOL" = $_c ]; then rect $_bx $(( _y + 4 )) 150 60 BLACK; TXBG=BLACK; _cl=w; else frame $(( _y + 4 )) $_bx 150 60 2; TXBG=""; _cl=k; fi
    [ $_c = w ] && _t="Trắng" || _t="Đen"; tx semi 24 $(( _bx + 75 )) $(( _y + 20 )) "$_t" c $_cl; TXBG=""; done
  _y=$(( _y + 90 ))
  tx semi 22 40 $(( _y )) "CHƠI VỚI MÁY" l s; _y=$(( _y + 34 ))
  for _l in 1 2 3; do
    frame $_y 40 $(( W - 80 )) 96 2
    tx semi 36 70 $(( _y + 14 )) "$(ch_level_name $_l)" l k
    case $_l in 1) _d="Máy đi khá ngẫu hứng, hợp người mới" ;; 2) _d="Máy nhìn trước 2 nước" ;; 3) _d="Máy nhìn trước 3-4 nước, nghĩ lâu hơn" ;; esac
    tx reg 20 70 $(( _y + 60 )) "$_d" l m $(( W - 160 ))
    _y=$(( _y + 110 ))
  done
  CHM_2P=$_y
  frame $_y 40 $(( W - 80 )) 96 2; tx semi 36 70 $(( _y + 14 )) "Hai người" l k; tx reg 20 70 $(( _y + 60 )) "Hai người chơi trên cùng một Kindle" l m
  txw reg 20 40 $(( H - 110 )) "Chạm quân để chọn, chạm ô có chấm để đi. Tốt đến cuối bàn tự phong Hậu. Ván tự lưu." $(( W - 80 )) 100 m
  refresh 1
}
chmenu_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -le 300 ] && VIEW=games; return; fi
  if [ -s "$CH_SAVE" ] && grep -q '^ST play' "$CH_SAVE" && [ $2 -ge 100 ] && [ $2 -lt 184 ]; then CH_MODE=game; return; fi
  if [ $2 -ge $CHM_Y ] && [ $2 -lt $(( CHM_Y + 80 )) ]; then [ $1 -ge $(( W - 200 )) ] && CH_PCOL=b || { [ $1 -ge $(( W - 360 )) ] && CH_PCOL=w; }; return; fi
  _y=$(( CHM_Y + 124 ))
  for _l in 1 2 3; do
    if [ $2 -ge $_y ] && [ $2 -lt $(( _y + 96 )) ]; then CH_NM=ai; CH_NL=$_l; CH_NP=${CH_PCOL:-w}; ch_engine new; CH_MODE=game; log "cờ vua: ván mới với máy mức $_l, cầm $CH_NP"; return; fi
    _y=$(( _y + 110 ))
  done
  if [ $2 -ge $CHM_2P ] && [ $2 -lt $(( CHM_2P + 96 )) ]; then CH_NM=2p; CH_NL=2; CH_NP=w; ch_engine new; CH_MODE=game; log "cờ vua: ván mới hai người"; fi
}
