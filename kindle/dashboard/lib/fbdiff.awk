# So 2 bản chụp bộ nhớ màn hình (đầu vào: kết quả "cmp -l"), trả về các hình chữ nhật bám sát hình dạng vùng đổi.
# Biến: S (byte mỗi hàng), W H (màn hình), T (cạnh ô, mặc định 16), FX FY (bộ nhớ lật ngang/dọc), MAXR (tối đa số hình), CAP
# In:  "FULL" (đổi gần hết) · hoặc mỗi dòng "top left width height diện_tích_đổi"
{ o = $1 - 1; r = int(o / S); c = o % S; if (c >= W || r >= H) next
  if (FY) r = H - 1 - r; if (FX) c = W - 1 - c
  k = int(r / T) SUBSEP int(c / T); if (!(k in TL)) { TL[k] = 1; nt++ }; n++ }
END {
  if (n >= CAP) { print "FULL"; exit }
  if (n == 0) exit
  t = T; nr = W / t; nrow = H / t
  while (1) {
    # các ô theo hàng -> đoạn ngang -> ghép dọc các đoạn giống nhau thành hình chữ nhật
    delete OPEN; delete RT; nrect = 0
    rows = int((H + t - 1) / t); cols = int((W + t - 1) / t)
    for (y = 0; y <= rows; y++) {
      delete RUN; nrun = 0; inrun = 0
      for (x = 0; x <= cols; x++) {
        on = (y < rows && x < cols && ((y SUBSEP x) in TL))
        if (on && !inrun) { s = x; inrun = 1 }
        if (!on && inrun) { RUN[s ":" (x - 1)] = 1; inrun = 0 }
      }
      for (key in OPEN) if (!(key in RUN)) { split(OPEN[key], q, ":"); split(key, cc, ":")
        nrect++; RT[nrect] = q[1] * t " " cc[1] * t " " (cc[2] - cc[1] + 1) * t " " (y - q[1]) * t; delete OPEN[key] }
      for (key in RUN) if (!(key in OPEN)) OPEN[key] = y
    }
    if (nrect <= MAXR || t >= 256) break
    # quá nhiều hình nhỏ -> gộp ô to gấp đôi rồi làm lại
    delete T2; for (k in TL) { split(k, p, SUBSEP); T2[int(p[1] / 2) SUBSEP int(p[2] / 2)] = 1 }
    delete TL; for (k in T2) TL[k] = 1; t *= 2
  }
  tot = 0
  for (i = 1; i <= nrect; i++) { split(RT[i], v, " ")
    if (v[1] + v[4] > H) v[4] = H - v[1]; if (v[2] + v[3] > W) v[3] = W - v[2]
    RT[i] = v[1] " " v[2] " " v[3] " " v[4]; tot += v[3] * v[4] }
  if (tot >= W * H * 7 / 10) { print "FULL"; exit }
  for (i = 1; i <= nrect; i++) print RT[i]
}
