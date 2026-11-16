# Đọc file .ics (Apple/iCloud/Google), xuất các sự kiện trong khoảng ngày.
# Biến vào: TODAY (epoch-day), FROM, TO (epoch-day), TZOFF (phút lệch so với UTC, VN = 420)
# Xuất mỗi dòng: KEY|EPOCHDAY|MINUTE|ALLDAY|SUMMARY   (KEY để sort -n)
# Hỗ trợ: sự kiện thường, cả ngày, UTC (Z), RRULE DAILY/WEEKLY(BYDAY)/MONTHLY/YEARLY,
#         INTERVAL, COUNT, UNTIL, EXDATE. Không hỗ trợ: BYSETPOS, BYMONTHDAY phức tạp.
function dfc(y, m, d,   era, yoe, doy, doe) {
  y -= (m <= 2); era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function cfd(z,   era, doe, yoe, y, doy, mp) {
  z += 719468; era = int((z >= 0 ? z : z - 146096) / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
  mp = int((5 * doy + 2) / 153); CD = doy - int((153 * mp + 2) / 5) + 1
  CM = mp + (mp < 10 ? 3 : -9); CY = y + (CM <= 2)
}
# parse "YYYYMMDD[THHMMSS[Z]]" -> PD (epoch-day), PMIN (minute of day), PALL
function pdt(v, isdate,   y, m, d, h, mi) {
  y = substr(v, 1, 4) + 0; m = substr(v, 5, 2) + 0; d = substr(v, 7, 2) + 0
  PD = dfc(y, m, d); PMIN = 0; PALL = (isdate || length(v) < 15)
  if (!PALL) {
    h = substr(v, 10, 2) + 0; mi = substr(v, 12, 2) + 0; PMIN = h * 60 + mi
    if (substr(v, 16, 1) == "Z") {
      PMIN += TZOFF
      while (PMIN >= 1440) { PMIN -= 1440; PD++ }
      while (PMIN < 0) { PMIN += 1440; PD-- }
    }
  }
}
function unesc(s) { gsub(/\\n/, " ", s); gsub(/\\,/, ",", s); gsub(/\;/, ";", s); gsub(/\\\\/, "\\", s); return s }
function emit(d) {
  if (d < FROM || d > TO || (d in EX)) return
  printf "%d|%d|%d|%d|%s\n", d * 1440 + (ALL ? 0 : MIN), d, MIN, ALL, SUM
}
function expand(   f, iv, cnt, until, n, i, k, parts, kv, byday, nb, bd, wd0, w, d, dd, y, m, dm, wdmap, idx, guard) {
  if (RR == "") { emit(START); return }
  split("SU MO TU WE TH FR SA", wdmap, " ")
  f = ""; iv = 1; cnt = -1; until = 999999; byday = ""
  n = split(RR, parts, ";")
  for (i = 1; i <= n; i++) {
    split(parts[i], kv, "=")
    if (kv[1] == "FREQ") f = kv[2]
    else if (kv[1] == "INTERVAL") iv = kv[2] + 0
    else if (kv[1] == "COUNT") cnt = kv[2] + 0
    else if (kv[1] == "UNTIL") { pdt(kv[2], 0); until = PD }
    else if (kv[1] == "BYDAY") byday = kv[2]
  }
  if (iv < 1) iv = 1
  k = 0; guard = 0
  if (f == "DAILY") {
    for (d = START; d <= TO && d <= until && (cnt < 0 || k < cnt) && guard < 5000; d += iv) { emit(d); k++; guard++ }
  } else if (f == "WEEKLY") {
    nb = 0
    if (byday != "") {
      nb = split(byday, bd, ",")
      for (i = 1; i <= nb; i++) for (idx = 1; idx <= 7; idx++) if (substr(bd[i], length(bd[i]) - 1) == wdmap[idx]) bd[i] = idx - 1
    } else { nb = 1; bd[1] = (START + 4) % 7 }
    wd0 = START - (START + 4) % 7          # Chủ nhật của tuần bắt đầu
    for (w = wd0; w <= TO && w <= until && (cnt < 0 || k < cnt) && guard < 5000; w += 7 * iv) {
      for (dd = 0; dd < 7; dd++) for (i = 1; i <= nb; i++) if (bd[i] == dd) {
        d = w + dd
        if (d >= START && d <= until && (cnt < 0 || k < cnt)) { emit(d); k++ }
      }
      guard++
    }
  } else if (f == "MONTHLY" || f == "YEARLY") {
    cfd(START); y = CY; m = CM; dm = CD
    while (guard < 2000 && (cnt < 0 || k < cnt)) {
      d = dfc(y, m, dm)
      if (d > TO || d > until) break
      cfd(d); if (CD == dm) { emit(d); k++ }    # bỏ ngày không tồn tại (vd 31/2)
      if (f == "MONTHLY") { m += iv; while (m > 12) { m -= 12; y++ } } else y += iv
      guard++
    }
  } else emit(START)
}
{ sub(/\r$/, "") }
/^[ \t]/ { if (prev != "") { prev = prev substr($0, 2) }; next }
{ if (prev != "") handle(prev); prev = $0 }
END { if (prev != "") handle(prev) }
function handle(line,   name, val, p, i, n, xs) {
  p = index(line, ":"); if (p == 0) return
  name = substr(line, 1, p - 1); val = substr(line, p + 1)
  if (line == "BEGIN:VEVENT") { inev = 1; RR = ""; SUM = ""; START = ""; MIN = 0; ALL = 0; split("", EX); return }
  if (line == "END:VEVENT") { if (inev && START != "" && !CANCEL) expand(); inev = 0; CANCEL = 0; return }
  if (!inev) return
  if (name ~ /^DTSTART/) { pdt(val, name ~ /VALUE=DATE/ && name !~ /DATE-TIME/); START = PD; MIN = PMIN; ALL = PALL }
  else if (name == "SUMMARY" || name ~ /^SUMMARY;/) SUM = unesc(val)
  else if (name == "RRULE") RR = val
  else if (name ~ /^EXDATE/) { n = split(val, xs, ","); for (i = 1; i <= n; i++) { pdt(xs[i], 0); EX[PD] = 1 } }
  else if (name == "STATUS" && val == "CANCELLED") CANCEL = 1
}
