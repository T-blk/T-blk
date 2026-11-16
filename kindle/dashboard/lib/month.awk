# Lưới lịch tháng. Vào: Y, M, D (ngày cần đánh dấu, 0 = không), WS (1 = tuần bắt đầu Thứ Hai, 0 = Chủ Nhật)
# Xuất: ROW|COL|DAY|ISTODAY
function dfc(y, m, d,   era, yoe, doy, doe) {
  y -= (m <= 2); era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
BEGIN {
  if (WS == "") WS = 1
  first = dfc(Y, M, 1); nm = M + 1; ny = Y; if (nm > 12) { nm = 1; ny++ }
  len = dfc(ny, nm, 1) - first
  wd = (first + 4) % 7                      # 0 = Chủ Nhật
  off = (WS == 1) ? (wd + 6) % 7 : wd
  for (d = 1; d <= len; d++) { c = off + d - 1; printf "%d|%d|%d|%d\n", int(c / 7), c % 7, d, (d == D) }
}
