# Tối ưu pin & làm mới (bản 18.03). Tất cả chỉ chạy khi OPT_NEW=1 (Cài đặt > Pin & đèn > "Tối ưu pin mới").
# Tắt công tắc đó = chạy y như bản 18.02. Mỗi phần đều có giới hạn thời gian/khối lượng và tự tắt nếu chậm,
# để không bao giờ làm dashboard chậm phản hồi khi chạm.
#
# Ghi chú biến: các hàm vẽ (tx, twv…) dùng chung nhiều biến ngắn (_a _c _f _k _n _o _p _r _s _t _v _w _lx f r…),
# nên ở đây chỉ dùng biến có tiền tố riêng: CB_ CS_ BF_ EC_.

opt_on() { [ "${OPT_NEW:-1}" = 1 ]; }

# ---------- Thăm dò khả năng của "cmp" trên máy (gọi 1 lần trong fb_probe) ----------
#   CMP_L=1    : có "cmp -l" (liệt kê từng byte khác) -> dùng cho đồng hồ chỉ vẽ lại chữ số đổi
#   CMP_SKIP=1 : "cmp A B BỎ1 BỎ2" chạy được -> dùng để tìm dải đổi bằng vài lệnh thay vì 64 lệnh
#   CMP_REL=1  : vị trí cmp báo tính từ chỗ bắt đầu so (busybox), 0 = tính từ đầu tệp
cmp_probe() {
  CMP_L=0; CMP_SKIP=0; CMP_REL=0
  printf 'a' > /tmp/dash_c1; printf 'b' > /tmp/dash_c2
  cmp -l /tmp/dash_c1 /tmp/dash_c2 2>/dev/null | grep -q '^ *1 ' && CMP_L=1
  printf '%060d1%039d' 0 0 > /tmp/dash_c2; printf '%0100d' 0 > /tmp/dash_c1
  CB_o=$(cmp /tmp/dash_c1 /tmp/dash_c2 40 40 2>/dev/null)
  set -- $CB_o
  case "${5%,}" in 21) CMP_SKIP=1; CMP_REL=1 ;; 61) CMP_SKIP=1; CMP_REL=0 ;; esac
  # khi bỏ qua đến sau chỗ khác thì phải báo "giống nhau"
  [ $CMP_SKIP = 1 ] && [ -n "$(cmp /tmp/dash_c1 /tmp/dash_c2 70 70 2>/dev/null)" ] && CMP_SKIP=0
  rm -f /tmp/dash_c1 /tmp/dash_c2
}

# ---------- Tìm các dải 32 hàng bị đổi giữa 2 bản chụp bộ nhớ màn hình ----------
# cmp dừng ở byte khác đầu tiên -> biết dải đó đổi -> nhảy sang dải kế tiếp và so tiếp.
# Số lệnh = số dải đổi + 1 (thường 2–8), thay cho 64 lệnh dd|cksum như trước. Không có bước nào phải đọc
# từng điểm ảnh bằng awk, nên thời gian luôn ngắn dù đổi nhiều hay ít.
# -> CB_RUNS="hàng_đầu:số_hàng ..." (theo hàng bộ nhớ, giống cách cũ). Trả 1 nếu không đọc được kết quả.
cmp_bands() { # tệp_trước tệp_sau
  CB_fa=$1; CB_fb=$2; CB_bb=$(( FB_STRIDE * BAND )); CB_tot=$(( FB_STRIDE * H ))
  CB_off=0; CB_RUNS=""; CB_s=""; CB_e=""; CB_n=0
  while [ $CB_off -lt $CB_tot ]; do
    CB_o=$(cmp "$CB_fa" "$CB_fb" $CB_off $CB_off 2>/dev/null)
    [ -n "$CB_o" ] || break                                   # phần còn lại giống hệt
    set -- $CB_o; CB_p=${5%,}
    case "$CB_p" in ''|*[!0-9]*) return 1 ;; esac
    [ "$CMP_REL" = 1 ] && CB_p=$(( CB_p + CB_off ))
    CB_b=$(( (CB_p - 1) / CB_bb ))
    if [ -n "$CB_s" ] && [ $CB_b = $(( CB_e + 1 )) ]; then CB_e=$CB_b
    else
      [ -n "$CB_s" ] && CB_RUNS="$CB_RUNS$(( CB_s * BAND )):$(( (CB_e - CB_s + 1) * BAND )) "
      CB_s=$CB_b; CB_e=$CB_b
    fi
    CB_off=$(( (CB_b + 1) * CB_bb ))
    CB_n=$(( CB_n + 1 )); [ $CB_n -gt 40 ] && return 1        # không thể quá số dải; có gì lạ thì thôi
  done
  [ -n "$CB_s" ] && CB_RUNS="$CB_RUNS$(( CB_s * BAND )):$(( (CB_e - CB_s + 1) * BAND )) "
  return 0
}

# ---------- Đồng hồ: chỉ xoá + vẽ lại CHỮ SỐ thật sự đổi ----------
# Vẽ ngầm số mới vào bộ nhớ, so riêng các hàng của ô đồng hồ (cmp -l, tối đa 60.000 điểm ảnh khác),
# tìm các khoảng CỘT có đổi -> chỉ những khoảng đó được xoá trắng rồi hiện số mới (11:01 -> 11:02 chỉ chớp số cuối).
# Trả 0 = đã xong; trả 1 = để cách cũ (xoá cả ô) làm, ví dụ khi đồng hồ là ảnh (kim), đổi quá nhiều, hay máy chậm.
# Dùng _rt _rl _rw _rh _m _reg của clock_region_redraw.
CS_OFF=""; CS_SLOW=0; CS_IMGKEY=""
clock_shape() { # lệnh_vẽ...
  opt_on && [ -z "$CS_OFF" ] && [ "$CMP_L" = 1 ] && [ -n "$FB_STRIDE" ] || return 1
  [ "${FB_FLIP:-1}" = 0 ] && [ "${FB_FLIPX:-1}" = 0 ] && [ "$DIFF_DRAW" != 1 ] || return 1
  CS_key="$PAGE|$LAYOUT|$CLOCK_STYLE"; [ "$CS_key" = "$CS_IMGKEY" ] && return 1      # đồng hồ dạng ảnh: cách cũ
  CS_h=$_rh; [ $(( _rt + CS_h )) -gt $H ] && CS_h=$(( H - _rt )); [ $CS_h -gt 0 ] || return 1
  dd if="$FBDEV" of=/tmp/dash_ca bs=$FB_STRIDE skip=$_rt count=$CS_h 2>/dev/null || return 1
  box $_rt $_rl $_rw $CS_h WHITE; IMG_USED=0; "$@"
  [ "$IMG_USED" = 1 ] && { CS_IMGKEY=$CS_key; rm -f /tmp/dash_ca; return 1; }
  CS_t0=$(date +%s)                                                             # đo riêng phần so (phần vẽ thì cách cũ cũng tốn)
  dd if="$FBDEV" of=/tmp/dash_cb bs=$FB_STRIDE skip=$_rt count=$CS_h 2>/dev/null || { rm -f /tmp/dash_ca; return 1; }
  cmp -l /tmp/dash_ca /tmp/dash_cb 2>/dev/null | head -n 60000 | \
    awk -v S=$FB_STRIDE -v L=$_rl -v R=$(( _rl + _rw )) -v CAP=60000 -f "$DIR/lib/cols.awk" > /tmp/dash_ccols 2>/dev/null
  rm -f /tmp/dash_ca
  cs_time                                                                       # đo phần so (chưa tính thời gian chờ màn hình)
  CS_segs=$(cat /tmp/dash_ccols 2>/dev/null)
  case "$CS_segs" in *FULL*) rm -f /tmp/dash_cb; return 1 ;; esac
  [ $(echo "$CS_segs" | wc -l) -gt 6 ] && { rm -f /tmp/dash_cb; return 1; }       # đổi lắt nhắt nhiều chỗ: cách cũ
  if [ -z "$CS_segs" ]; then rm -f /tmp/dash_cb; return 0; fi                   # không có gì đổi
  CS_fl=0; [ "${CLOCK_CLEAN_MIN:-10}" -gt 0 ] && [ $(( _m % ${CLOCK_CLEAN_MIN:-10} )) = 0 ] && CS_fl=1
  CS_regs=""; CS_ul=$W; CS_ur=0
  while read -r CS_l CS_w; do
    case "$CS_l$CS_w" in ''|*[!0-9]*) continue ;; esac
    CS_l=$(( CS_l - 4 )); CS_w=$(( CS_w + 8 ))                                   # chừa viền cho sạch nét cũ
    [ $CS_l -lt $_rl ] && { CS_w=$(( CS_w - (_rl - CS_l) )); CS_l=$_rl; }
    [ $(( CS_l + CS_w )) -gt $(( _rl + _rw )) ] && CS_w=$(( _rl + _rw - CS_l ))
    [ $(( CS_l + CS_w )) -gt $W ] && CS_w=$(( W - CS_l ))
    [ $CS_w -gt 0 ] || continue
    CS_regs="$CS_regs $CS_l:$CS_w"
    [ $CS_l -lt $CS_ul ] && CS_ul=$CS_l; [ $(( CS_l + CS_w )) -gt $CS_ur ] && CS_ur=$(( CS_l + CS_w ))
  done < /tmp/dash_ccols
  [ -n "$CS_regs" ] || { rm -f /tmp/dash_cb; return 0; }
  # Vùng gộp từ chữ số đổi đầu tiên tới cuối cùng. Làm mới thường (không nháy) chỉ đổi những điểm ảnh thật sự khác,
  # nên chữ số không đổi nằm giữa vẫn đứng yên — mà chỉ phải chờ màn hình 2 lần thay vì 2 lần cho MỖI chữ số.
  CS_u="top=$_rt,left=$CS_ul,width=$(( CS_ur - CS_ul )),height=$CS_h"
  if [ $CS_fl = 1 ]; then                                                       # mỗi CLOCK_CLEAN_MIN phút: nháy đen riêng chữ số đổi
    for CS_r in $CS_regs; do refresh_wait "top=$_rt,left=${CS_r%:*},width=${CS_r#*:},height=$CS_h" 1; done
  else
    for CS_r in $CS_regs; do box $_rt ${CS_r%:*} ${CS_r#*:} $CS_h WHITE; done       # 1) xoá trắng riêng chữ số đổi
    refresh_wait "$CS_u"                       #    và CHỜ màn hình xoá xong hẳn (xem refresh_wait)
    usleep 100000 2>/dev/null                  #    thêm chút dư cho chắc
    dd if=/tmp/dash_cb of="$FBDEV" bs=$FB_STRIDE seek=$_rt count=$CS_h conv=notrunc 2>/dev/null   # 2) chép lại số mới
    refresh_wait "$CS_u"                       #    chờ xong: ngay sau đây có thể vẽ lại cả màn hình
  fi
  rm -f /tmp/dash_cb
  return 0
}
# Làm mới (không nháy) rồi CHỜ bộ điều khiển e-ink xử lý xong (fbink -w). Bắt buộc trước khi ghi đè cùng vùng
# trong bộ nhớ màn hình: lệnh làm mới chạy ngầm ~0,2 giây và đọc bộ nhớ trong lúc chạy; ghi số mới vào ngay
# thì nó đọc lẫn nửa cũ nửa mới -> chữ số hiện thiếu một nửa, còn sót nét số cũ (lỗi bản 18.03).
refresh_wait() { # vùng [1 = nháy đen]
  [ "$DIFF_DRAW" = 1 ] && return 0
  CS_inv=""; [ "$NIGHT_INVERT" = 1 ] && is_night && CS_inv="-H"
  CS_fla=""; [ "$2" = 1 ] && CS_fla="-f"
  "$FB" -q -w $CS_fla $CS_inv -s $1 >/dev/null 2>&1 || { refresh "${2:-0}" "$1"; usleep 300000 2>/dev/null || sleep 1; }
}
cs_time() { # quá chậm 2 lần liền (>= 4 giây) -> tự tắt cho phiên này, dùng cách cũ
  CS_el=$(( $(date +%s) - CS_t0 ))
  if [ $CS_el -ge 4 ]; then CS_SLOW=$(( CS_SLOW + 1 )); log "đồng hồ: so chữ số mất ${CS_el}s"
    [ $CS_SLOW -ge 2 ] && { CS_OFF=1; log "đồng hồ: máy chậm -> tự tắt chế độ chỉ vẽ chữ số đổi"; }
  else CS_SLOW=0; fi
}

# ---------- Bố cục có ảnh không? (không có ảnh thì đến giờ đổi ảnh khỏi vẽ lại) ----------
uses_photo() {
  opt_on || return 0
  [ "$PAGE" = main ] || return 1                     # các trang khác (bảng tin, bloc, ban đêm…) không có ảnh
  if layout_active; then case "$LAYOUT" in the|anh) return 0 ;; esac; return 1; fi
  return 0                                           # Cổ điển: có ô ảnh
}

# ---------- Nút "Dùng gợi ý tiết kiệm pin" (Cài đặt > Pin & đèn) ----------
eco_apply() {
  EC_ch=""
  if [ "${LIGHT_IDLE_MIN:-0}" = 0 ] || [ "${LIGHT_IDLE_MIN:-0}" -gt 15 ]; then
    save_setting LIGHT_IDLE_MIN 15; LIGHT_IDLE_MIN=15; EC_ch="$EC_ch · tắt đèn sau 15 phút không chạm"; fi
  if [ -n "$LIGHT_NIGHT" ] && [ "$LIGHT_NIGHT" -gt 1 ] 2>/dev/null; then
    save_setting LIGHT_NIGHT 1; LIGHT_NIGHT=1; EC_ch="$EC_ch · đèn ban đêm mức 1"; fi
  if [ "${REFRESH_MIN:-1}" = 1 ]; then
    save_setting REFRESH_MIN 2; REFRESH_MIN=2; EC_ch="$EC_ch · cập nhật giờ mỗi 2 phút"; fi
  if [ "${OPT_NEW:-1}" != 1 ]; then save_setting OPT_NEW 1; OPT_NEW=1; EC_ch="$EC_ch · bật tối ưu pin mới"; fi
  if [ -n "$EC_ch" ]; then MSG_TEXT="Đã đổi:${EC_ch#" ·"}. Muốn đổi lại: Cài đặt > Pin & đèn."
  else MSG_TEXT="Bạn đã dùng sẵn các mức tiết kiệm pin gợi ý."; fi
  log "tiết kiệm pin:$EC_ch"
  LIGHT_NOW=""; MSG_TIME=$(date +%H:%M); MSG_PREV=main; VIEW=msg
}
