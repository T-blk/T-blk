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
remote_init() { [ "$REMOTE" = 1 ] && { remote_start; settings_json; }; }

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
    photodone) log "nhận ảnh qua Wi-Fi: xong"; RECV_DONE=1; LAST_KEY=""; [ "$VIEW" = recv ] && VIEW=recv ;;
    set) setting_apply "$2" "$3" ;;
    home) go_home "điện thoại" ;;
  esac
  remote_state
}

# Đổi một cài đặt từ điện thoại: chỉ nhận khoá + giá trị có trong danh sách Cài đặt
all_settings() { printf '%s\n%s\n%s\n%s\n' "$SETTINGS_LOOK" "$SETTINGS_POWER" "$SETTINGS_AUTO" "$SETTINGS_DEF" | grep -v '^@'; }
setting_apply() { # KEY VALUE
  line=$(all_settings | grep "^$1|" | head -1); [ -n "$line" ] || { log "remote set: khoá lạ $1"; return 1; }
  echo "$line" | cut -d'|' -f3 | tr ';' '\n' | cut -d= -f1 | grep -qx "$2" || { log "remote set: giá trị lạ $1=$2"; return 1; }
  old=$(setting_value "$1"); [ "$old" = "$2" ] && return 0
  save_setting "$1" "$2"; eval "$1=\"$2\""
  case "$1" in
    LAYOUT) for kk in CLOCK_STYLE EVENT_STYLE PHOTO_STYLE; do save_setting $kk auto; eval "$kk=auto"; done; PAGE=main; VIEW=main; MOFF=0 ;;
    ORIENTATION) PREV_ORIENT="$old"; reorient "$2"; VIEW=main ;;
    REMOTE) [ "$2" = 0 ] && remote_stop ;;
    LIGHT_DAY|LIGHT_NIGHT) LIGHT_NOW=""; set_light ;;
  esac
  LAST_KEY=""; settings_json
}
settings_json() { # -> /tmp/dash_settings.json cho ứng dụng điện thoại
  [ "$REMOTE" = 1 ] || return 0
  for g in look power auto main; do
    case $g in look) d="$SETTINGS_LOOK" ;; power) d="$SETTINGS_POWER" ;; auto) d="$SETTINGS_AUTO" ;; main) d="$SETTINGS_DEF" ;; esac
    echo "$d" | grep -v '^@' | while IFS='|' read -r key label opts; do printf '%s|%s|%s|%s|%s\n' "$g" "$key" "$label" "$(setting_value "$key")" "$opts"; done
  done | awk -F'|' 'function q(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return "\"" s "\"" }
    BEGIN { printf "{\"ok\":true,\"settings\":[" }
    { n = split($5, o, ";"); opts = ""
      for (i = 1; i <= n; i++) { split(o[i], kv, "="); v = kv[1]; t = substr(o[i], length(v) + 2); opts = opts (i > 1 ? "," : "") "{\"value\":" q(v) ",\"label\":" q(t) "}" }
      printf "%s{\"group\":%s,\"key\":%s,\"label\":%s,\"value\":%s,\"options\":[%s]}", (NR > 1 ? "," : ""), q($1), q($2), q($3), q($4), opts }
    END { print "]}" }' > /tmp/dash_settings.json.tmp && mv /tmp/dash_settings.json.tmp /tmp/dash_settings.json
}

render_msg() {
  "$FB" -q -b -k >/dev/null 2>&1
  tx sym 64 $(( W / 2 - 30 )) 90 "$I_QUOTE" l k
  TXTOPT="-m"
  txw semi 52 50 210 "$MSG_TEXT" $(( W - 100 )) $(( H - 420 ))
  TXTOPT=""
  tx reg 22 $(( W / 2 )) $(( H - 110 )) "Lời nhắn lúc $MSG_TIME" c m
  tx reg 18 $(( W / 2 )) $(( H - 70 )) "Chạm để đóng" c s
  refresh 1
}
msg_tap() { VIEW=main; [ "$MSG_PREV" = status ] && [ -n "$ST_ID" ] && VIEW=status; }

# ---------- Nhận ảnh từ Mac qua Wi-Fi (không cần cắm cáp) ----------
# Bật máy chủ tạm thời (15 phút hoặc tới khi thoát màn hình này), Wi-Fi giữ mở trong lúc đó.
recv_start() {
  [ -n "$REMOTE_KEY" ] || { REMOTE_KEY=$(( ($(date +%s) + $$) % 9000 + 1000 )); save_setting REMOTE_KEY "$REMOTE_KEY"; }
  RECV_ON=1; RECV_DONE=0; RECV_UNTIL=$(( $(date +%s) + 900 ))
  REMOTE_SAVE=$REMOTE; REMOTE=1; remote_start
}
recv_stop() {
  RECV_ON=0; REMOTE=${REMOTE_SAVE:-0}
  [ "$REMOTE" = 1 ] || remote_stop
  WIFI_USED=1
}
recv_check() { [ "$RECV_ON" = 1 ] && [ $(date +%s) -ge $RECV_UNTIL ] && { recv_stop; [ "$VIEW" = recv ] && VIEW=settings; return 0; }; return 1; }
render_recv() {
  "$FB" -q -b -k >/dev/null 2>&1
  txt 34 18 40 "$I_LEFT" s; txt 34 18 84 "Nhận ảnh từ Mac qua Wi-Fi" b
  box 72 40 $(( W - 80 )) 2
  ip=$(wifi_ip)
  if [ "$RECV_DONE" = 1 ]; then txt 34 110 40 "Đã nhận ảnh xong!" b; txt 24 160 40 "Chạm mũi tên trái để quay lại." "" $(( W - 80 ))
  elif [ -n "$ip" ]; then
    txt 26 110 40 "Kindle đang chờ ảnh. Trên Mac (cùng Wi-Fi), chạy lệnh gửi ảnh với:" "" $(( W - 80 )) 80
    tx reg 24 40 200 "Địa chỉ Kindle:" l m; tx semi 48 40 236 "$ip" l k
    tx reg 24 40 320 "Mã PIN:" l m; tx bold 64 40 352 "$REMOTE_KEY" l k
    txt 22 470 40 "Màn hình này tự tắt sau 15 phút. Không cần cắm cáp." "" $(( W - 80 )) 70
  else txt 26 120 40 "Đang bật Wi-Fi… mở lại màn hình này sau vài giây." "" $(( W - 80 )) 80; fi
  refresh 1
}
recv_tap() { [ $2 -le 80 ] && { recv_stop; VIEW=settings; }; }

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
    save_setting REMOTE "$REMOTE"; settings_json
  fi
}
