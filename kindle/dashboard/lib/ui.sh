# Bộ vẽ cho giao diện hiện đại (font Inter, màu xám, căn trái/giữa/phải chính xác).
# Được dash.sh nạp. Dùng chung các biến W H FB DIR.

FONTDIR="$DIR/fonts"

TXBG=""            # nền đang vẽ chữ lên (vd GRAYE trên thẻ xám) để viền chữ mịn đúng màu

font_path() {
  case "$1" in
    thin) echo "$FONTDIR/Inter-Thin.ttf" ;; light) echo "$FONTDIR/Inter-Light.ttf" ;;
    reg) echo "$FONTDIR/Inter-Regular.ttf" ;; semi) echo "$FONTDIR/Inter-SemiBold.ttf" ;;
    bold) echo "$FONTDIR/Inter-Bold.ttf" ;; black) echo "$FONTDIR/Inter-Black.ttf" ;;
    mono) echo "$FONTDIR/JBMono-Light.ttf" ;; sym) echo "$SYM" ;;
    nbold) echo "$BOLD" ;; *) echo "$REG" ;;
  esac
}
# có font Inter chưa (bản cũ chưa chép font thì quay về Noto)
modern_ok() { [ -f "$FONTDIR/Inter-Regular.ttf" ] && [ -f "$DIR/lib/metrics/reg.txt" ]; }

# Thông số dọc của font (phần nghìn em): K = cao dòng FBInk, ASC = đỉnh tới đường chân chữ, CAP = cao chữ hoa
fmetric() {
  case "$1" in
    mono) FK=1320; FA=1020; FC=730 ;; nreg|nbold|sym) FK=1362; FA=1069; FC=714 ;;
    *) FK=1209; FA=968; FC=727 ;;
  esac
}
# px để chữ HOA / chữ số cao đúng $2 pixel
px_for_cap() { fmetric "$1"; echo $(( $2 * FK / FC )); }
pxv() { fmetric "$1"; PXV=$(( $2 * FK / FC )); }          # như trên, không fork
# toạ độ top (FBInk) để đỉnh chữ số nằm ở y = $3
top_for_cap() { fmetric "$1"; echo $(( $3 - $2 * (FA - FC) / FK )); }

# twv KEY PX "chữ" -> TWV = độ rộng (px). Có bộ nhớ đệm trong shell: chữ đã đo thì không chạy awk nữa.
TWC="|"
# Bảng độ rộng ký tự ASCII nạp 1 lần vào biến shell (MW_<font>_<ký tự>) -> đo số, giờ, chữ không dấu không cần awk
mw_load() {
  eval "$(awk 'BEGIN { split("sp co dt cm hy sl pc lp rp", N, " "); split(" :.,-/%()", C, "")
      for (i = 1; i <= 9; i++) M[C[i]] = N[i]
      for (c = 48; c < 123; c++) { ch = sprintf("%c", c); if (ch ~ /[0-9A-Za-z]/) M[ch] = ch } }
    FNR == 1 { k = FILENAME; sub(/.*\//, "", k); sub(/\.txt$/, "", k) }
    { split($0, a, "\t"); if (FNR == 1) print "MK_" k "=" a[2]; else if (a[1] in M) print "MW_" k "_" M[a[1]] "=" a[2] }' "$DIR"/lib/metrics/*.txt 2>/dev/null)"
}
tw_sh() { # chỉ ký tự ASCII thường gặp; trả về 1 nếu gặp ký tự lạ
  _s=$3; _sum=0
  while [ -n "$_s" ]; do
    _r=${_s#?}; _c=${_s%"$_r"}; _s=$_r
    case "$_c" in
      [0-9A-Za-z]) _n=$_c ;; " ") _n=sp ;; :) _n=co ;; .) _n=dt ;; ,) _n=cm ;; -) _n=hy ;; /) _n=sl ;; %) _n=pc ;; "(") _n=lp ;; ")") _n=rp ;;
      *) return 1 ;;
    esac
    eval "_a=\${MW_$1_$_n}"; [ -n "$_a" ] || return 1
    _sum=$(( _sum + _a ))
  done
  eval "_K=\${MK_$1:-1209}"; TWV=$(( (_sum * $2 * 2 / _K + 1) / 2 ))
}
twv() {
  if [ "$1" = sym ]; then TWV=$(( ${#3} * $2 / 3 )); return; fi
  tw_sh "$@" && return 0
  _k="$1.$2.$3"
  case "$_k" in *"|"*) TWV=$(tw_awk "$@"); return ;; esac
  case "$TWC" in
    *"|$_k="*) _v=${TWC#*"|$_k="}; TWV=${_v%%|*}; return ;;
  esac
  TWV=$(tw_awk "$@")
  [ ${#TWC} -gt 24000 ] && TWC="|"
  TWC="$TWC$_k=$TWV|"
}
tw() { twv "$@"; echo "$TWV"; }
tw_awk() {
  printf '%s\n' "$3" | awk -v MF="$DIR/lib/metrics/$1.txt" -v PX="$2" '
    BEGIN { FS = "\t"; n = 0; while ((getline l < MF) > 0) { split(l, a, "\t"); if (++n == 1) K = a[2]; else A[a[1]] = a[2] }
            if (K == "") K = 1209 }
    { s = 0; i = 1; L = length($0)
      while (i <= L) {
        c = substr($0, i, 3); if (c in A) { s += A[c]; i += 3; continue }
        c = substr($0, i, 2); if (c in A) { s += A[c]; i += 2; continue }
        c = substr($0, i, 1); if (c in A) s += A[c]; else if (c > "\177") s += 180; else s += 560
        i++
      }
      printf "%d\n", s * PX / K + 0.5 }'
}

fbcolor() { # k m s h c w -> cờ FBInk
  case "$1" in
    m) echo "-C GRAY6" ;; s) echo "-C GRAY9" ;; h) echo "-C GRAYC" ;; c) echo "-C GRAYE" ;; d) echo "-C GRAY3" ;;
    w) echo "-C WHITE -B BLACK" ;;
    *) [ -n "$TXBG" ] && echo "-C BLACK -B $TXBG" || echo "" ;;
  esac
}
fbcolor_bg() { # màu chữ xám trên nền TXBG
  _c=$(fbcolor "$1"); case "$1" in w) ;; *) [ -n "$TXBG" ] && case "$_c" in *-B*) ;; *) _c="$_c -B $TXBG" ;; esac ;; esac; echo "$_c"
}

# tx KEY PX X Y "chữ" [căn l|c|r] [màu k|m|s|h|c|w] [rộng tối đa]
#   Y = top dòng chữ (như FBInk). căn c: X là tâm; căn r: X là mép phải.
tx() {
  [ -n "$5" ] || return 0
  _f=$(font_path "$1"); _al=${6:-l}
  case "$_al" in
    c) twv "$1" "$2" "$5"; _w=$TWV; [ -n "$8" ] && [ $_w -gt $8 ] && _w=$8; _lx=$(( $3 - _w / 2 )) ;;
    r) twv "$1" "$2" "$5"; _w=$TWV; [ -n "$8" ] && [ $_w -gt $8 ] && _w=$8; _lx=$(( $3 - _w )) ;;
    *) _lx=$3 ;;
  esac
  [ $_lx -lt 0 ] && _lx=0
  _r=0; [ -n "$8" ] && _r=$(( W - _lx - $8 - 2 )); [ $_r -lt 0 ] && _r=0
  _bt=$(( H - $4 - $2 * 14 / 10 )); [ $_bt -lt 0 ] && _bt=0
  "$FB" -q -b -O $(fbcolor_bg "${7:-k}") -t "regular=$_f,px=$2,top=$4,left=$_lx,right=$_r,bottom=$_bt" "$5" >/dev/null 2>&1
}
# txcap KEY CAPH X Y "chữ" [căn] [màu] [rộng]  — Y = đỉnh chữ số/chữ hoa, cao CAPH
txcap() {
  fmetric "$1"; _p=$(( $2 * FK / FC )); _t=$(( $4 - _p * (FA - FC) / FK ))
  tx "$1" "$_p" "$3" "$_t" "$5" "$6" "$7" "$8"
}
# txfit KEY CAPH X Y "chữ" căn màu RỘNG — như txcap nhưng thu nhỏ cho vừa RỘNG
txfit() {
  _ch=$2; pxv "$1" "$_ch"; _p=$PXV; twv "$1" "$_p" "$5"; _ww=$TWV
  [ $_ww -gt $8 ] && _ch=$(( _ch * $8 / _ww ))
  txcap "$1" "$_ch" "$3" "$4" "$5" "$6" "$7" "$8"
}
# txw KEY PX X Y "đoạn văn" RỘNG CAO [màu]  — nhiều dòng, tự xuống dòng
txw() {
  _f=$(font_path "$1"); _r=$(( W - $3 - $6 )); [ $_r -lt 0 ] && _r=0
  _bt=$(( H - $4 - $7 )); [ $_bt -lt 0 ] && _bt=0
  "$FB" -q -b -O $TXTOPT $(fbcolor_bg "${8:-k}") -t "regular=$_f,px=$2,top=$4,left=$3,right=$_r,bottom=$_bt" "$5" >/dev/null 2>&1
}

rect() { # x y w h [màu FBInk: BLACK GRAY6 GRAYC GRAYE WHITE ...]
  "$FB" -q -b -B "${5:-BLACK}" -k "top=$2,left=$1,width=$3,height=$4" >/dev/null 2>&1
}
hl() { rect "$2" "$1" $(( $3 - $2 )) "${5:-1}" "${4:-GRAYC}"; }   # hl Y X0 X1 [màu] [dày]
vl() { rect "$1" "$2" "${5:-1}" $(( $3 - $2 )) "${4:-GRAYC}"; }   # vl X Y0 Y1 [màu] [dày]
# chấm / vòng tròn bằng ký hiệu trong symbols.ttf (glyph rộng 858/1000 em, lệch trái 44, đỉnh 253 dưới top)
dot() { # cx cy đường_kính [màu k|m|s|h]
  _dp=$(( $3 * 1362 / 858 )); tx sym "$_dp" $(( $1 - $3 / 2 - 44 * _dp / 1362 )) $(( $2 - $3 / 2 - 253 * _dp / 1362 )) "$I_DISC" l "${4:-k}"
}
ring() { _dp=$(( $3 * 1362 / 858 )); tx sym "$_dp" $(( $1 - $3 / 2 - 44 * _dp / 1362 )) $(( $2 - $3 / 2 - 253 * _dp / 1362 )) "$I_RING" l "${4:-k}"; }
# khối tròn đen + số trắng (đánh dấu hôm nay)
disc_num() { # cx cy đường_kính "số" font capH
  dot "$1" "$2" "$3" k
  txcap "${5:-semi}" "${6:-$(( $3 * 40 / 100 ))}" "$1" $(( $2 - ${6:-$(( $3 * 40 / 100 ))} / 2 )) "$4" c w
}
# ô vuông đen + số trắng
box_num() { # x y w h "số" font capH
  rect "$1" "$2" "$3" "$4" BLACK
  txcap "${6:-semi}" "$7" $(( $1 + $3 / 2 )) $(( $2 + ($4 - $7) / 2 )) "$5" c w
}

# ---------- Chữ tiếng Việt ----------
VN_MONTH="Một|Hai|Ba|Tư|Năm|Sáu|Bảy|Tám|Chín|Mười|Mười Một|Mười Hai"
up() { echo "$1" | tr 'a-z' 'A-Z' | sed 's/ă/Ă/g;s/â/Â/g;s/đ/Đ/g;s/ê/Ê/g;s/ô/Ô/g;s/ơ/Ơ/g;s/ư/Ư/g;s/à/À/g;s/á/Á/g;s/ả/Ả/g;s/ã/Ã/g;s/ạ/Ạ/g;s/ằ/Ằ/g;s/ắ/Ắ/g;s/ẳ/Ẳ/g;s/ẵ/Ẵ/g;s/ặ/Ặ/g;s/ầ/Ầ/g;s/ấ/Ấ/g;s/ẩ/Ẩ/g;s/ẫ/Ẫ/g;s/ậ/Ậ/g;s/è/È/g;s/é/É/g;s/ẻ/Ẻ/g;s/ẽ/Ẽ/g;s/ẹ/Ẹ/g;s/ề/Ề/g;s/ế/Ế/g;s/ể/Ể/g;s/ễ/Ễ/g;s/ệ/Ệ/g;s/ì/Ì/g;s/í/Í/g;s/ỉ/Ỉ/g;s/ĩ/Ĩ/g;s/ị/Ị/g;s/ò/Ò/g;s/ó/Ó/g;s/ỏ/Ỏ/g;s/õ/Õ/g;s/ọ/Ọ/g;s/ồ/Ồ/g;s/ố/Ố/g;s/ổ/Ổ/g;s/ỗ/Ỗ/g;s/ộ/Ộ/g;s/ờ/Ờ/g;s/ớ/Ớ/g;s/ở/Ở/g;s/ỡ/Ỡ/g;s/ợ/Ợ/g;s/ù/Ù/g;s/ú/Ú/g;s/ủ/Ủ/g;s/ũ/Ũ/g;s/ụ/Ụ/g;s/ừ/Ừ/g;s/ứ/Ứ/g;s/ử/Ử/g;s/ữ/Ữ/g;s/ự/Ự/g;s/ỳ/Ỳ/g;s/ý/Ý/g;s/ỷ/Ỷ/g;s/ỹ/Ỹ/g;s/ỵ/Ỵ/g'; }
# chữ số -> chữ (dùng lại clock_words)
words3() { # giờ phút -> 3 dòng: "hai giờ" / "hai mươi tư" / "phút chiều"
  awk -v h="$1" -v m="$2" 'function so(n,  c,d,s){split("không một hai ba bốn năm sáu bảy tám chín",U," ");
    if(n<10)return U[n+1]; c=int(n/10); d=n%10
    s=(c==1)?"mười":U[c+1]" mươi"
    if(d==0)return s; if(d==1&&c>1)return s" mốt"; if(d==5)return s" lăm"; if(d==4&&c>1)return s" tư"; return s" "U[d+1]}
    BEGIN{ b=(h<11)?"sáng":(h<13)?"trưa":(h<18)?"chiều":"tối"; h12=h%12; if(h12==0)h12=12
      printf "%s giờ\n", so(h12)
      if(m==0) printf "đúng\n%s\n", b; else printf "%s\nphút %s\n", so(m), b }'
}
