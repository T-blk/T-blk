# Tin tức đọc offline cho Kindle Dashboard (được dash.sh nạp).
# RSS -> /tmp/dash_news.txt (mỗi dòng: nguồn|tiêu đề|tóm tắt|link|epoch)
# Bài viết đầy đủ -> /tmp/dash_article.txt -> chia trang để đọc.

NEWS=/tmp/dash_news.txt
NEWS_STAMP=/tmp/dash_news.stamp
: "${NEWS_FEEDS:=VnExpress=https://vnexpress.net/rss/tin-moi-nhat.rss TuoiTre=https://tuoitre.vn/rss/tin-moi-nhat.rss}"
: "${NEWS_MIN:=30}" "${NEWS_ROTATE_MIN:=5}"
NEWS_OFF=0; RD_PAGE=0; RD_LINK=""; RD_TITLE=""; RD_SRC=""

# Bỏ thẻ HTML, CDATA và các ký tự HTML thường gặp
html_clean() {
  sed -e 's/<!\[CDATA\[//g; s/\]\]>//g' -e 's/<[^>]*>//g' \
      -e 's/&amp;/\&/g; s/&quot;/"/g; s/&#39;/'"'"'/g; s/&apos;/'"'"'/g; s/&lt;/</g; s/&gt;/>/g; s/&nbsp;/ /g' \
      -e 's/&#[0-9]*;//g; s/&[a-z]*;//g' -e 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

# RSS (1 file) -> các dòng nguồn|tiêu đề|tóm tắt|link|ngày
rss_parse() { # $1 = tên nguồn, đọc RSS từ stdin
  tr '\r\n\t' '   ' | awk '{ gsub(/<item[ >]/, "\n&"); print }' | grep '^<item' | awk -v SRC="$1" '
    function tag(s, t,   a, b, r) { a = index(s, "<" t ">"); if (!a) { a = index(s, "<" t " "); if (!a) return ""; a = index(substr(s, a), ">") + a - 1 } else a = a + length(t) + 1
      r = substr(s, a + 1); b = index(r, "</" t ">"); return b ? substr(r, 1, b - 1) : "" }
    { t = tag($0, "title"); d = tag($0, "description"); l = tag($0, "link"); p = tag($0, "pubDate")
      gsub(/\|/, "/", t); gsub(/\|/, "/", d)
      if (t != "") print SRC "|" t "|" d "|" l "|" p }' | {
    while IFS='|' read -r src t d l p; do
      t=$(echo "$t" | html_clean); d=$(echo "$d" | html_clean); l=$(echo "$l" | html_clean); p=$(echo "$p" | html_clean)
      echo "$src|$t|$d|$l|$(pub_epoch "$p")"
    done
  }
}

# "Mon, 16 Nov 2026 14:05:00 +0700" (hoặc GMT+7) -> epoch (UTC)
pub_epoch() {
  echo "$1" | awk '{
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", MN, " "); m = 0
    for (i = 1; i <= 12; i++) if (MN[i] == $3) m = i
    if (!m) { print 0; exit }
    d = $2 + 0; y = $4 + 0; split($5, t, ":")
    z = $6; off = 0
    if (z ~ /^[+-][0-9][0-9][0-9][0-9]$/) off = (substr(z, 2, 2) * 60 + substr(z, 4, 2)) * (substr(z, 1, 1) == "-" ? -1 : 1)
    else if (z ~ /GMT[+-][0-9]+/) { sub(/GMT/, "", z); off = z * 60 }
    yy = y - (m <= 2); era = int(yy / 400); yoe = yy - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
    days = era * 146097 + yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy - 719468
    print days * 86400 + t[1] * 3600 + t[2] * 60 + t[3] - off * 60 }'
}

fetch_news() {
  [ -n "$NEWS_FEEDS" ] || return 0
  due "$NEWS_STAMP" "$NEWS_MIN" || return 0
  : > "$NEWS.new"
  for f in $NEWS_FEEDS; do
    src="${f%%=*}"; url="${f#*=}"
    if fetch "$url" /tmp/dash_rss.xml "<item"; then rss_parse "$src" < /tmp/dash_rss.xml | head -15 >> "$NEWS.new"; fi
  done
  if [ -s "$NEWS.new" ]; then sort -t'|' -k5,5nr "$NEWS.new" | head -24 > "$NEWS"; fi
  rm -f "$NEWS.new"; date +%s > "$NEWS_STAMP"
  log "news: $(wc -l < "$NEWS" 2>/dev/null) items"
}

news_count() { [ -s "$NEWS" ] && wc -l < "$NEWS" | tr -d ' ' || echo 0; }
news_index() { # tin nổi bật hiện tại: đổi mỗi NEWS_ROTATE_MIN phút
  n=$(news_count); [ "$n" -gt 0 ] || { echo 0; return; }
  i=$(( ( $(date +%s) / (NEWS_ROTATE_MIN * 60) + NEWS_OFF ) % n )); [ $i -lt 0 ] && i=$(( i + n )); echo $(( i + 1 ))
}
news_item() { sed -n "${1}p" "$NEWS"; }         # -> nguồn|tiêu đề|tóm tắt|link|epoch
ago() { # epoch -> "12 phút trước"
  [ "${1:-0}" -gt 0 ] || { echo ""; return; }
  s=$(( $(date +%s) - $1 )); [ $s -lt 0 ] && s=0
  if [ $s -lt 3600 ]; then echo "$(( s / 60 )) phút trước"; elif [ $s -lt 86400 ]; then echo "$(( s / 3600 )) giờ trước"; else echo "$(( s / 86400 )) ngày trước"; fi
}

# Ô tin nổi bật: top left width height
draw_news_card() {
  ny=$1; nx=$2; nw=$3; nh=$4
  i=$(news_index); [ "$i" -gt 0 ] || { txt 24 $(( ny + 10 )) $nx "Chưa có tin (cần Wi-Fi)" "" $nw; return; }
  it=$(news_item "$i"); src=$(echo "$it" | cut -d'|' -f1); t=$(echo "$it" | cut -d'|' -f2); d=$(echo "$it" | cut -d'|' -f3); e=$(echo "$it" | cut -d'|' -f5)
  frame $ny $nx $nw $nh 2
  txt 20 $(( ny + 10 )) $(( nx + 16 )) "TIN MỚI · $src · $(ago "$e")" b $(( nw - 120 )) 30
  txt 20 $(( ny + 10 )) $(( nx + nw - 96 )) "$i/$(news_count)" "" 80 30
  txt 30 $(( ny + 40 )) $(( nx + 16 )) "$t" b $(( nw - 32 )) 84
  txt 22 $(( ny + 128 )) $(( nx + 16 )) "$d" "" $(( nw - 32 )) $(( nh - 160 ))
  txt 18 $(( ny + nh - 28 )) $(( nx + nw - 190 )) "Chạm để đọc toàn bài ›" b 180 26
  NEWS_CARD="$ny $nx $nw $nh $i"
}

# ---------- Đọc bài ----------
article_fetch() { # $1 = link -> /tmp/dash_article.txt (mỗi đoạn một dòng)
  : > /tmp/dash_article.txt
  wifi_on >/dev/null 2>&1
  fetch "$1" /tmp/dash_article.html "<p" || return 1
  tr '\r\n\t' '   ' < /tmp/dash_article.html | awk '{ gsub(/<script[^>]*>[^<]*<\/script>/, ""); gsub(/<p[ >]/, "\n&"); gsub(/<\/p>/, "&\n"); print }' \
    | grep '^<p' | html_clean | awk 'length($0) > 60' | head -80 > /tmp/dash_article.txt
  [ -s /tmp/dash_article.txt ]
}
# Chia đoạn văn thành dòng ~CH ký tự, mỗi trang LP dòng -> /tmp/dash_pages.txt (dòng trống phân đoạn; "\f" ngắt trang)
article_paginate() { # $1 = số ký tự/dòng  $2 = số dòng/trang  $3 = số dòng dành cho tiêu đề ở trang đầu
  awk -v CH="$1" -v LP="$2" -v FC="${3:-0}" '
    function clen(s,   c) { c = s; return length(s) - gsub(/[\200-\277]/, "", c) }
    function out(l) { print l; n++; if (n >= (pg == 0 ? LP - FC : LP)) { print "\f"; n = 0; pg++ } }
    { line = ""; m = split($0, w, " ")
      for (k = 1; k <= m; k++) {
        if (line == "") line = w[k]
        else if (clen(line) + 1 + clen(w[k]) <= CH) line = line " " w[k]
        else { out(line); line = w[k] } }
      if (line != "") out(line)
      if (n > 0) out("") }' /tmp/dash_article.txt > /tmp/dash_pages.txt
  RD_NP=$(( $(grep -c "$(printf '\f')" /tmp/dash_pages.txt) + 1 ))
}
reader_page_text() { # $1 = số trang (0..) -> văn bản trang đó
  awk -v P="$1" 'BEGIN { RS = "\f" } NR == P + 1 { sub(/^\n/, ""); printf "%s", $0 }' /tmp/dash_pages.txt
}
open_reader() { # $1 = chỉ số tin
  it=$(news_item "$1"); RD_SRC=$(echo "$it" | cut -d'|' -f1); RD_TITLE=$(echo "$it" | cut -d'|' -f2)
  RD_SUM=$(echo "$it" | cut -d'|' -f3); RD_LINK=$(echo "$it" | cut -d'|' -f4)
  "$FB" -q -c -m -M -t "regular=$BOLD,px=34" "Đang tải bài…" >/dev/null 2>&1
  if ! article_fetch "$RD_LINK"; then echo "$RD_SUM" > /tmp/dash_article.txt; echo "(Không tải được toàn bài, đang hiện tóm tắt.)" >> /tmp/dash_article.txt; fi
  if [ $W -gt $H ]; then article_paginate 80 16 3; else article_paginate 54 24 5; fi
  RD_PAGE=0; VIEW=reader
  log "reader: $RD_SRC $RD_LINK ($RD_NP trang)"
}
render_reader() {
  "$FB" -q -b -k >/dev/null 2>&1
  txt 30 18 40 "$I_LEFT" s; txt 26 20 76 "Quay lại" b 160
  txt 22 24 $(( W - 260 )) "$RD_SRC · trang $(( RD_PAGE + 1 ))/$RD_NP" "" 220
  box 66 40 $(( W - 80 )) 2
  y=84
  if [ $RD_PAGE = 0 ]; then txt 34 $y 40 "$RD_TITLE" b $(( W - 80 )) 140; y=$(( y + 140 )); fi
  body=$(reader_page_text $RD_PAGE)
  "$FB" -q -b -O -t "regular=$REG,px=30,top=$y,left=40,right=40,bottom=70" "$body" >/dev/null 2>&1
  txt 20 $(( H - 44 )) 40 "‹ chạm trái: trang trước     chạm phải: trang sau ›" "" $(( W - 80 )) 30
  refresh 1
}
reader_tap() { # x y
  if [ $2 -le 70 ]; then VIEW=main; return; fi
  if [ $1 -lt $(( W / 2 )) ]; then [ $RD_PAGE -gt 0 ] && RD_PAGE=$((RD_PAGE - 1))
  else [ $RD_PAGE -lt $(( RD_NP - 1 )) ] && RD_PAGE=$((RD_PAGE + 1)); fi
}

# ---------- Trang Tin tức ----------
render_news() {
  common_date
  "$FB" -q -b -k >/dev/null 2>&1
  txt 30 18 40 "Tin tức" b; txt 20 26 170 "đổi tin nổi bật mỗi $NEWS_ROTATE_MIN phút · chạm để đọc" "" 330
  page_icons 18
  box 66 40 $(( W - 80 )) 2
  n=$(news_count)
  if [ "$n" = 0 ]; then txt 28 120 40 "Chưa có tin. Bật Wi-Fi, tin sẽ tự tải sau ít phút." "" $(( W - 80 )); refresh "$1"; return; fi
  cur=$(news_index)
  draw_news_card 80 40 678 300
  y=400; k=1
  head -8 "$NEWS" | while IFS='|' read -r src t d l e; do
    [ $k = $cur ] && { k=$((k + 1)); continue; }
    txt 18 $y 40 "$src · $(ago "$e")" b 400 26
    txt 26 $(( y + 26 )) 40 "$t" "" 678 72
    box $(( y + 98 )) 40 678 1
    y=$(( y + 106 )); k=$((k + 1))
    [ $y -gt $(( H - 110 )) ] && break
  done
  refresh "$1"
}
news_list_tap() { # x y trên trang Tin tức -> mở bài
  set -- $NEWS_CARD
  if [ -n "$1" ] && [ $CY_TAP -ge $1 ] && [ $CY_TAP -le $(( $1 + $4 )) ]; then open_reader "$5"; return; fi
  [ $CY_TAP -ge 400 ] || return
  row=$(( (CY_TAP - 400) / 106 )); cur=$(news_index)
  idx=$(( row + 1 )); [ $idx -ge $cur ] && idx=$(( idx + 1 ))
  [ $idx -le $(news_count) ] && open_reader $idx
}
