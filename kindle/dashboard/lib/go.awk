# Cờ vây: bàn 9/13/19, ăn quân, cấm tự sát, luật ko, bỏ lượt, đánh dấu quân chết, tính điểm khu vực
# (luật Trung Quốc: quân + đất, Trắng cộng komi) + máy chơi theo kinh nghiệm (mức tập chơi).
# Biến vào: ACT (full play pass undo ai resign new dead finish resume), ARG (điểm 0..N*N-1), SAVE,
#           NN NMODE NPC (khi new)
# In ra:  G điểm quân nướccuối chết đất · TOP lượt ăn_đen ăn_trắng giaiđoạn sốlượtbỏ chếđộ màungười N kết_quả
#         AI (đến lượt máy) · MSG thông_báo
function nb(i, k,   r, c) { r = int(i / N); c = i % N
  if (k == 1) return r > 0 ? i - N : -1; if (k == 2) return r < N - 1 ? i + N : -1
  if (k == 3) return c > 0 ? i - 1 : -1; return c < N - 1 ? i + 1 : -1 }
function group(i,   col, st, sp, j, k, q, libs) {   # -> GR[] (các quân trong nhóm), GN, GL (số khí)
  delete GR; delete SEEN; delete LIB; col = B[i]; GN = 0; GL = 0; sp = 1; st[1] = i; SEEN[i] = 1
  while (sp > 0) { j = st[sp--]; GR[++GN] = j
    for (k = 1; k <= 4; k++) { q = nb(j, k); if (q < 0) continue
      if (B[q] == "." && !(q in LIB)) { LIB[q] = 1; GL++ }
      else if (B[q] == col && !(q in SEEN)) { SEEN[q] = 1; st[++sp] = q } } }
  return GL
}
function opp(c) { return c == "b" ? "w" : "b" }
function tryplay(i, col,   k, q, o, cap, n, j, cnt) {   # đặt quân thật; trả số quân ăn được, -1 nếu không hợp lệ
  if (B[i] != "." || i == KO) return -1
  B[i] = col; o = opp(col); cnt = 0; delete CAPS
  for (k = 1; k <= 4; k++) { q = nb(i, k); if (q < 0 || B[q] != o) continue
    if (group(q) == 0) for (j = 1; j <= GN; j++) { if (B[GR[j]] == o) { B[GR[j]] = "."; CAPS[++cnt] = GR[j] } } }
  if (group(i) == 0) { B[i] = "."; for (j = 1; j <= cnt; j++) B[CAPS[j]] = o; return -1 }   # tự sát
  NEWKO = -1; if (cnt == 1 && GN == 1 && GL == 1) NEWKO = CAPS[1]
  return cnt
}
function undoplay(i, col, cnt,   j) { B[i] = "."; for (j = 1; j <= cnt; j++) B[CAPS[j]] = opp(col) }
function bstr(   i, s) { s = ""; for (i = 0; i < N * N; i++) s = s B[i]; return s }
function setb(s,   i) { for (i = 0; i < N * N; i++) B[i] = substr(s, i + 1, 1) }
function push() { H[++NH] = bstr() " " TURN " " CB " " CW " " KO " " PASS " " LAST }
function pop(   a) { split(H[NH], a, " "); NH--; setb(a[1]); TURN = a[2]; CB = a[3] + 0; CW = a[4] + 0; KO = a[5] + 0; PASS = a[6] + 0; LAST = a[7] + 0 }
function doplay(i,   c) {
  push(); c = tryplay(i, TURN)
  if (c < 0) { NH--; MSG = (i == KO) ? "Không được đi ngay vào chỗ ko — đi chỗ khác một nước trước" : "Không được tự sát (đặt quân hết khí)"; return 0 }
  if (TURN == "b") CB += c; else CW += c
  KO = NEWKO; PASS = 0; LAST = i; TURN = opp(TURN); return 1
}
function dopass() { push(); PASS++; KO = -1; LAST = -1; TURN = opp(TURN); if (PASS >= 2) { PH = "score"; autodead() } }
function territory(   i, j, k, q, sp, st, seen, reg, rn, bb, ww, x) {   # -> T[] chủ đất của mỗi ô trống ("b", "w", ".")
  delete T; delete seen
  for (i = 0; i < N * N; i++) { if (EB(i) != "." || (i in seen)) continue
    sp = 1; st[1] = i; seen[i] = 1; rn = 0; bb = 0; ww = 0
    while (sp > 0) { j = st[sp--]; reg[++rn] = j
      for (k = 1; k <= 4; k++) { q = nb(j, k); if (q < 0) continue; x = EB(q)
        if (x == ".") { if (!(q in seen)) { seen[q] = 1; st[++sp] = q } } else if (x == "b") bb = 1; else ww = 1 } }
    for (k = 1; k <= rn; k++) T[reg[k]] = (bb && !ww) ? "b" : ((ww && !bb) ? "w" : ".") }
}
function EB(i) { return (B[i] != "." && substr(DEAD, i + 1, 1) == "1") ? "." : B[i] }   # bàn sau khi bỏ quân chết
function score(   i, sb, sw) {
  territory(); sb = 0; sw = KOMI
  for (i = 0; i < N * N; i++) { x = EB(i); if (x == "b") sb++; else if (x == "w") sw++; else if (T[i] == "b") sb++; else if (T[i] == "w") sw++ }
  SB = sb; SW = sw
  return (sb > sw) ? "Đen thắng " (sb - sw) " điểm" : "Trắng thắng " (sw - sb) " điểm"
}
function setdead(i, v,   j, s) {   # đánh dấu cả nhóm của ô i
  group(i); for (j = 1; j <= GN; j++) DEAD = substr(DEAD, 1, GR[j]) v substr(DEAD, GR[j] + 2)
}
function autodead(   i, done) {   # gợi ý quân chết: nhóm chỉ còn 1 khí khi hết ván
  DEAD = ""; for (i = 0; i < N * N; i++) DEAD = DEAD "0"
  delete done
  for (i = 0; i < N * N; i++) if (B[i] != "." && !(i in done)) { if (group(i) <= 1 && GN <= 6) setdead(i, "1"); for (j = 1; j <= GN; j++) done[GR[j]] = 1 }
}
function aiscore(i, col,   s, c, k, q, o, r, cc, d, own, l0, pre, sz, e, j) {   # điểm kinh nghiệm cho nước đi i
  o = opp(col); s = 0
  # khí các nhóm kề trước khi đi
  delete PRE
  for (k = 1; k <= 4; k++) { q = nb(i, k); if (q >= 0 && B[q] != ".") { group(q); PRE[k] = GL; PRS[k] = GN } }
  # không tự lấp mắt của mình
  own = 0; e = 0
  for (k = 1; k <= 4; k++) { q = nb(i, k); if (q < 0) { own++; continue } if (B[q] == col) own++ }
  if (own == 4) { e = 1; s -= 400 }
  c = tryplay(i, col); if (c < 0) return -99999
  s += c * 120
  group(i); l0 = GL; sz = GN
  if (l0 == 1 && c == 0) s -= 150 + sz * 20               # tự đưa vào thế bị ăn
  else if (l0 == 2) s -= 10
  for (k = 1; k <= 4; k++) { q = nb(i, k); if (q < 0) continue
    if (PRE[k] == 1 && B[q] == col) s += 90 * PRS[k]       # cứu nhóm đang bị dọa ăn
    if (B[q] == o) { group(q); if (GL == 1) s += 35 * GN; else if (GL == 2) s += 6 } }
  undoplay(i, col, c)
  r = int(i / N); cc = i % N; d = r; if (cc < d) d = cc; if (N - 1 - r < d) d = N - 1 - r; if (N - 1 - cc < d) d = N - 1 - cc
  if (d == 0) s -= (MOVES < 3 * N) ? 45 : 18                  # mép bàn: chỉ đi khi cần (ăn quân, cứu quân)
  else if (d == 1) s -= (MOVES < 2 * N) ? 18 : 4
  else if ((d == 2 || d == 3) && MOVES < 2 * N) s += 16
  if (MOVES < N && N >= 13) { if ((r == 3 || r == N - 4) && (cc == 3 || cc == N - 4)) s += 20 }   # khai cuộc: góc sao
  if (LAST >= 0 && d >= 2) { j = (int(LAST / N) - r); if (j < 0) j = -j; k = (LAST % N - cc); if (k < 0) k = -k; if (j + k <= 3) s += 7 - (j + k) * 2 }
  s += int(rand() * 9)
  return s
}
function aimove(   i, best, bi, sc) {
  best = -99999; bi = -1
  for (i = 0; i < N * N; i++) { if (B[i] != ".") continue; sc = aiscore(i, TURN); if (sc > best) { best = sc; bi = i } }
  if (bi < 0 || best < -60 || (PASS > 0 && best < 20)) { dopass(); return }
  doplay(bi)
}
function visual(i,   t) {
  t = "."; if (PH != "play") t = (i in T) ? T[i] : "."
  return B[i] " " (i == LAST ? 1 : 0) " " ((PH != "play" && B[i] != "." && substr(DEAD, i + 1, 1) == "1") ? 1 : 0) " " t
}
BEGIN {
  N = 9; TURN = "b"; CB = 0; CW = 0; KO = -1; PASS = 0; LAST = -1; MODE = "2p"; PC = "b"; PH = "play"; NH = 0; RES = "-"; DEAD = ""
  while ((getline line < SAVE) > 0) {
    k = substr(line, 1, index(line, " ") - 1); v = substr(line, index(line, " ") + 1)
    if (k == "N") N = v + 0; else if (k == "B") BS = v; else if (k == "H") H[++NH] = v
    else if (k == "TURN") TURN = v; else if (k == "CB") CB = v + 0; else if (k == "CW") CW = v + 0
    else if (k == "KO") KO = v + 0; else if (k == "PASS") PASS = v + 0; else if (k == "LAST") LAST = v + 0
    else if (k == "MODE") MODE = v; else if (k == "PC") PC = v; else if (k == "PH") PH = v
    else if (k == "RES") RES = v; else if (k == "DEAD") DEAD = v
  }
  close(SAVE)
  if (ACT == "new") { N = NN + 0; MODE = NMODE; PC = NPC; TURN = "b"; CB = 0; CW = 0; KO = -1; PASS = 0; LAST = -1; PH = "play"; NH = 0; RES = "-"; BS = ""; ACT = "full" }
  if (BS == "") for (i = 0; i < N * N; i++) BS = BS "."
  setb(BS); KOMI = (N == 9) ? 7 : 6.5; MOVES = 0; for (i = 0; i < N * N; i++) if (B[i] != ".") MOVES++
  if (DEAD == "") for (i = 0; i < N * N; i++) DEAD = DEAD "0"
  if (PH != "play") territory()
  for (i = 0; i < N * N; i++) OLD[i] = visual(i)
  srand(); a = ARG + 0; MSG = ""
  myturn = (MODE == "2p" || TURN == PC)
  if (ACT == "play" && PH == "play" && myturn && a >= 0 && a < N * N) doplay(a)
  else if (ACT == "pass" && PH == "play" && myturn) dopass()
  else if (ACT == "ai" && PH == "play" && MODE == "ai" && TURN != PC) aimove()
  else if (ACT == "undo" && PH == "play" && NH > 0) { nb2 = (MODE == "ai" && TURN == PC && NH >= 2) ? 2 : 1; for (k = 1; k <= nb2; k++) pop() }
  else if (ACT == "undo" && PH == "score" && NH > 0) { pop(); PH = "play" }
  else if (ACT == "dead" && PH == "score" && a >= 0 && a < N * N && B[a] != ".") setdead(a, substr(DEAD, a + 1, 1) == "1" ? "0" : "1")
  else if (ACT == "finish" && PH == "score") { RES = score(); PH = "end" }
  else if (ACT == "resume" && PH == "score") { PH = "play"; PASS = 0 }
  else if (ACT == "resign" && PH == "play") { RES = ((MODE == "2p" ? TURN : PC) == "b" ? "Đen" : "Trắng") " xin thua"; gsub(/ /, "_", RES); PH = "end" }
  if (PH != "play") territory()
  if (PH == "score") RES = score()
  printf "N %d\nB %s\n", N, bstr() > SAVE
  st = NH > 400 ? NH - 399 : 1; for (i = st; i <= NH; i++) printf "H %s\n", H[i] > SAVE
  gsub(/ /, "_", RES)
  printf "TURN %s\nCB %d\nCW %d\nKO %d\nPASS %d\nLAST %d\nMODE %s\nPC %s\nPH %s\nRES %s\nDEAD %s\n", TURN, CB, CW, KO, PASS, LAST, MODE, PC, PH, RES, DEAD > SAVE
  close(SAVE)
  for (i = 0; i < N * N; i++) { nv = visual(i); if (ACT == "full" || nv != OLD[i]) print "G " i " " nv }
  print "TOP " TURN " " CB " " CW " " PH " " PASS " " MODE " " PC " " N " " RES
  if (PH == "play" && MODE == "ai" && TURN != PC && ACT != "undo") print "AI"
  if (MSG != "") print "MSG " MSG
}
