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

# Trả framebuffer về góc xoay của giao diện Kindle (dashboard có thể đã tự xoay, vd lộn ngược).
# Ưu tiên góc đã lưu lúc xoay (/tmp/dash_rota_orig); nếu mất (vd 2 bản dashboard tranh nhau) thì dùng góc
# "đứng thẳng" đã học từ màn hình chính (.rota_up2). Chỉ gọi khi đánh thức giao diện Kindle đang bị đóng băng.
fw_restore_rota() {
  _rf=/sys/class/graphics/fb0/rotate; _ro=""
  if [ -s /tmp/dash_rota_orig ]; then _ro=$(cat /tmp/dash_rota_orig); rm -f /tmp/dash_rota_orig
  elif [ -s "${DIR:-/mnt/us/dashboard}/.rota_up2" ]; then _ro=$(cat "${DIR:-/mnt/us/dashboard}/.rota_up2"); fi
  case "$_ro" in [0-3]) [ "$(cat "$_rf" 2>/dev/null)" = "$_ro" ] || { echo "$_ro" > "$_rf"; } 2>/dev/null ;; esac
}
fw_resume() {
  # Tìm giao diện Kindle đang bị đóng băng: theo cờ, hoặc (khi cờ đã mất) chính tiến trình cvm đang ở trạng thái T.
  # Trước đây mất cờ thì Kindle bị đóng băng mãi (màn hình đen/đứng) -> giờ luôn đánh thức được.
  _p=""; [ -f "$FW_FLAG" ] && _p=$(cat "$FW_FLAG"); rm -f "$FW_FLAG"
  case "$(proc_state "$_p")" in T|t) ;; *) _p="" ;; esac
  if [ -z "$_p" ] && _c=$(cvm_pid); then case "$(proc_state "$_c")" in T|t) _p=$_c ;; esac; fi
  if [ -n "$_p" ]; then
    fw_restore_rota                                   # trả góc xoay TRƯỚC khi giao diện Kindle chạy lại
    kill -CONT "$_p" 2>/dev/null
    lipc-set-prop com.lab126.pillow disableEnablePillow enable 2>/dev/null
    fw_repaint
    return 0
  fi
  rm -f /tmp/dash_rota_orig
  lipc-set-prop com.lab126.pillow disableEnablePillow enable 2>/dev/null
  status framework 2>/dev/null | grep -q running || start framework 2>/dev/null || start lab126_gui 2>/dev/null
}
fw_paused() { [ -f "$FW_FLAG" ]; }

# Bắt giao diện Kindle vẽ lại TOÀN màn hình: nếu đang ở màn hình chính thì lệnh "mở màn hình chính" bị bỏ qua
# (chỉ vẽ lại vài vùng -> chỗ dashboard từng vẽ bị khuyết). Chuyển qua trang Cài đặt rồi về lại: mỗi lần
# chuyển ứng dụng Kindle đều vẽ lại cả màn hình.
# Khi giao diện Kindle chạy lại, nó xử lý nốt các lần chạm bị xếp hàng lúc đóng băng (vd cú chạm vào nút Nhà
# ở góc phải trên = nút ⋮ của Kindle -> menu bật ra). Nên: đợi nó xử lý xong, rồi chuyển qua trang Cài đặt và về
# màn hình chính -> đóng mọi menu/trang lỡ mở + vẽ lại toàn màn hình.
# HOME_REPAINT: chuyen (mặc định, ~3 giây) · nguon = thêm "ngủ rồi dậy" như bấm nút nguồn 2 lần (~7 giây, vẽ lại
# chắc chắn nhất) · 0 = không làm gì
fw_repaint() {
  [ "${HOME_REPAINT:-chuyen}" = 0 ] && return 0
  sleep 1                                              # để Kindle xử lý hết các lần chạm tồn đọng
  lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.settings 2>/dev/null
  sleep 2
  lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home 2>/dev/null
  if [ "$HOME_REPAINT" = nguon ] && command -v powerd_test >/dev/null 2>&1; then
    sleep 1; lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
    powerd_test -p >/dev/null 2>&1; sleep 3; powerd_test -p >/dev/null 2>&1
  fi
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
