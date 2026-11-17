# Điều khiển từ điện thoại: bật/tắt máy chủ web (remote_srv.sh), nhận lệnh, màn hình lời nhắn.
: "${REMOTE:=0}" "${REMOTE_PORT:=8080}"

wifi_ip() { ifconfig wlan0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p;s/.*inet \([0-9.]*\) .*/\1/p' | head -1; }
remote_running() { pgrep -f "$DIR/remote_srv.sh" >/dev/null 2>&1 || ps | grep -v grep | grep -q "remote_srv.sh"; }

remote_start() {
  [ -n "$REMOTE_KEY" ] || { REMOTE_KEY=$(( ($(date +%s) + $$) % 9000 + 1000 )); save_setting REMOTE_KEY "$REMOTE_KEY"; }
  wifi_on >/dev/null 2>&1
  touch /tmp/dash_remote_on
  remote_running || { nohup sh "$DIR/remote_srv.sh" "$REMOTE_PORT" "$REMOTE_KEY" >/dev/null 2>&1 & }
  log "remote: bật cổng $REMOTE_PORT"
}
remote_stop() {
  rm -f /tmp/dash_remote_on
  pkill -f "$DIR/remote_srv.sh" 2>/dev/null; pkill -f "nc -l -p $REMOTE_PORT" 2>/dev/null
  iptables -D INPUT -p tcp --dport "$REMOTE_PORT" -j ACCEPT 2>/dev/null
  rm -f /tmp/dash_http.fifo
}
remote_init() { [ "$REMOTE" = 1 ] && remote_start; }

# Trạng thái cho trang web (ghi vào /tmp, không ghi thẻ nhớ)
remote_state() {
  [ "$REMOTE" = 1 ] || return 0
  printf '"view":"%s","status":"%s","layout":"%s","page":"%s","batt":"%s","ver":"%s",' \
    "$VIEW" "$ST_ID" "$LAYOUT" "$PAGE" "${BATT:-$(battery)}" "$DASH_VER" > /tmp/dash_state
  if [ $(( ${LOOPN:-0} % 15 )) = 1 ] || [ ! -s /tmp/dash_diag_web.txt ]; then diag_lines > /tmp/dash_diag_web.txt 2>/dev/null; fi
}

handle_cmd() { # hành_động tham_số
  LAST_ACT=$(date +%s); LAST_TOUCH=$LAST_ACT
  case "$1" in
    status) [ -n "$(status_name "$2")" ] && status_enter "$2" ;;
    back) [ "$VIEW" = status ] && status_exit; VIEW=main ;;
    layout) case "$2" in codien|toigian|thuysi|the|anh|chu|lich)
              LAYOUT=$2; save_setting LAYOUT "$2"; PAGE=main; VIEW=main; MOFF=0 ;; esac ;;
    page) case "$2" in main|tin|bloc|dem|pomo|news) PAGE=$2; VIEW=main ;; esac ;;
    light) [ "$2" = up ] && LADJ=$((LADJ + 2)); [ "$2" = down ] && LADJ=$((LADJ - 2)); LIGHT_NOW=""; set_light ;;
    msg) MSG_TEXT=$(cat /tmp/dash_msg 2>/dev/null); MSG_TIME=$(date +%H:%M); [ -n "$MSG_TEXT" ] && { MSG_PREV=$VIEW; VIEW=msg; } ;;
    refresh) LAST_KEY="" ;;
    home) go_home "điện thoại" ;;
  esac
  remote_state
}

render_msg() {
  "$FB" -q -b -k >/dev/null 2>&1
  tx sym 64 $(( W / 2 - 30 )) 90 "$I_QUOTE" l k
  TXTOPT="-m"
  txw semi 52 50 210 "$MSG_TEXT" $(( W - 100 )) $(( H - 420 ))
  TXTOPT=""
  [ -f "$DIR/ui/flora_div.png" ] && image "$DIR/ui/flora_div.png" $(( (W - 420) / 2 )) $(( H - 170 ))
  tx reg 22 $(( W / 2 )) $(( H - 110 )) "Lời nhắn lúc $MSG_TIME" c m
  tx reg 18 $(( W / 2 )) $(( H - 70 )) "Chạm để đóng" c s
  refresh 1
}
msg_tap() { VIEW=main; [ "$MSG_PREV" = status ] && [ -n "$ST_ID" ] && VIEW=status; }

render_remote() {
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_LEFT" s; txt 34 18 84 "Điều khiển từ điện thoại" b
  box 72 40 $(( W - 80 )) 2
  if [ "$REMOTE" = 1 ]; then
    frame 100 40 $(( W - 80 )) 90 4; txt 34 124 70 "Đang BẬT" b; txt 24 130 $(( W - 260 )) "chạm để tắt" "" 200
    ip=$(wifi_ip)
    if [ -n "$ip" ]; then
      txt 24 214 40 "Trên điện thoại (cùng mạng Wi-Fi với Kindle), mở trình duyệt và gõ:" "" $(( W - 80 )) 70
      tx semi 40 40 290 "http://$ip:$REMOTE_PORT" l k $(( W - 80 ))
      txt 24 370 40 "Mã PIN:" ""; tx bold 64 170 356 "$REMOTE_KEY" l k
      txt 22 460 40 "Mẹo: lưu trang đó ra màn hình chính điện thoại để mở bằng một chạm." "" $(( W - 80 )) 70
    else
      txt 26 214 40 "Chưa có Wi-Fi — đang kết nối… (mở lại trang này sau vài giây)" "" $(( W - 80 )) 80
    fi
  else
    frame 100 40 $(( W - 80 )) 90 1; txt 34 124 70 "Đang TẮT" b; txt 24 130 $(( W - 260 )) "chạm để bật" "" 200
  fi
  y=560
  for t in "Bấm đổi trạng thái (Toilet, Họp, Cà phê…), bố cục, trang" \
           "Gửi lời nhắn hiện to lên Kindle" "Chỉnh đèn, xem pin & chẩn đoán, về Home" \
           "Khi bật: Wi-Fi luôn mở để nghe lệnh nên tốn pin hơn. Chỉ người biết mã PIN và cùng mạng mới điều khiển được."; do
    txt 24 $y 40 "•" b; txt 24 $y 70 "$t" "" $(( W - 110 )) 100; y=$(( y + 80 ))
  done
  refresh 1
}
remote_tap() { # x y
  if [ $2 -le 80 ]; then VIEW=settings; return; fi
  if [ $2 -ge 100 ] && [ $2 -le 190 ]; then
    if [ "$REMOTE" = 1 ]; then REMOTE=0; remote_stop; else REMOTE=1; remote_start; fi
    save_setting REMOTE "$REMOTE"
  fi
}
