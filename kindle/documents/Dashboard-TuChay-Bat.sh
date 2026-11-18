#!/bin/sh
# Name: Dashboard - Tu chay: Bat
# Cài tự chạy: mỗi lần Kindle khởi động, khi màn hình chính đã sẵn sàng thêm 60 giây, dashboard tự bật.
# An toàn: nếu lần khởi động trước dashboard không lên được, lần sau tự bỏ qua và tắt tự chạy.
# Gỡ: chạy "Dashboard - Tu chay: Tat", hoặc xoá file dashboard/AUTOSTART qua USB.
D=/mnt/us/dashboard
LOG="$D/autostart.log"
{
  echo "$(date '+%F %T') install"
  mntroot rw
  cat > /etc/upstart/kindle-dashboard.conf <<'JOB'
# Kindle Dashboard autostart (cài bởi Dashboard - Tu chay: Bat) — bản an toàn
start on started framework or started lab126_gui
script
  D=/mnt/us/dashboard; L=$D/autostart.log
  [ -f $D/AUTOSTART ] || exit 0
  [ -f /tmp/dash_autostarted ] && exit 0
  touch /tmp/dash_autostarted
  # Chống kẹt vòng: lần khởi động trước dashboard KHÔNG vẽ được -> lần này bỏ qua và tắt luôn tự chạy
  if [ -f $D/.boot_try ]; then
    rm -f $D/.boot_try $D/AUTOSTART; sync
    echo "$(date '+%F %T') bỏ qua: lần khởi động trước dashboard không lên -> đã tắt tự chạy" >> $L
    exit 0
  fi
  # Chờ giao diện Kindle sẵn sàng hẳn (trình quản lý cửa sổ trả lời), tối đa 5 phút, rồi thêm 60 giây
  i=0; while [ $i -lt 300 ]; do [ -n "$(lipc-get-prop com.lab126.winmgr orientationLock 2>/dev/null)" ] && break; sleep 1; i=$((i + 1)); done
  sleep 60
  [ -f $D/AUTOSTART ] || exit 0          # tắt tự chạy, hoặc đang cắm USB (ổ nhớ không gắn) -> thôi
  [ -d /tmp/dash.lock ] && exit 0        # người dùng đã tự mở dashboard
  touch $D/.boot_try; sync               # dashboard xoá tệp này sau lần vẽ đầu tiên thành công
  echo "$(date '+%F %T') tự mở dashboard" >> $L
  [ -f $D/dash.log ] && mv -f $D/dash.log $D/dash.log.1
  exec sh $D/dash.sh >> $D/dash.log 2>&1
end script
JOB
  r=$?
  mntroot ro
  [ $r = 0 ] && touch "$D/AUTOSTART" && echo "ok" || echo "FAILED ($r)"
  ls -l /etc/upstart/kindle-dashboard.conf
} >> "$LOG" 2>&1
