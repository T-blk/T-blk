# Trang "Trò chơi": Sudoku · Cờ vua · Cờ vây (mỗi trò tự lưu ván đang chơi)
. "$DIR/lib/sudoku.sh"
. "$DIR/lib/chess.sh"
. "$DIR/lib/go.sh"
render_games() {
  "$FB" -q -b -k >/dev/null 2>&1
  tx sym 34 30 18 "$I_LEFT" l k; tx semi 30 74 20 "Trò chơi" l k
  hl 76 40 $(( W - 40 )) BLACK 2
  GM_H=$(( (H - 120) / 3 )); [ $GM_H -gt 240 ] && GM_H=240
  _i=0
  for _g in sudoku chess go; do
    _y=$(( 100 + _i * (GM_H + 16) )); GM_Y=$_y
    frame $_y 40 $(( W - 80 )) $GM_H 3
    case $_g in
      sudoku) _ic=$(printf '\357\200\212'); GM_T="Sudoku"; GM_D="Dễ · Vừa · Khó · Rất khó — ghi chú, gợi ý, kỷ lục"
              GM_S=""; [ -s "$SU_SAVE" ] && grep -q '^DONE 0' "$SU_SAVE" && GM_S="Đang có ván dở — chạm để chơi tiếp" ;;
      chess)  _ic=""; GM_T="Cờ vua"; GM_D="Chơi với máy (Dễ · Vừa · Khó) hoặc hai người"
              GM_S=""; [ -s "$CH_SAVE" ] && grep -q '^ST play' "$CH_SAVE" && GM_S="Đang có ván dở — chạm để chơi tiếp" ;;
      go)     _ic=""; GM_T="Cờ vây"; GM_D="Bàn 9×9 · 13×13 · 19×19, hai người hoặc với máy"
              GM_S=""; [ -s "$GO_SAVE" ] && grep -q '^PH play' "$GO_SAVE" && GM_S="Đang có ván dở — chạm để chơi tiếp" ;;
    esac
    _ix=70; _iy=$(( GM_Y + GM_H / 2 - 50 ))
    case $_g in
      sudoku) tx sym 90 $_ix $(( _iy - 4 )) "$_ic" l k ;;
      chess) tx chess 130 $(( _ix - 10 )) $(( _iy - 26 )) "$(ch_glyph n)" l k ;;
      go) dot $(( _ix + 34 )) $(( _iy + 34 )) 60 k; dot $(( _ix + 70 )) $(( _iy + 70 )) 60 w; ring $(( _ix + 70 )) $(( _iy + 70 )) 60 k ;;
    esac
    tx semi 44 210 $(( GM_Y + GM_H / 2 - 62 )) "$GM_T" l k
    txw reg 22 210 $(( GM_Y + GM_H / 2 - 2 )) "$GM_D" $(( W - 290 )) 64 m
    [ -n "$GM_S" ] && tx semi 20 210 $(( GM_Y + GM_H - 42 )) "$GM_S" l k $(( W - 290 ))
    _i=$(( _i + 1 ))
  done
  refresh 1
}
games_tap() { # x y
  if [ $2 -le 80 ]; then [ $1 -le 300 ] && VIEW=main; return; fi
  _k=$(( ($2 - 100) / (GM_H + 16) ))
  case $_k in 0) su_open ;; 1) ch_open ;; 2) go_open ;; esac
}
