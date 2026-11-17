# Bộ máy Sudoku: đọc trạng thái, làm 1 thao tác, ghi trạng thái mới, in ra những gì cần vẽ lại.
# Biến vào: ACT (full sel num erase undo hint check note auto new), ARG, NOWT (giây đã chơi),
#           SAVE (file trạng thái), UNDO (file hoàn tác), NEWL NEWP NEWS SEED (khi ACT=new)
# In ra:  C ô nền số kiểu ghi_chú lỗi   (nền: w trắng · s đang chọn · h cùng số; kiểu: g đề · u người chơi)
#         PAD c1..c9 (số lượng mỗi chữ số đã có) · TOP lỗi gợi_ý ghi_chú báo_lỗi mức · WIN giây lỗi gợi_ý
function peers_clear(i, d,   r, c, br, bc, k, j, m) {
  r = int(i / 9); c = i % 9; br = int(r / 3) * 3; bc = int(c / 3) * 3; m = 2 ^ (d - 1)
  for (k = 0; k < 9; k++) {
    j = r * 9 + k; if (int(N[j] / m) % 2) N[j] -= m
    j = k * 9 + c; if (int(N[j] / m) % 2) N[j] -= m
    j = (br + int(k / 3)) * 9 + bc + k % 3; if (int(N[j] / m) % 2) N[j] -= m
  }
}
function val(i) { return P[i] != 0 ? P[i] : U[i] }
function visual(i,   v, bg, st, e, nt, sd) {
  v = val(i); st = (P[i] != 0) ? "g" : "u"
  sd = (SEL >= 0) ? val(SEL) : 0
  bg = "w"; if (i == SEL) bg = "s"; else if (sd != 0 && v == sd) bg = "h"
  e = (st == "u" && v != 0 && v != S[i] && (AUTO || CHK)) ? 1 : 0
  nt = (v == 0) ? N[i] : 0
  return bg " " v " " st " " nt " " e
}
function pushundo(   s, i) { s = ""; for (i = 0; i < 81; i++) s = s U[i]; s = s "|"; for (i = 0; i < 81; i++) s = s (i ? " " : "") N[i]; UN[++nu] = s }
function counts(   i, d, s) { for (d = 1; d <= 9; d++) CNT[d] = 0; for (i = 0; i < 81; i++) if (val(i)) CNT[val(i)]++
  s = ""; for (d = 1; d <= 9; d++) s = s " " CNT[d]; return s }
function topline() { return MIS " " HIN " " NM " " AUTO " " LV }
function solved(   i) { for (i = 0; i < 81; i++) if (val(i) != S[i]) return 0; return 1 }
function shuffle(a, n,   i, j, t) { for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t } }
# xáo đề: đổi tên chữ số, đổi hàng/cột trong khối, đổi khối, xoay 90° -> cùng độ khó, đề mới
function transform(p, s,   map, rr, cc, b, i, k, r, c, sr, sc, tp, ts, rot, t) {
  for (k = 1; k <= 9; k++) map[k] = k; shuffle(map, 9)
  for (b = 0; b < 3; b++) { for (k = 1; k <= 3; k++) t[k] = k; shuffle(t, 3); for (k = 1; k <= 3; k++) rr[b * 3 + k - 1] = b * 3 + t[k] - 1 }
  for (k = 1; k <= 3; k++) t[k] = k; shuffle(t, 3); for (b = 0; b < 3; b++) for (k = 0; k < 3; k++) RB[b * 3 + k] = (t[b + 1] - 1) * 3 + k
  for (b = 0; b < 3; b++) { for (k = 1; k <= 3; k++) t[k] = k; shuffle(t, 3); for (k = 1; k <= 3; k++) cc[b * 3 + k - 1] = b * 3 + t[k] - 1 }
  for (k = 1; k <= 3; k++) t[k] = k; shuffle(t, 3); for (b = 0; b < 3; b++) for (k = 0; k < 3; k++) CB[b * 3 + k] = (t[b + 1] - 1) * 3 + k
  rot = (rand() < 0.5)
  tp = ""; ts = ""
  for (i = 0; i < 81; i++) {
    r = int(i / 9); c = i % 9
    if (rot) { k = r; r = c; c = 8 - k }
    sr = rr[RB[r]]; sc = cc[CB[c]]
    k = substr(p, sr * 9 + sc + 1, 1) + 0; tp = tp (k ? map[k] : 0)
    k = substr(s, sr * 9 + sc + 1, 1) + 0; ts = ts map[k]
  }
  NEWP = tp; NEWS = ts
}
BEGIN {
  SEL = -1; NM = 0; AUTO = 1; CHK = 0; T = 0; MIS = 0; HIN = 0; DONE = 0; LV = 2
  for (i = 0; i < 81; i++) { P[i] = 0; S[i] = 0; U[i] = 0; N[i] = 0 }
  while ((getline line < SAVE) > 0) {
    k = substr(line, 1, index(line, " ") - 1); v = substr(line, index(line, " ") + 1)
    if (k == "P" || k == "S" || k == "U") { for (i = 0; i < 81; i++) { d = substr(v, i + 1, 1) + 0; if (k == "P") P[i] = d; else if (k == "S") S[i] = d; else U[i] = d } }
    else if (k == "N") { n = split(v, nn, " "); for (i = 0; i < 81; i++) N[i] = nn[i + 1] + 0 }
    else if (k == "SEL") SEL = v + 0; else if (k == "NM") NM = v + 0; else if (k == "AUTO") AUTO = v + 0
    else if (k == "CHK") CHK = v + 0; else if (k == "T") T = v + 0; else if (k == "MIS") MIS = v + 0
    else if (k == "HIN") HIN = v + 0; else if (k == "DONE") DONE = v + 0; else if (k == "L") LV = v + 0
  }
  close(SAVE)
  nu = 0; while ((getline line < UNDO) > 0) UN[++nu] = line; close(UNDO)
  if (ACT == "new") {
    srand(SEED + 0); transform(NEWP, NEWS)
    for (i = 0; i < 81; i++) { P[i] = substr(NEWP, i + 1, 1) + 0; S[i] = substr(NEWS, i + 1, 1) + 0; U[i] = 0; N[i] = 0 }
    SEL = -1; NM = 0; CHK = 0; T = 0; MIS = 0; HIN = 0; DONE = 0; LV = NEWL + 0; nu = 0; ACT = "full"
  }
  for (i = 0; i < 81; i++) OLD[i] = visual(i)
  oc = counts(); ot = topline(); od = DONE
  if (NOWT != "") T = NOWT + 0
  a = ARG + 0
  if (DONE && ACT != "full" && ACT != "auto") ACT = "none"
  if (ACT == "sel") { if (a >= 0 && a < 81) SEL = a }
  else if (ACT == "num" && SEL >= 0 && P[SEL] == 0 && a >= 1 && a <= 9) {
    if (NM) { if (U[SEL] == 0) { pushundo(); m = 2 ^ (a - 1); if (int(N[SEL] / m) % 2) N[SEL] -= m; else N[SEL] += m } }
    else {
      pushundo(); CHK = 0
      if (U[SEL] == a) U[SEL] = 0
      else { U[SEL] = a; N[SEL] = 0
        if (a != S[SEL]) { if (AUTO) MIS++ } else peers_clear(SEL, a) }
    }
  }
  else if (ACT == "erase" && SEL >= 0 && P[SEL] == 0 && (U[SEL] || N[SEL])) { pushundo(); U[SEL] = 0; N[SEL] = 0 }
  else if (ACT == "undo" && nu > 0) {
    split(UN[nu], b, "|"); nu--
    for (i = 0; i < 81; i++) U[i] = substr(b[1], i + 1, 1) + 0
    split(b[2], a2, " "); for (i = 0; i < 81; i++) N[i] = a2[i + 1] + 0
  }
  else if (ACT == "hint") {
    t = -1
    if (SEL >= 0 && P[SEL] == 0 && U[SEL] != S[SEL]) t = SEL
    else { srand(); m = 0; for (i = 0; i < 81; i++) if (P[i] == 0 && U[i] != S[i]) { m++; if (rand() * m < 1) t = i } }
    if (t >= 0) { pushundo(); U[t] = S[t]; N[t] = 0; peers_clear(t, S[t]); SEL = t; HIN++ }
  }
  else if (ACT == "check") CHK = 1
  else if (ACT == "note") NM = 1 - NM
  else if (ACT == "auto") AUTO = 1 - AUTO
  if (!DONE && solved()) { DONE = 1; SEL = -1 }
  # ghi trạng thái
  s = ""; for (i = 0; i < 81; i++) s = s P[i]; printf "P %s\n", s > SAVE
  s = ""; for (i = 0; i < 81; i++) s = s S[i]; printf "S %s\n", s > SAVE
  s = ""; for (i = 0; i < 81; i++) s = s U[i]; printf "U %s\n", s > SAVE
  s = ""; for (i = 0; i < 81; i++) s = s (i ? " " : "") N[i]; printf "N %s\n", s > SAVE
  printf "SEL %d\nNM %d\nAUTO %d\nCHK %d\nT %d\nMIS %d\nHIN %d\nDONE %d\nL %d\n", SEL, NM, AUTO, CHK, T, MIS, HIN, DONE, LV > SAVE
  close(SAVE)
  st = nu > 100 ? nu - 99 : 1; printf "" > UNDO; for (i = st; i <= nu; i++) print UN[i] > UNDO; close(UNDO)
  # những gì cần vẽ lại
  for (i = 0; i < 81; i++) { nv = visual(i); if (ACT == "full" || nv != OLD[i]) print "C " i " " nv }
  nc = counts(); if (ACT == "full" || nc != oc) print "PAD" nc
  ntp = topline(); if (ACT == "full" || ntp != ot) print "TOP " ntp
  if (DONE && !od) print "WIN " T " " MIS " " HIN " " LV
}
