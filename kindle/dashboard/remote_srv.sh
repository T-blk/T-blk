#!/bin/sh
# Máy chủ web nhỏ để điều khiển dashboard từ điện thoại (cùng mạng Wi-Fi).
#   sh remote_srv.sh CỔNG MÃ_PIN
# Mỗi yêu cầu: nc nghe 1 kết nối -> handle() đọc dòng GET -> trả trang/JSON hoặc chuyển lệnh cho dash.sh.
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=${1:-8080}; KEY=${2:-0000}
FIFO=/tmp/dash_http.fifo
log() { echo "$(date '+%F %T') [remote] $*" >> "$DIR/dash.log"; }

urldec() { # %XX và + -> ký tự (UTF-8 tiếng Việt giữ nguyên)
  printf '%b' "$(printf '%s' "$1" | awk '{
    gsub(/\+/, " "); out = ""; n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (c == "%" && i + 2 <= n) {
        h = toupper(substr($0, i + 1, 2)); v = index("0123456789ABCDEF", substr(h, 1, 1)) - 1
        w = index("0123456789ABCDEF", substr(h, 2, 1)) - 1
        if (v >= 0 && w >= 0) { d = v * 16 + w; out = out sprintf("\\0%o%o%o", int(d / 64), int(d / 8) % 8, d % 8); i += 2; continue }
      }
      if (c == "\\") c = "\\\\"
      out = out c
    }
    printf "%s", out }')"
}
qget() { echo "$1" | tr '&' '\n' | sed -n "s/^$2=//p" | head -1; }

reply() { # mã kiểu nội_dung   (có Content-Length để trình duyệt tự đóng kết nối ngay)
  _len=$(printf '%s' "$3" | wc -c | tr -d ' ')
  printf 'HTTP/1.0 %s\r\nContent-Type: %s; charset=utf-8\r\nContent-Length: %s\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n' "$1" "$2" "$_len"
  printf '%s' "$3"
}

handle() {
  read -r method path proto || return
  while read -r h; do h=$(printf '%s' "$h" | tr -d '\r'); [ -z "$h" ] && break; done
  route=${path%%\?*}; q=""; case "$path" in *\?*) q=${path#*\?} ;; esac
  k=$(qget "$q" k)
  case "$route" in
    /hello)   # dò tìm trong mạng (không cần PIN): ứng dụng quét dải IP và gọi /hello
      reply "200 OK" application/json "{\"app\":\"kindle-dashboard\",\"api\":1,\"ver\":\"$(cat "$DIR/VERSION" 2>/dev/null)\",\"port\":$PORT,\"auth\":\"pin\"}" ;;
    /settings)
      [ "$k" = "$KEY" ] || { reply "403 Forbidden" application/json '{"ok":false}'; return; }
      reply "200 OK" application/json "$(cat /tmp/dash_settings.json 2>/dev/null || echo '{"ok":false}')" ;;
    /) if [ "$k" = "$KEY" ]; then reply "200 OK" text/html "$(sed "s/__KEY__/$KEY/g" "$DIR/lib/remote.html")"
       else reply "200 OK" text/html '<meta name=viewport content="width=device-width"><body style="font:20px sans-serif;padding:24px"><form>Mã PIN trên Kindle:<br><input name=k inputmode=numeric style="font-size:28px;width:6em"> <button style="font-size:24px">Mở</button></form>'; fi ;;
    /api)
      [ "$k" = "$KEY" ] || { reply "403 Forbidden" application/json '{"ok":false}'; return; }
      st=$(cat /tmp/dash_state 2>/dev/null)
      dg=$(awk -F'|' '{ gsub(/"/, "\\\"", $2); printf "%s[\"%s\",\"%s\"]", (NR > 1 ? "," : ""), $1, $2 }' /tmp/dash_diag_web.txt 2>/dev/null)
      reply "200 OK" application/json "{\"ok\":true,$st\"diag\":[$dg]}" ;;
    /c)
      [ "$k" = "$KEY" ] || { reply "403 Forbidden" application/json '{"ok":false}'; return; }
      a=$(qget "$q" a); v=$(urldec "$(qget "$q" v)")
      case "$a" in
        status|back|layout|page|light|msg|refresh|home) ;;
        set) sk=$(qget "$q" key); case "$sk" in ""|*[!A-Z_]*) reply "400 Bad Request" application/json '{"ok":false,"error":"key"}'; return ;; esac ;;
        *) reply "400 Bad Request" application/json '{"ok":false}'; return ;;
      esac
      v=$(printf '%s' "$v" | tr -d '\r' | tr '\n' ' ' | cut -c1-400)
      [ "$a" = msg ] && { printf '%s\n' "$v" > /tmp/dash_msg; v=""; }
      case "$v" in *[!a-z0-9+-]*) v="" ;; esac       # tham số khác lời nhắn: chỉ chữ thường/số
      if [ "$a" = set ]; then [ -n "$v" ] || { reply "400 Bad Request" application/json '{"ok":false,"error":"value"}'; return; }; echo "C set $sk $v" >> /tmp/dash_taps
      else echo "C $a $v" >> /tmp/dash_taps; fi
      kill -USR1 "$(cat /tmp/dash.pid 2>/dev/null)" 2>/dev/null
      log "lệnh từ điện thoại: $a $v"
      reply "200 OK" application/json '{"ok":true}' ;;
    *) reply "404 Not Found" text/plain "" ;;
  esac
}

# busybox: nc -l -p CỔNG ; OpenBSD netcat (để thử trên máy tính): nc -N -l CỔNG
if nc -h 2>&1 | grep -q OpenBSD; then NCL="nc -N -l $PORT"; else NCL="nc -l -p $PORT"; fi
rm -f "$FIFO"; mkfifo "$FIFO" || exit 1
iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
log "nghe cổng $PORT"
while [ -f /tmp/dash_remote_on ] && [ ! -f /tmp/dash_stop ]; do
  $NCL < "$FIFO" | handle > "$FIFO" 2>/dev/null || sleep 1
done
iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null
rm -f "$FIFO"; log "dừng"
