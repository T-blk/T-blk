# Tạm dừng / chạy lại giao diện Kindle (dùng chung cho dash.sh, touch.sh, các scriptlet).
#   HOME_MODE=nhanh  : "đóng băng" giao diện (kill -STOP cvm, cách KOReader cũng dùng) -> về Home ~2 giây
#   HOME_MODE=antoan : tắt hẳn (stop framework) như trước -> về Home ~30 giây
# Cờ /tmp/dash_fw_paused giữ pid đang bị đóng băng; chạy lại luôn dựa vào cờ này nên không phụ thuộc cài đặt.
FW_FLAG=/tmp/dash_fw_paused

cvm_pid() { for _p in $(pidof cvm 2>/dev/null); do echo "$_p"; return 0; done; return 1; }
proc_state() { read -r _a _b _st _r < "/proc/$1/stat" 2>/dev/null && echo "$_st"; }   # R S T ... (không tốn tiến trình)

fw_pause() {
  if [ "${HOME_MODE:-nhanh}" = nhanh ] && _p=$(cvm_pid); then
    lipc-set-prop com.lab126.pillow disableEnablePillow disable 2>/dev/null     # ẩn thanh trạng thái
    if kill -STOP "$_p" 2>/dev/null; then echo "$_p" > "$FW_FLAG"; return 0; fi
  fi
  rm -f "$FW_FLAG"
  stop framework 2>/dev/null || stop lab126_gui 2>/dev/null
}

fw_resume() {
  if [ -f "$FW_FLAG" ]; then
    _p=$(cat "$FW_FLAG"); rm -f "$FW_FLAG"
    if [ -n "$(proc_state "$_p")" ]; then
      kill -CONT "$_p" 2>/dev/null
      lipc-set-prop com.lab126.pillow disableEnablePillow enable 2>/dev/null
      fw_repaint
      return 0
    fi
  fi
  status framework 2>/dev/null | grep -q running || start framework 2>/dev/null || start lab126_gui 2>/dev/null
}
fw_paused() { [ -f "$FW_FLAG" ]; }

# Bắt giao diện Kindle vẽ lại TOÀN màn hình: nếu đang ở màn hình chính thì lệnh "mở màn hình chính" bị bỏ qua
# (chỉ vẽ lại vài vùng -> chỗ dashboard từng vẽ bị khuyết). Chuyển qua trang Cài đặt rồi về lại: mỗi lần
# chuyển ứng dụng Kindle đều vẽ lại cả màn hình.
fw_repaint() {
  usleep 400000 2>/dev/null || sleep 1
  if [ "${HOME_REPAINT:-1}" = 1 ]; then
    lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.settings 2>/dev/null
    sleep 2
  fi
  lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home 2>/dev/null
}

# Cho giao diện Kindle chạy tạm vài giây để làm việc cần nó (vd đổi hướng màn hình), rồi đóng băng lại
fw_thaw_do() { # lệnh...
  _p=$(cat "$FW_FLAG" 2>/dev/null); [ -n "$_p" ] || return 1
  kill -CONT "$_p" 2>/dev/null; sleep 2
  "$@"
  sleep 2; kill -STOP "$_p" 2>/dev/null
}

# Giao diện Kindle có tự chạy lại không? (0 = có, đã dừng lại)
fw_check() {
  if [ -f "$FW_FLAG" ]; then
    case "$(proc_state "$(cat "$FW_FLAG")")" in T|t) return 1 ;; esac
    rm -f "$FW_FLAG"
    _p=$(cvm_pid) || return 1
  else
    status framework 2>/dev/null | grep -q running || status lab126_gui 2>/dev/null | grep -q running || return 1
  fi
  fw_pause
  return 0
}
