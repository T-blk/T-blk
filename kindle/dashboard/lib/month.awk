# Lưới lịch tháng, tuần bắt đầu Thứ Hai. Vào: Y, M, D (hôm nay).
# Xuất: ROW|COL|DAY|ISTODAY
function dfc(y, m, d,   era, yoe, doy, doe) {
  y -= (m <= 2); era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
BEGIN {
  first = dfc(Y, M, 1); nm = M + 1; ny = Y; if (nm > 12) { nm = 1; ny++ }
  len = dfc(ny, nm, 1) - first
  off = ((first + 4) % 7 + 6) % 7          # 0 = Thứ Hai
  for (d = 1; d <= len; d++) { c = off + d - 1; printf "%d|%d|%d|%d\n", int(c / 7), c % 7, d, (d == D) }
}
