# Màn hình trạng thái toàn màn hình (tập trung, họp, toilet, cà phê...) + lưới chọn nhanh.
# Ảnh riêng (anime, meme của bạn...): photos/status/<mã>*.png — tạo bằng them-anh.command
# (bỏ ảnh vào thư mục con "trangthai", đặt tên theo mã, vd toilet.jpg, toilet_2.jpg).

STATUS_LIST='taptrung|Đang tập trung
hop|Đang họp
goidien|Đang nghe điện thoại
roidi|Ra ngoài một chút
toilet|Toilet time
cafe|Cà phê thư giãn
antrua|Đi ăn trưa
ngutrua|Ngủ trưa
vengay|Tan làm rồi'
ST_ID=""; ST_START=0; ST_SEED=0; ST_HOFF=0

status_name() { echo "$STATUS_LIST" | grep "^$1|" | cut -d'|' -f2; }
status_hooks() { grep "^$1|" "$DIR/lib/hooks.txt" 2>/dev/null | cut -d'|' -f2-; }
status_away() { case "$1" in roidi|toilet|antrua|ngutrua|vengay) return 0 ;; esac; return 1; }

status_enter() { # mã
  ST_ID=$1; ST_START=$(date +%s); ST_HM=$(date +%H:%M); ST_SEED=$(( ST_START / 7 )); ST_HOFF=0
  VIEW=status; LAST_KEY=""; log "status: $1"
}
status_exit() { log "status: back after $(( ($(date +%s) - ST_START) / 60 )) min"; ST_ID=""; VIEW=main; LIGHT_NOW=""; }
status_elapsed() { echo $(( ($(date +%s) - ST_START) / 60 )); }
status_hook() { # câu hiện tại (đổi mỗi 30 phút hoặc khi vuốt)
  n=$(status_hooks "$ST_ID" | grep -c .); [ "$n" -gt 0 ] || return 0
  i=$(( (ST_SEED + ($(date +%s) - ST_START) / 1800 + ST_HOFF) % n )); [ $i -lt 0 ] && i=$(( i + n ))
  status_hooks "$ST_ID" | sed -n "$(( i + 1 ))p"
}
status_key() { echo "st.$ST_ID.$ST_HOFF.$(( ($(date +%s) - ST_START) / 1800 ))"; }
status_image() { # -> đường dẫn ảnh (ảnh riêng của bạn ưu tiên, đổi mỗi lần vào)
  sub=""; [ $W -gt $H ] && sub="land/"
  l=$(ls "$DIR/photos/status/$sub$ST_ID"*.png 2>/dev/null)
  if [ -n "$l" ]; then n=$(echo "$l" | wc -l); echo "$l" | sed -n "$(( (ST_SEED + ST_HOFF) % n + 1 ))p"; return; fi
  echo "$DIR/ui/status/$ST_ID.png"
}
png_size() { set -- $(od -An -tu1 -j16 -N8 "$1" 2>/dev/null); [ $# -ge 8 ] && echo "$(( $3 * 256 + $4 )) $(( $7 * 256 + $8 ))" || echo "560 420"; }

status_topline() { # giờ + đã bao lâu (vẽ lại mỗi phút, chỉ vùng nhỏ này)
  e=$(status_elapsed)
  if [ $e -ge 60 ]; then el="$(( e / 60 )) giờ $(( e % 60 )) phút"; else el="$e phút"; fi
  t="$(date +%H:%M)  ·  từ $ST_HM · đã $el"
  tx semi 24 40 26 "$t" l m $(( W - 80 ))
}
status_tick() { # mỗi phút: chỉ cập nhật dòng giờ phía trên
  rect 0 18 $W 44 WHITE; status_topline; refresh 0 "top=18,left=0,width=$W,height=44"
}

render_status() {
  "$FB" -q -b -k >/dev/null 2>&1
  img=$(status_image); set -- $(png_size "$img"); iw=$1; ih=$2
  name=$(status_name "$ST_ID"); hook=$(status_hook)
  status_topline
  if [ $W -le $H ]; then
    iy=$(( 80 + (560 - ih) / 2 )); [ $iy -lt 72 ] && iy=72
    image "$img" $(( (W - iw) / 2 )) $iy
    y=$(( iy + ih + 34 )); [ $y -lt 560 ] && y=560
    TXTOPT="-m"
    txw semi 60 40 $y "$name" $(( W - 80 )) 84
    txw light 36 50 $(( y + 92 )) "$hook" $(( W - 100 )) 150 m
    TXTOPT=""
    tx reg 18 $(( W / 2 )) $(( H - 64 )) "Chạm để quay lại  ·  vuốt ngang: câu khác" c s
  else
    image "$img" $(( 30 + (580 - iw) / 2 )) $(( 80 + (650 - ih) / 2 ))
    tx semi 52 640 200 "$name" l k 360
    txw light 32 640 290 "$hook" 360 220 m
    tx reg 18 640 640 "Chạm để quay lại · vuốt: câu khác" l s 360
  fi
  refresh 1
}
status_tap() { status_exit; }
status_swipe() { if [ $1 -lt 0 ]; then ST_HOFF=$(( ST_HOFF + 1 )); else ST_HOFF=$(( ST_HOFF - 1 )); fi; }

# ---------- Lưới chọn nhanh ----------
stpick_geom() { SPC=3; SPW=$(( (W - 40) / 3 )); SPY0=92; SPH=$(( (H - SPY0 - 16) / 3 )); }
render_stpick() {
  stpick_geom
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_LEFT" s; txt 34 18 84 "Trạng thái" b
  txt 24 26 $(( W - 330 )) "chạm một ô để bật" "" 300
  box 72 40 $(( W - 80 )) 2
  i=0
  echo "$STATUS_LIST" | while IFS='|' read -r id nm; do
    x=$(( 20 + (i % 3) * SPW )); y=$(( SPY0 + (i / 3) * SPH ))
    frame $(( y + 6 )) $(( x + 6 )) $(( SPW - 12 )) $(( SPH - 12 )) 1
    th="$DIR/ui/status/${id}_s.png"; ts=$(( SPH - 70 )); [ $ts -gt 150 ] && ts=150
    image "$th" $(( x + (SPW - 200) / 2 )) $(( y + 14 + (SPH - 70 - 150) / 2 ))
    tx semi 22 $(( x + SPW / 2 )) $(( y + SPH - 50 )) "$nm" c k $(( SPW - 24 ))
    i=$((i + 1))
  done
  refresh 1
  log "render stpick: done"
}
stpick_tap() { # x y
  if [ $2 -le 80 ]; then VIEW=main; return; fi
  stpick_geom
  col=$(( ($1 - 20) / SPW )); row=$(( ($2 - SPY0) / SPH ))
  [ $col -ge 0 ] && [ $col -lt 3 ] && [ $row -ge 0 ] && [ $row -lt 3 ] || return
  id=$(echo "$STATUS_LIST" | sed -n "$(( row * 3 + col + 1 ))p" | cut -d'|' -f1)
  [ -n "$id" ] && status_enter "$id"
}
