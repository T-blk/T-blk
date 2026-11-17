# Chẩn đoán + đo pin. Ghi % pin mỗi 15 phút vào battery.log, đếm số lần vẽ / chạm / thời gian bật Wi-Fi,
# ước tính còn bao lâu hết pin. Trang "Chẩn đoán & pin" trong Cài đặt (và trang web điều khiển) hiển thị.

BLOG="$DIR/battery.log"
ST_DAY=""; ST_FULL=0; ST_PART=0; ST_TAPS=0; ST_WIFI=0; ST_WIFIN=0; ST_SLEEP=0; ST_START=$(date +%s)
LAST_BLOG=0

stat_day() { d=$(date +%Y%m%d); [ "$d" = "$ST_DAY" ] || { ST_DAY=$d; ST_FULL=0; ST_PART=0; ST_TAPS=0; ST_WIFI=0; ST_WIFIN=0; ST_SLEEP=0; }; }
stat_full() { stat_day; ST_FULL=$(( ST_FULL + 1 )); }
stat_part() { ST_PART=$(( ST_PART + 1 )); }
stat_tap() { ST_TAPS=$(( ST_TAPS + 1 )); }
stat_wifi() { ST_WIFI=$(( ST_WIFI + $1 )); ST_WIFIN=$(( ST_WIFIN + 1 )); }   # giây bật sóng của 1 lần tải

batt_log() { # mỗi 15 phút: "epoch pin% sạc(0/1)"
  [ $(( ${NOWE:-0} - LAST_BLOG )) -ge 900 ] || return 0
  LAST_BLOG=$NOWE
  b=$(battery); [ -n "$b" ] || return 0
  c=0; is_charging && c=1
  echo "$NOWE $b $c" >> "$BLOG"
  if [ $(wc -l < "$BLOG") -gt 800 ]; then tail -672 "$BLOG" > "$BLOG.tmp" && cat "$BLOG.tmp" > "$BLOG"; rm -f "$BLOG.tmp"; fi   # giữ ~7 ngày
}

# Ước tính tốc độ hao pin (%/giờ) trên đoạn không sạc gần nhất (>= 2 giờ) -> BR_RATE BR_HOURS BR_LEFT
batt_rate() {
  BR_RATE=""; BR_HOURS=""; BR_LEFT=""
  [ -s "$BLOG" ] || return 1
  set -- $(awk '{ t[NR] = $1; b[NR] = $2; c[NR] = $3 } END {
      if (NR < 2) exit
      e = NR; while (e > 0 && c[e] == 1) e--          # bỏ đoạn đang sạc ở cuối
      if (e < 2) exit
      s = e; while (s > 1 && c[s - 1] == 0 && b[s - 1] >= b[s]) s--
      h = (t[e] - t[s]) / 3600; d = b[s] - b[e]
      if (h < 2 || d <= 0) { printf "0 %.1f %d\n", h, b[e]; exit }
      printf "%.2f %.1f %d\n", d / h, h, b[e] }' "$BLOG")
  [ $# = 3 ] || return 1
  BR_RATE=$1; BR_HOURS=$2
  [ "$1" = 0.00 ] || [ "$1" = 0 ] && return 1
  BR_LEFT=$(awk -v r="$1" -v b="$3" 'BEGIN { h = b / r; if (h >= 48) printf "~%.1f ngày", h / 24; else printf "~%.0f giờ", h }')
}

ago() { # epoch file mtime -> "12 phút trước"
  [ -e "$1" ] || { echo "chưa có"; return; }
  a=$(( $(date +%s) - $(date -r "$1" +%s 2>/dev/null || echo 0) ))
  if [ $a -lt 60 ]; then echo "vừa xong"; elif [ $a -lt 3600 ]; then echo "$(( a / 60 )) phút trước"
  elif [ $a -lt 86400 ]; then echo "$(( a / 3600 )) giờ trước"; else echo "$(( a / 86400 )) ngày trước"; fi
}

diag_lines() { # "nhãn|giá trị" cho trang chẩn đoán & trang web
  stat_day
  b=$(battery); c="không"; is_charging && c="đang sạc"
  batt_rate; r="đang đo (cần ≥ 2 giờ không sạc)"; [ -n "$BR_RATE" ] && r="$BR_RATE %/giờ · còn $BR_LEFT"
  up=$(( ($(date +%s) - ST_START) / 60 ))
  fw="chạy"; fw_paused && fw="đóng băng (nhanh)"; [ "$HOME_MODE" = antoan ] && fw="tắt (an toàn)"
  wf="tắt"; [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ] && wf="đang bật"
  mem=$(awk '/MemFree/ { f = $2 } /^Cached/ { c = $2 } END { printf "%d MB trống", (f + c) / 1024 }' /proc/meminfo 2>/dev/null)
  disk=$(df -m "$DIR" 2>/dev/null | awk 'NR == 2 { print $4 " MB trống" }')
  echo "Pin|${b:-?}% · $c"
  echo "Hao pin|$r"
  echo "Đèn nền|$(lipc-get-prop com.lab126.powerd flIntensity 2>/dev/null) / 24"
  echo "Wi-Fi|$wf · hôm nay bật $ST_WIFIN lần, tổng $(( ST_WIFI / 60 )) phút $(( ST_WIFI % 60 )) giây"
  echo "Vẽ hôm nay|$ST_FULL toàn màn hình · $ST_PART đồng hồ · $ST_TAPS lần chạm"
  [ "$ST_SLEEP" -gt 0 ] && echo "Ngủ sâu|$(( ST_SLEEP / 60 )) phút hôm nay"
  echo "Thời tiết|$(ago "$WX")"
  echo "Lịch Apple|$(ago "$CALDIR/stamp")"
  [ -n "$NEWS_FEEDS" ] && echo "Tin tức|$(ago "$NEWS_STAMP")"
  echo "Chỉnh giờ|$(ago "$TS_STAMP")"
  echo "Giao diện Kindle|$fw"
  echo "Bộ nhớ|$mem · thẻ $disk"
  echo "Đã chạy|$(( up / 60 )) giờ $(( up % 60 )) phút · bản $DASH_VER"
}

render_diag() {
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_LEFT" s; txt 34 18 84 "Chẩn đoán & pin" b
  txt 26 22 $(( W - 190 )) "$I_REFRESH" s; txt 26 20 $(( W - 158 )) "Làm mới" b
  box 72 40 $(( W - 80 )) 2
  y=92
  diag_lines > /tmp/dash_diag.txt
  while IFS='|' read -r k v; do
    txt 22 $y 40 "$k" "" 200; txt 22 $y 250 "$v" b $(( W - 290 )) 34
    box $(( y + 36 )) 40 $(( W - 80 )) 1
    y=$(( y + 44 ))
  done < /tmp/dash_diag.txt
  # biểu đồ pin 48 giờ (mỗi cột 1 giờ, cột xám = đang sạc)
  gy=$(( y + 30 )); gh=$(( H - gy - 70 )); [ $gh -gt 220 ] && gh=220
  if [ $gh -ge 80 ] && [ -s "$BLOG" ]; then
    txt 22 $(( gy - 4 )) 40 "Pin 48 giờ qua" b
    gy=$(( gy + 34 )); gw=$(( W - 120 )); bw=$(( gw / 48 ))
    frame $gy 40 $(( 48 * bw + 4 )) $(( gh + 4 )) 1
    now=$(date +%s)
    awk -v N="$now" '{ k = int((N - $1) / 3600); if (k < 48 && !(k in b)) { b[k] = $2; c[k] = $3 } }
      END { for (k in b) print k, b[k], c[k] }' "$BLOG" | while read -r k p c; do
      h=$(( p * gh / 100 )); x=$(( 42 + (47 - k) * bw ))
      if [ "$c" = 1 ]; then box $(( gy + 2 + gh - h )) $x $(( bw - 1 )) $h GRAY9; else box $(( gy + 2 + gh - h )) $x $(( bw - 1 )) $h; fi
    done
    txt 18 $(( gy + gh + 10 )) 40 "48 giờ trước"; txt 18 $(( gy + gh + 10 )) $(( 40 + 48 * bw - 70 )) "bây giờ"
    txt 18 $(( gy + gh + 10 )) $(( W / 2 - 60 )) "xám = đang sạc"
  fi
  refresh 1
}
diag_tap() { # x y
  if [ $2 -le 80 ]; then if [ $1 -ge $(( W - 220 )) ]; then LAST_BLOG=0; batt_log; else VIEW=settings; fi; fi
}
