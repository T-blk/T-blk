# Âm lịch Việt Nam (thuật toán Hồ Ngọc Đức, múi giờ +7).
# Chế độ:
#   -v MODE=day   -v D= -v M= -v Y=   -> "ld|lm|ly|leap|canchi_nam"
#   -v MODE=month -v M= -v Y=         -> mỗi dòng "d|ld|lm" cho từng ngày dương của tháng
function jdn(dd, mm, yy,   a, y, m) {
  a = int((14 - mm) / 12); y = yy + 4800 - a; m = mm + 12 * a - 3
  return dd + int((153 * m + 2) / 5) + 365 * y + int(y / 4) - int(y / 100) + int(y / 400) - 32045
}
function newmoon(k,   T, T2, T3, dr, Jd1, Mm, Mpr, F, C1, dt) {
  T = k / 1236.85; T2 = T * T; T3 = T2 * T; dr = PI / 180
  Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3
  Jd1 += 0.00033 * sin((166.56 + 132.87 * T - 0.009173 * T2) * dr)
  Mm = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3
  Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3
  F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3
  C1 = (0.1734 - 0.000393 * T) * sin(Mm * dr) + 0.0021 * sin(2 * dr * Mm)
  C1 = C1 - 0.4068 * sin(Mpr * dr) + 0.0161 * sin(dr * 2 * Mpr)
  C1 = C1 - 0.0004 * sin(dr * 3 * Mpr)
  C1 = C1 + 0.0104 * sin(dr * 2 * F) - 0.0051 * sin(dr * (Mm + Mpr))
  C1 = C1 - 0.0074 * sin(dr * (Mm - Mpr)) + 0.0004 * sin(dr * (2 * F + Mm))
  C1 = C1 - 0.0004 * sin(dr * (2 * F - Mm)) - 0.0006 * sin(dr * (2 * F + Mpr))
  C1 = C1 + 0.0010 * sin(dr * (2 * F - Mpr)) + 0.0005 * sin(dr * (2 * Mpr + Mm))
  if (T < -11) dt = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3
  else dt = -0.000278 + 0.000265 * T + 0.000262 * T2
  return fl(Jd1 + C1 - dt + 0.5 + TZ / 24)
}
function sunlong(jd,   T, T2, dr, Mm, L0, DL, L) {
  T = (jd - 2451545.5 - TZ / 24) / 36525; T2 = T * T; dr = PI / 180
  Mm = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2
  L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2
  DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * sin(dr * Mm)
  DL = DL + (0.019993 - 0.000101 * T) * sin(dr * 2 * Mm) + 0.000290 * sin(dr * 3 * Mm)
  L = (L0 + DL) * dr; L = L - PI * 2 * fl(L / (PI * 2))
  return fl(L / PI * 6)
}
function fl(x) { return (x >= 0 || x == int(x)) ? int(x) : int(x) - 1 }
function month11(yy,   off, k, nm) {
  off = jdn(31, 12, yy) - 2415021; k = fl(off / 29.530588853)
  nm = newmoon(k); if (sunlong(nm) >= 9) nm = newmoon(k - 1)
  return nm
}
function leapoff(a11,   k, last, i, arc) {
  k = fl((a11 - 2415021.076998695) / 29.530588853 + 0.5); last = 0; i = 1
  arc = sunlong(newmoon(k + i))
  do { last = arc; i++; arc = sunlong(newmoon(k + i)) } while (arc != last && i < 14)
  return i - 1
}
function s2l(dd, mm, yy,   dn, k, ms, a11, b11, diff, lo) {
  dn = jdn(dd, mm, yy); k = fl((dn - 2415021.076998695) / 29.530588853)
  ms = newmoon(k + 1); if (ms > dn) ms = newmoon(k)
  a11 = month11(yy); b11 = a11
  if (a11 >= ms) { LY = yy; a11 = month11(yy - 1) } else { LY = yy + 1; b11 = month11(yy + 1) }
  LD = dn - ms + 1; diff = fl((ms - a11) / 29); LLEAP = 0; LM = diff + 11
  if (b11 - a11 > 365) { lo = leapoff(a11); if (diff >= lo) { LM = diff + 10; if (diff == lo) LLEAP = 1 } }
  if (LM > 12) LM -= 12
  if (LM >= 11 && diff < 4) LY -= 1
}
BEGIN {
  PI = atan2(0, -1); TZ = 7
  split("Canh Tân Nhâm Quý Giáp Ất Bính Đinh Mậu Kỷ", CAN, " ")
  split("Thân Dậu Tuất Hợi Tý Sửu Dần Mão Thìn Tỵ Ngọ Mùi", CHI, " ")
  if (MODE == "month") {
    nm = M + 1; ny = Y; if (nm > 12) { nm = 1; ny++ }
    len = jdn(1, nm, ny) - jdn(1, M, Y)
    for (d = 1; d <= len; d++) { s2l(d, M, Y); printf "%d|%d|%d\n", d, LD, LM }
  } else {
    s2l(D, M, Y)
    printf "%d|%d|%d|%d|%s %s\n", LD, LM, LY, LLEAP, CAN[LY % 10 + 1], CHI[LY % 12 + 1]
  }
}
