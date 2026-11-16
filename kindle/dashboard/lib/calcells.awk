# Tính sẵn toàn bộ lệnh vẽ cho lưới lịch tháng (để shell không phải gọi thêm tiến trình cho từng ô).
# Vào: Y M D(ngày đánh dấu, 0=không) WS CX CW GY RH PX LPX LUNPOS SHOWLUN TSTYLE RP CFIRST
#      LUNF (file "d|ld|lm") EVF (file các epoch-day có sự kiện)
# Xuất: T|px|top|left|style|text   (chữ; style: b, s, w = chữ trắng)
#       B|top|left|width|height     (khối đen)
#       F|top|left|width|height     (khung viền)
function dfc(y, m, d,   era, yoe, doy, doe) {
  y -= (m <= 2); era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function w(s, px) { return int(length(s) * px * 43 / 100) }
BEGIN {
  while ((getline line < LUNF) > 0) { split(line, a, "|"); LD[a[1]] = a[2]; LM[a[1]] = a[3] }
  while ((getline line < EVF) > 0) EV[line] = 1
  first = dfc(Y, M, 1); nm = M + 1; ny = Y; if (nm > 12) { nm = 1; ny++ }
  len = dfc(ny, nm, 1) - first
  wd = (first + 4) % 7; off = (WS == 1) ? (wd + 6) % 7 : wd
  sun = (WS == 1) ? 6 : 0
  for (d = 1; d <= len; d++) {
    cc = off + d - 1; row = int(cc / 7); col = cc % 7
    c = CX + col * CW + int(CW / 2); y = GY + row * RH
    sty = (col == sun) ? "b" : ""
    if (d == D) {
      sty = "b"
      if (TSTYLE == "khung") printf "F|%d|%d|%d|%d\n", y - 2, c - int(CW / 2) + 4, CW - 8, RH - 4
      else if (TSTYLE == "gach") printf "B|%d|%d|%d|4\n", y + int(PX * 70 / 100), c - int(PX / 2), PX
      else if (TSTYLE == "den") { printf "T|%d|%d|%d|s|DISC\n", RP, y + int(PX * 51 / 100) - int(RP * 51 / 100), c - int(RP * 35 / 100); sty = "w" }
      else printf "T|%d|%d|%d|s|RING\n", RP, y + int(PX * 51 / 100) - int(RP * 51 / 100), c - int(RP * 35 / 100)
    }
    printf "T|%d|%d|%d|%s|%d\n", PX, y, c - int(w(d "", PX) / 2), sty, d
    if (SHOWLUN == 1 && (d in LD)) {
      lt = (LD[d] == 1) ? "1/" LM[d] : LD[d]
      if (LUNPOS == "below") printf "T|%d|%d|%d||%s\n", LPX, y + int(PX * 78 / 100), c - int(w(lt, LPX) / 2), lt
      else printf "T|%d|%d|%d||%s\n", LPX, y + int(PX * 56 / 100), c + int(CW * 36 / 100) - int(w(lt, LPX) / 2), lt
    }
    if ((CFIRST + d - 1) in EV) printf "B|%d|%d|8|8\n", y + int(PX * 18 / 100), c + int(CW * 30 / 100)
  }
}
