# Chọn chủ đề hoa văn + dòng chúc mừng theo ngày (dương lịch + âm lịch).
# Vào: D M Y (dương), LD LM LEAP (âm). Xuất: "chude|dòng chữ" (chude=macdinh nếu không có dịp lễ)
function dfc(y, m, d,   era, yoe, doy, doe) {
  y -= (m <= 2); era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function say(name, left) { return (left == 0) ? "Hôm nay: " name : name " · còn " left " ngày" }
function solar(ed, em, theme, name, win,   t, left) {
  t = dfc(Y, em, ed); if (t < TODAY) t = dfc(Y + 1, em, ed)
  left = t - TODAY
  if (left <= win && (best == "" || left < bestleft)) { best = theme "|" say(name, left); bestleft = left }
}
function lunar(ld, lm, theme, name, win,   left) {
  if (LEAP == 1 || LM != lm || LD > ld) return
  left = ld - LD
  if (left <= win && (best == "" || left < bestleft)) { best = theme "|" say(name, left); bestleft = left }
}
BEGIN {
  TODAY = dfc(Y, M, D); best = ""; bestleft = 999
  # Tết Nguyên Đán ưu tiên cao nhất
  if (LEAP != 1 && LM == 12 && LD >= 15) {
    if (LD == 23) { print "tet|Hôm nay: Ông Công Ông Táo"; exit }
    print "tet|Sắp Tết Nguyên Đán"; exit
  }
  if (LEAP != 1 && LM == 1 && LD <= 15) {
    if (LD == 1) { print "tet|Mùng 1 Tết · Chúc mừng năm mới!"; exit }
    if (LD <= 10) { print "tet|Mùng " LD " Tết Nguyên Đán"; exit }
    print "tet|" say("Rằm tháng Giêng", 15 - LD); exit
  }
  solar(1, 1, "duonglich", "Tết Dương lịch", 3)
  solar(14, 2, "tinhyeu", "Lễ Tình nhân 14/2", 3)
  solar(8, 3, "tinhyeu", "Quốc tế Phụ nữ 8/3", 5)
  solar(30, 4, "quockhanh", "Giải phóng miền Nam 30/4", 6)
  solar(1, 5, "quockhanh", "Quốc tế Lao động 1/5", 0)
  solar(1, 6, "thieunhi", "Quốc tế Thiếu nhi 1/6", 5)
  solar(2, 9, "quockhanh", "Quốc khánh 2/9", 6)
  solar(20, 10, "tinhyeu", "Phụ nữ Việt Nam 20/10", 5)
  solar(20, 11, "nhagiao", "Nhà giáo Việt Nam 20/11", 7)
  solar(24, 12, "noel", "Đêm Giáng sinh", 9)
  solar(25, 12, "noel", "Giáng sinh", 0)
  lunar(10, 3, "dongson", "Giỗ Tổ Hùng Vương", 5)
  lunar(15, 4, "sen", "Lễ Phật Đản", 5)
  lunar(15, 7, "sen", "Lễ Vu Lan", 7)
  lunar(15, 8, "trungthu", "Tết Trung thu", 14)
  if (best == "") best = "macdinh|"
  print best
}
