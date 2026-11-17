# Cờ vây trên Kindle: bàn 9×9 / 13×13 / 19×19, chơi 2 người hoặc với máy (mức tập chơi), bỏ lượt,
# hoàn tác, xin thua, đánh dấu quân chết, tính điểm theo luật Trung Quốc (komi 7 / 6,5). Luật: lib/go.awk.
GO_SAVE="$DIR/go.save"; GO_MODE=game
go_geom() {
  _n=$(sed -n 's/^N //p' "$GO_SAVE" 2>/dev/null); GN_=${_n:-9}
  if [ $W -gt $H ]; then GA=684; GBX=20; GBY=70; GLAND=1; GPX=$(( GBX + GA + 24 )); GPW=$(( W - GPX - 20 ))
  else GA=702; GBX=$(( (W - GA) / 2 )); GBY=84; GLAND=0; GPX=$GBX; GPW=$GA; fi
  GSP=$(( GA / GN_ ))
}
go_engine() { awk -v ACT="$1" -v ARG="${2:-0}" -v SAVE="$GO_SAVE" -v NN="$GO_NN" -v NMODE="$GO_NM" -v NPC="$GO_NP" -f "$DIR/lib/go.awk" > /tmp/dash_go.out 2>>"$DIR/dash.log"; }
go_open() { VIEW=go; if [ -s "$GO_SAVE" ] && grep -q '^PH play' "$GO_SAVE"; then GO_MODE=game; else GO_MODE=menu; fi; }
go_star() { # có phải điểm sao không
  case "$GN_" in 9) _s=" 2 4 6 " ;; 13) _s=" 3 6 9 " ;; *) _s=" 3 9 15 " ;; esac
  case "$_s" in *" $1 "*) case "$_s" in *" $2 "*) return 0 ;; esac ;; esac; return 1
}
go_pt() { # điểm quân nướccuối chết đất
  _r=$(( $1 / GN_ )); _c=$(( $1 % GN_ ))
  _x=$(( GBX + _c * GSP )); _y=$(( GBY + _r * GSP )); _cx=$(( _x + GSP / 2 )); _cy=$(( _y + GSP / 2 ))
  rect $_x $_y $GSP $GSP WHITE
  _l=$_x; _rr=$(( _x + GSP )); [ $_c = 0 ] && _l=$_cx; [ $_c = $(( GN_ - 1 )) ] && _rr=$(( _cx + 1 ))
  _t=$_y; _b=$(( _y + GSP )); [ $_r = 0 ] && _t=$_cy; [ $_r = $(( GN_ - 1 )) ] && _b=$(( _cy + 1 ))
  _lw=1; { [ $_r = 0 ] || [ $_r = $(( GN_ - 1 )) ]; } && _lw=2
  rect $_l $_cy $(( _rr - _l )) $_lw GRAY4
  _lw=1; { [ $_c = 0 ] || [ $_c = $(( GN_ - 1 )) ]; } && _lw=2
  rect $_cx $_t $_lw $(( _b - _t )) GRAY4
  [ "$2" = . ] && go_star $_r $_c && dot $_cx $_cy $(( GSP / 5 + 3 )) k
  _d=$(( GSP * 92 / 100 ))
  case "$2" in
    b) dot $_cx $_cy $_d k; [ "$3" = 1 ] && dot $_cx $_cy $(( GSP / 3 )) w ;;
    w) dot $_cx $_cy $_d w; ring $_cx $_cy $_d k; [ "$3" = 1 ] && dot $_cx $_cy $(( GSP / 3 )) k ;;
  esac
  if [ "$4" = 1 ]; then _cl=w; [ "$2" = w ] && _cl=k
    tx sym $(( GSP * 60 / 100 )) $(( _cx - GSP * 21 / 100 )) $(( _cy - GSP * 38 / 100 )) "$(printf '\357\200\215')" l $_cl; fi
  case "$5" in
    b) [ "$2" = . ] || [ "$4" = 1 ] && rect $(( _cx - GSP / 6 )) $(( _cy - GSP / 6 )) $(( GSP / 3 )) $(( GSP / 3 )) BLACK ;;
    w) if [ "$2" = . ] || [ "$4" = 1 ]; then rect $(( _cx - GSP / 6 )) $(( _cy - GSP / 6 )) $(( GSP / 3 )) $(( GSP / 3 )) WHITE; frame $(( _cy - GSP / 6 )) $(( _cx - GSP / 6 )) $(( GSP / 3 )) $(( GSP / 3 )) 2; fi ;;
  esac
  [ $_x -lt $GRX0 ] && GRX0=$_x; [ $_y -lt $GRY0 ] && GRY0=$_y
  [ $(( _x + GSP )) -gt $GRX1 ] && GRX1=$(( _x + GSP )); [ $(( _y + GSP )) -gt $GRY1 ] && GRY1=$(( _y + GSP ))
}
go_panel() { # lượt ăn_đen ăn_trắng giaiđoạn bỏlượt chếđộ màungười N kếtquả [thông báo]
  _who() { [ "$1" = b ] && echo "Đen" || echo "Trắng"; }
  _res=$(echo "$9" | tr '_' ' ')
  case "$4" in
    play) if [ "$6" = ai ]; then [ "$1" = "$7" ] && _st="Lượt bạn ($(_who $1))" || _st="Máy đang nghĩ…"; else _st="Lượt $(_who $1)"; fi
          [ "$5" = 1 ] && _st="$_st · đối phương vừa bỏ lượt" ;;
    score) _st="Tính điểm: chạm nhóm quân để đánh dấu chết/sống · tạm tính: $_res" ;;
    end) _st="Kết thúc: $_res" ;;
  esac
  [ -n "${10}" ] && _st=${10}
  if [ $GLAND = 1 ]; then _sx=$GPX; _sy=$(( GBY + 4 )); _sh=200; else _sx=$GBX; _sy=$(( GBY + GA + 8 )); _sh=90; fi
  rect $_sx $_sy $GPW $_sh WHITE
  txw semi 24 $_sx $(( _sy + 4 )) "$_st" $GPW 64
  tx reg 20 $_sx $(( _sy + _sh - 30 )) "Đen bắt $2 quân · Trắng bắt $3 quân · komi $([ "$8" = 9 ] && echo 7 || echo 6,5)" l m $GPW
  refresh 0 "top=$_sy,left=$_sx,width=$GPW,height=$_sh"
  GO_TOP="$1 $2 $3 $4 $5 $6 $7 $8 $9"; GO_PH=$4
}
go_buttons() { # theo giai đoạn
  case "$GO_PH" in
    play) GO_BTNS="pass|Bỏ lượt
undo|Hoàn tác
resign|Xin thua" ;;
    score) GO_BTNS="resume|Chơi tiếp
undo|Hoàn tác
finish|Tính điểm" ;;
    *) GO_BTNS="newgame|Ván mới" ;;
  esac
  _nb=$(echo "$GO_BTNS" | grep -c .)
  if [ $GLAND = 1 ]; then _y0=$(( GBY + 220 )); rect $GPX $_y0 $GPW $(( H - _y0 )) WHITE
  else _y0=$(( GBY + GA + 106 )); rect $GBX $_y0 $GA $(( H - _y0 )) WHITE; fi
  _i=0
  echo "$GO_BTNS" | while IFS='|' read -r _a _lb; do
    if [ $GLAND = 1 ]; then _bw=$GPW; _bh=96; _x=$GPX; _y=$(( _y0 + _i * 110 ))
    else _bw=$(( GA / _nb )); _bh=$(( H - _y0 - 10 )); _x=$(( GBX + _i * _bw )); _y=$_y0; fi
    if [ "$_a" = finish ] || [ "$_a" = newgame ]; then rect $(( _x + 4 )) $_y $(( _bw - 8 )) $_bh BLACK; TXBG=BLACK; _cl=w
    else rect $(( _x + 4 )) $_y $(( _bw - 8 )) $_bh WHITE; frame $_y $(( _x + 4 )) $(( _bw - 8 )) $_bh 2; _cl=k; fi
    tx semi 28 $(( _x + _bw / 2 )) $(( _y + _bh / 2 - 20 )) "$_lb" c $_cl $(( _bw - 16 )); TXBG=""
    _i=$(( _i + 1 ))
  done
  if [ $GLAND = 1 ]; then refresh 0 "top=$_y0,left=$GPX,width=$GPW,height=$(( H - _y0 ))"; else refresh 0 "top=$_y0,left=$GBX,width=$GA,height=$(( H - _y0 ))"; fi
}
go_apply() { # vẽ theo /tmp/dash_go.out; trả 0 nếu đến lượt máy
  GRX0=9999; GRY0=9999; GRX1=0; GRY1=0; _ai=1; _msg=""; _oph=$GO_PH
  while read -r _k _a _b _c _d _e; do
    case "$_k" in G) go_pt "$_a" "$_b" "$_c" "$_d" "$_e" ;; AI) _ai=0 ;; MSG) _msg="$_a $_b $_c $_d $_e" ;; esac
  done < /tmp/dash_go.out
  _msg=$(sed -n 's/^MSG //p' /tmp/dash_go.out)
  [ $GRX1 -gt 0 ] && refresh 0 "top=$GRY0,left=$GRX0,width=$(( GRX1 - GRX0 )),height=$(( GRY1 - GRY0 ))"
  _t=$(sed -n 's/^TOP //p' /tmp/dash_go.out); [ -n "$_t" ] && go_panel $_t "$_msg"
  [ "$_oph" != "$GO_PH" ] && go_buttons
  return $_ai
}
go_top() {
  rect 0 0 $W 74 WHITE
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Cờ vây ${GN_}×${GN_}" l k
  _m=$(sed -n 's/^MODE //p' "$GO_SAVE" 2>/dev/null); [ "$_m" = ai ] && tx reg 20 280 30 "với máy" l m; [ "$_m" = 2p ] && tx reg 20 280 30 "hai người" l m
  rect $(( W - 170 )) 14 140 50 BLACK; TXBG=BLACK; tx semi 22 $(( W - 100 )) 26 "Ván mới" c w; TXBG=""
}
render_go() {
  go_geom
  "$FB" -q -b -k >/dev/null 2>&1
  [ "$GO_MODE" = menu ] && { render_gomenu; return; }
  DIFF_SAVE=$DIFF_DRAW; DIFF_DRAW=1
  go_top; GO_PH=""; go_engine full; go_apply; _need=$?
  DIFF_DRAW=$DIFF_SAVE
  refresh 1
  [ $_need = 0 ] && { go_engine ai; go_apply; }
}
go_tap() { # x y
  go_geom; GAME_INCR=""
  [ "$GO_MODE" = menu ] && { gomenu_tap "$1" "$2"; return; }
  if [ $2 -le 76 ]; then
    if [ $1 -le 300 ]; then VIEW=games; elif [ $1 -ge $(( W - 180 )) ]; then GO_MODE=menu; fi
    return
  fi
  _act=""
  if [ $1 -ge $GBX ] && [ $1 -lt $(( GBX + GN_ * GSP )) ] && [ $2 -ge $GBY ] && [ $2 -lt $(( GBY + GN_ * GSP )) ]; then
    _p=$(( (($2 - GBY) / GSP) * GN_ + ($1 - GBX) / GSP )); [ "$GO_PH" = score ] && _act=dead || _act=play; _arg=$_p
  else
    _nb=$(echo "$GO_BTNS" | grep -c .)
    if [ $GLAND = 1 ] && [ $1 -ge $GPX ] && [ $2 -ge $(( GBY + 220 )) ]; then _k=$(( ($2 - GBY - 220) / 110 + 1 ))
    elif [ $GLAND = 0 ] && [ $2 -ge $(( GBY + GA + 100 )) ]; then _k=$(( ($1 - GBX) / (GA / _nb) + 1 )); else _k=0; fi
    [ $_k -ge 1 ] && [ $_k -le $_nb ] && _act=$(echo "$GO_BTNS" | sed -n "${_k}p" | cut -d'|' -f1)
  fi
  [ -n "$_act" ] || { GAME_INCR=1; return; }
  [ "$_act" = newgame ] && { GO_MODE=menu; return; }
  if [ "$_act" = resign ] && [ "$GO_CONFIRM" != 1 ]; then GO_CONFIRM=1; go_panel $GO_TOP "Chạm Xin thua lần nữa để xác nhận"; GAME_INCR=1; return; fi
  GO_CONFIRM=0
  go_engine "$_act" "$_arg"
  go_apply && { go_engine ai; go_apply; }
  GAME_INCR=1
}
render_gomenu() {
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Cờ vây — ván mới" l k
  hl 76 40 $(( W - 40 )) BLACK 2
  _y=100
  if [ -s "$GO_SAVE" ] && grep -q '^PH play' "$GO_SAVE"; then
    rect 40 $_y $(( W - 80 )) 84 BLACK; TXBG=BLACK; tx semi 30 70 $(( _y + 22 )) "Tiếp tục ván đang chơi" l w; TXBG=""; _y=$(( _y + 104 ))
  fi
  GOM_Y=$_y; [ -n "$GO_SIZE" ] || GO_SIZE=9; [ -n "$GO_PCOL" ] || GO_PCOL=b
  tx reg 26 40 $(( _y + 18 )) "Cỡ bàn" l k
  _bx=$(( W - 480 ))
  for _s in 9 13 19; do
    if [ "$GO_SIZE" = $_s ]; then rect $_bx $(( _y + 4 )) 140 60 BLACK; TXBG=BLACK; _cl=w; else frame $(( _y + 4 )) $_bx 140 60 2; _cl=k; fi
    tx semi 24 $(( _bx + 70 )) $(( _y + 20 )) "${_s}×${_s}" c $_cl; TXBG=""; _bx=$(( _bx + 150 ))
  done
  _y=$(( _y + 84 ))
  tx reg 26 40 $(( _y + 18 )) "Bạn cầm quân (khi chơi với máy)" l k $(( W - 420 ))
  for _c in b w; do _bx=$(( W - 330 )); [ $_c = w ] && _bx=$(( W - 180 ))
    if [ "$GO_PCOL" = $_c ]; then rect $_bx $(( _y + 4 )) 140 60 BLACK; TXBG=BLACK; _cl=w; else frame $(( _y + 4 )) $_bx 140 60 2; _cl=k; fi
    [ $_c = b ] && _t="Đen" || _t="Trắng"; tx semi 24 $(( _bx + 70 )) $(( _y + 20 )) "$_t" c $_cl; TXBG=""; done
  _y=$(( _y + 100 ))
  GOM_AI=$_y
  frame $_y 40 $(( W - 80 )) 100 2; tx semi 36 70 $(( _y + 14 )) "Chơi với máy" l k; tx reg 20 70 $(( _y + 62 )) "Máy mức tập chơi — hợp để làm quen luật" l m $(( W - 160 ))
  _y=$(( _y + 116 )); GOM_2P=$_y
  frame $_y 40 $(( W - 80 )) 100 2; tx semi 36 70 $(( _y + 14 )) "Hai người" l k; tx reg 20 70 $(( _y + 62 )) "Hai người chơi trên cùng một Kindle" l m
  txw reg 20 40 $(( H - 150 )) "Đen đi trước. Bao vây hết khí thì ăn quân. Hai bên cùng bỏ lượt thì sang tính điểm: chạm nhóm quân chết để đánh dấu, rồi chạm Tính điểm (quân + đất, Trắng được cộng komi)." $(( W - 80 )) 140 m
  refresh 1
}
gomenu_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -le 300 ] && VIEW=games; return; fi
  if [ -s "$GO_SAVE" ] && grep -q '^PH play' "$GO_SAVE" && [ $2 -ge 100 ] && [ $2 -lt 184 ]; then GO_MODE=game; return; fi
  if [ $2 -ge $GOM_Y ] && [ $2 -lt $(( GOM_Y + 76 )) ] && [ $1 -ge $(( W - 480 )) ]; then
    _k=$(( ($1 - W + 480) / 150 )); case $_k in 0) GO_SIZE=9 ;; 1) GO_SIZE=13 ;; *) GO_SIZE=19 ;; esac; return; fi
  if [ $2 -ge $(( GOM_Y + 84 )) ] && [ $2 -lt $(( GOM_Y + 160 )) ] && [ $1 -ge $(( W - 330 )) ]; then
    [ $1 -ge $(( W - 180 )) ] && GO_PCOL=w || GO_PCOL=b; return; fi
  if [ $2 -ge $GOM_AI ] && [ $2 -lt $(( GOM_AI + 100 )) ]; then GO_NN=${GO_SIZE:-9}; GO_NM=ai; GO_NP=${GO_PCOL:-b}; go_engine new; GO_MODE=game; log "cờ vây: ván mới ${GO_NN}x${GO_NN} với máy"; return; fi
  if [ $2 -ge $GOM_2P ] && [ $2 -lt $(( GOM_2P + 100 )) ]; then GO_NN=${GO_SIZE:-9}; GO_NM=2p; GO_NP=b; go_engine new; GO_MODE=game; log "cờ vây: ván mới ${GO_NN}x${GO_NN} hai người"; fi
}
