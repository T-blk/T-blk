# Cờ vua: luật đầy đủ (nhập thành, bắt tốt qua đường, phong cấp, chiếu, chiếu hết, hết nước,
# hoà 50 nước / lặp 3 lần / không đủ quân) + máy chơi (alpha-beta, 3 mức).
# Biến vào: ACT (full tap ai undo flip hint new none), ARG (ô 0..63, a8=0 ... h1=63), SAVE,
#           NMODE NLV NPC (khi new: ai|2p, 1..3, w|b)
# In ra:  Q ô quân nền chọn đích nướccuối chiếu gợiý  (mỗi ô thay đổi)
#         TOP lượt trạngthái chiếu chếđộ mức màungười bịăn_trắng bịăn_đen lật
#         AI (đến lượt máy, gọi lại ACT=ai) · END kết_quả
function m2s(m) { return int(m / 10 - 2) * 8 + (m % 10 - 1) }
function s2m(s) { return 21 + int(s / 8) * 10 + s % 8 }
function iswhite(p) { return p != "." && p != "x" && index("PNBRQK", p) > 0 }
function isblack(p) { return p != "." && p != "x" && index("pnbrqk", p) > 0 }
function side(p) { return iswhite(p) ? "w" : (isblack(p) ? "b" : "") }
function up(p) { return toupper(p) }
function attacked(m, by,   d, i, t, p, k) {   # ô m có bị bên "by" tấn công không
  if (by == "w") { if (b[m + 9] == "P" || b[m + 11] == "P") return 1 }
  else { if (b[m - 9] == "p" || b[m - 11] == "p") return 1 }
  for (k = 1; k <= 8; k++) { p = b[m + ND[k]]; if (p != "." && p != "x" && up(p) == "N" && side(p) == by) return 1
    p = b[m + KD[k]]; if (p != "." && p != "x" && up(p) == "K" && side(p) == by) return 1 }
  for (k = 1; k <= 8; k++) { d = KD[k]; t = m + d
    while (b[t] == ".") t += d
    p = b[t]; if (p == "x" || p == "." || side(p) != by) continue
    p = up(p); if (p == "Q") return 1
    if (k <= 4 && p == "R") return 1
    if (k > 4 && p == "B") return 1 }
  return 0
}
function incheck(s) { return attacked(s == "w" ? KW : KB, s == "w" ? "b" : "w") }
function addm(ply, f, t, pr) { n = ++MN[ply]; MF[ply, n] = f; MT[ply, n] = t; MP[ply, n] = pr }
function gen(ply, s,   m, p, P, d, t, k, q, dir, st, pr, i) {   # nước giả hợp lệ
  MN[ply] = 0
  for (i = 0; i < 64; i++) { m = s2m(i); p = b[m]; if (p == "." || side(p) != s) continue
    P = up(p)
    if (P == "P") {
      dir = (s == "w") ? -10 : 10; st = (s == "w") ? 8 : 3; pr = (s == "w") ? 2 : 9
      t = m + dir
      if (b[t] == ".") { if (int(t / 10) == pr) { addm(ply, m, t, "Q"); addm(ply, m, t, "N"); addm(ply, m, t, "R"); addm(ply, m, t, "B") } else addm(ply, m, t, "")
        if (int(m / 10) == st && b[t + dir] == ".") addm(ply, m, t + dir, "") }
      for (k = -1; k <= 1; k += 2) { t = m + dir + k; q = b[t]
        if (q != "." && q != "x" && side(q) != s) { if (int(t / 10) == pr) { addm(ply, m, t, "Q"); addm(ply, m, t, "N"); addm(ply, m, t, "R"); addm(ply, m, t, "B") } else addm(ply, m, t, "") }
        else if (t == EP) addm(ply, m, t, "") }
    } else if (P == "N" || P == "K") {
      for (k = 1; k <= 8; k++) { t = m + (P == "N" ? ND[k] : KD[k]); q = b[t]; if (q == "x") continue; if (q == "." || side(q) != s) addm(ply, m, t, "") }
      if (P == "K") {
        if (s == "w" && m == 95) {
          if (CWK && b[96] == "." && b[97] == "." && b[98] == "R" && !attacked(95, "b") && !attacked(96, "b") && !attacked(97, "b")) addm(ply, 95, 97, "")
          if (CWQ && b[94] == "." && b[93] == "." && b[92] == "." && b[91] == "R" && !attacked(95, "b") && !attacked(94, "b") && !attacked(93, "b")) addm(ply, 95, 93, "") }
        if (s == "b" && m == 25) {
          if (CBK && b[26] == "." && b[27] == "." && b[28] == "r" && !attacked(25, "w") && !attacked(26, "w") && !attacked(27, "w")) addm(ply, 25, 27, "")
          if (CBQ && b[24] == "." && b[23] == "." && b[22] == "." && b[21] == "r" && !attacked(25, "w") && !attacked(24, "w") && !attacked(23, "w")) addm(ply, 25, 23, "") }
      }
    } else {
      for (k = (P == "B" ? 5 : 1); k <= (P == "R" ? 4 : 8); k++) { d = KD[k]; t = m + d
        while (1) { q = b[t]; if (q == "x") break
          if (q == ".") { addm(ply, m, t, ""); t += d; continue }
          if (side(q) != s) addm(ply, m, t, ""); break } }
    }
  }
}
function make(ply, f, t, pr,   p, c) {   # đi quân, lưu đủ để hoàn lại
  p = b[f]; c = b[t]
  U_P[ply] = p; U_C[ply] = c; U_EP[ply] = EP; U_CA[ply] = CWK CWQ CBK CBQ; U_KW[ply] = KW; U_KB[ply] = KB; U_HM[ply] = HM; U_X[ply] = 0
  b[t] = p; b[f] = "."
  if (up(p) == "P" && t == EP) { if (p == "P") { U_X[ply] = t + 10; b[t + 10] = "." } else { U_X[ply] = t - 10; b[t - 10] = "." } }
  if (pr != "") b[t] = (p == "P") ? pr : tolower(pr)
  EP = -1; if (up(p) == "P" && (t - f == 20 || f - t == 20)) EP = (f + t) / 2
  if (p == "K") { KW = t; CWK = 0; CWQ = 0; if (f == 95 && t == 97) { b[96] = "R"; b[98] = "." } if (f == 95 && t == 93) { b[94] = "R"; b[91] = "." } }
  if (p == "k") { KB = t; CBK = 0; CBQ = 0; if (f == 25 && t == 27) { b[26] = "r"; b[28] = "." } if (f == 25 && t == 23) { b[24] = "r"; b[21] = "." } }
  if (f == 98 || t == 98) CWK = 0; if (f == 91 || t == 91) CWQ = 0; if (f == 28 || t == 28) CBK = 0; if (f == 21 || t == 21) CBQ = 0
  HM = (up(p) == "P" || c != ".") ? 0 : HM + 1
}
function unmake(ply, f, t,   p) {
  p = U_P[ply]; b[f] = p; b[t] = U_C[ply]
  if (U_X[ply]) b[U_X[ply]] = (p == "P") ? "p" : "P"
  if (p == "K" && f == 95 && t == 97) { b[98] = "R"; b[96] = "." } if (p == "K" && f == 95 && t == 93) { b[91] = "R"; b[94] = "." }
  if (p == "k" && f == 25 && t == 27) { b[28] = "r"; b[26] = "." } if (p == "k" && f == 25 && t == 23) { b[21] = "r"; b[24] = "." }
  EP = U_EP[ply]; CWK = substr(U_CA[ply], 1, 1) + 0; CWQ = substr(U_CA[ply], 2, 1) + 0; CBK = substr(U_CA[ply], 3, 1) + 0; CBQ = substr(U_CA[ply], 4, 1) + 0
  KW = U_KW[ply]; KB = U_KB[ply]; HM = U_HM[ply]
}
function legal(ply, s,   k, n2, f, t, pr, ok) {   # lọc nước hợp lệ vào LF/LT/LP[ply]
  gen(ply, s); n2 = 0
  for (k = 1; k <= MN[ply]; k++) { f = MF[ply, k]; t = MT[ply, k]; pr = MP[ply, k]
    make(ply, f, t, pr); ok = !incheck(s); unmake(ply, f, t)
    if (ok) { n2++; LF[ply, n2] = f; LT[ply, n2] = t; LP[ply, n2] = pr } }
  LN[ply] = n2; return n2
}
function pst(P, i, white,   r, c, cd) {   # điểm vị trí đơn giản
  r = int(i / 8); c = i % 8; if (!white) r = 7 - r
  cd = (c < 4 ? 3 - c : c - 4) + (r < 4 ? 3 - r : r - 4)
  if (P == "P") return (6 - r) * 8 + (c >= 2 && c <= 5 ? 6 : 0) * (r <= 4)
  if (P == "N") return 20 - cd * 7
  if (P == "B") return 12 - cd * 4
  if (P == "Q") return 4 - cd * 2
  if (P == "R") return (r == 1 ? 12 : 0)
  if (P == "K") return (NPIECE > 10) ? ((r == 7 && (c <= 2 || c >= 6)) ? 18 : -cd * 2 - (7 - r) * 6) : 10 - cd * 6
  return 0
}
function evalpos(   i, m, p, v, np) {   # điểm theo bên trắng (bảng PST tính sẵn trong BEGIN)
  v = 0; np = 0
  for (i = 0; i < 64; i++) { p = b[SQM[i]]; if (p == ".") continue
    v += EV[p, i]; if (p != "P" && p != "p" && p != "K" && p != "k") np++ }
  if (np > 10) v += EV["K", "mid", m2s(KW)] - EV["k", "mid", m2s(KB)]
  else v += EV["K", "end", m2s(KW)] - EV["k", "end", m2s(KB)]
  return v
}
function order(ply, n,   k, j, sc, t1, t2, t3, ts) {   # ăn quân giá trị cao trước
  for (k = 1; k <= n; k++) { sc[k] = (b[LT[ply, k]] != ".") ? VAL[up(b[LT[ply, k]])] * 10 - VAL[up(b[LF[ply, k]])] : 0; if (LP[ply, k] == "Q") sc[k] += 8000 }
  for (k = 2; k <= n; k++) { j = k
    while (j > 1 && sc[j] > sc[j - 1]) { ts = sc[j]; sc[j] = sc[j - 1]; sc[j - 1] = ts
      t1 = LF[ply, j]; LF[ply, j] = LF[ply, j - 1]; LF[ply, j - 1] = t1
      t2 = LT[ply, j]; LT[ply, j] = LT[ply, j - 1]; LT[ply, j - 1] = t2
      t3 = LP[ply, j]; LP[ply, j] = LP[ply, j - 1]; LP[ply, j - 1] = t3; j-- } }
}
function qs(s, alpha, beta, ply, qd,   sp, n, k, sc, f, t, pr, o, ic, nl) {   # ở lá: chỉ xét ăn quân (đang bị chiếu thì xét mọi nước để thấy chiếu hết)
  NODES++
  ic = (qd > 0 || ply < 6) ? incheck(s) : 0
  if (!ic) { sp = evalpos(); if (s == "b") sp = -sp
    if (sp >= beta) return sp; if (sp > alpha) alpha = sp
    if (qd <= 0) return alpha }
  o = (s == "w") ? "b" : "w"
  gen(ply, s); n = 0
  for (k = 1; k <= MN[ply]; k++) { t = MT[ply, k]; if (ic || b[t] != "." || MP[ply, k] == "Q") { n++; LF[ply, n] = MF[ply, k]; LT[ply, n] = t; LP[ply, n] = MP[ply, k] } }
  order(ply, n); nl = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]
    if (pr != "" && pr != "Q") continue
    make(ply, f, t, pr); if (incheck(s)) { unmake(ply, f, t); continue }
    nl++; sc = -qs(o, -beta, -alpha, ply + 1, (qd > 0 ? qd - 1 : 0)); unmake(ply, f, t)
    if (sc >= beta) return sc; if (sc > alpha) alpha = sc }
  if (ic && nl == 0) return -100000 + ply
  if (ic && alpha == -9999999) { sp = evalpos(); return (s == "b") ? -sp : sp }
  return alpha
}
function search(s, depth, alpha, beta, ply,   n, k, sc, f, t, pr, o, best, nl) {
  NODES++
  if (NODES > BUDGET) ABORT = 1
  if (depth <= 0 || ABORT) return (LV >= 2) ? qs(s, alpha, beta, ply, LV == 3 ? 3 : 1) : ((s == "w") ? evalpos() : -evalpos())
  gen(ply, s); n = MN[ply]
  for (k = 1; k <= n; k++) { LF[ply, k] = MF[ply, k]; LT[ply, k] = MT[ply, k]; LP[ply, k] = MP[ply, k] }
  order(ply, n); o = (s == "w") ? "b" : "w"; best = -999999; nl = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]
    if (pr != "" && pr != "Q" && pr != "N") continue
    make(ply, f, t, pr); if (incheck(s)) { unmake(ply, f, t); continue }
    nl++; sc = -search(o, depth - 1, -beta, -alpha, ply + 1); unmake(ply, f, t)
    if (sc > best) best = sc; if (sc > alpha) alpha = sc; if (alpha >= beta) break }
  if (nl == 0) return incheck(s) ? -100000 + ply : 0
  return best
}
function think(s, depth, noise,   n, k, sc, f, t, pr, o, bs, alpha, d, rf, rt, rp, rs, j) {   # -> BF BT BP
  n = legal(0, s); if (n == 0) return 0
  order(0, n); o = (s == "w") ? "b" : "w"
  for (k = 1; k <= n; k++) { rf[k] = LF[0, k]; rt[k] = LT[0, k]; rp[k] = LP[0, k] }
  BF = rf[1]; BT = rt[1]; BP = rp[1]; ABORT = 0
  for (d = 1; d <= depth; d++) {                 # đào sâu dần; hết "ngân sách" thì giữ kết quả độ sâu trước
    bs = -9999999; alpha = -9999999
    for (k = 1; k <= n; k++) { f = rf[k]; t = rt[k]; pr = rp[k]
      if (pr != "" && pr != "Q") continue
      make(0, f, t, pr); sc = -search(o, d - 1, -9999999, -alpha + noise, 1); unmake(0, f, t)
      if (ABORT) break
      if (noise) sc += int(rand() * noise)
      rs[k] = sc
      if (sc > bs) { bs = sc; nf = f; nt = t; np_ = pr }
      if (!noise && sc > alpha) alpha = sc }
    if (ABORT && d > 1) break
    BF = nf; BT = nt; BP = np_
    for (k = 2; k <= n; k++) { j = k                 # nước tốt lên đầu cho lần sau (cắt tỉa nhiều hơn)
      while (j > 1 && rs[j] > rs[j - 1]) { sc = rs[j]; rs[j] = rs[j - 1]; rs[j - 1] = sc; sc = rf[j]; rf[j] = rf[j - 1]; rf[j - 1] = sc
        sc = rt[j]; rt[j] = rt[j - 1]; rt[j - 1] = sc; sc = rp[j]; rp[j] = rp[j - 1]; rp[j - 1] = sc; j-- } }
    if (ABORT) break
  }
  return 1
}
function poskey(   i, s) { s = ""; for (i = 0; i < 64; i++) s = s b[s2m(i)]; return s TURN CWK CWQ CBK CBQ EP }
function boardstr(   i, s) { s = ""; for (i = 0; i < 64; i++) s = s b[s2m(i)]; return s }
function setstate(line,   a, i) {
  split(line, a, " ")
  for (i = 0; i < 64; i++) b[s2m(i)] = substr(a[1], i + 1, 1)
  TURN = a[2]; CWK = substr(a[3], 1, 1) + 0; CWQ = substr(a[3], 2, 1) + 0; CBK = substr(a[3], 3, 1) + 0; CBQ = substr(a[3], 4, 1) + 0
  EP = a[4] + 0; HM = a[5] + 0; FM = a[6] + 0; LASTF = a[7] + 0; LASTT = a[8] + 0
  for (i = 0; i < 120; i++) if (b[i] == "K") KW = i; else if (b[i] == "k") KB = i
}
function statestr() { return boardstr() " " TURN " " CWK CWQ CBK CBQ " " EP " " HM " " FM " " LASTF " " LASTT }
function domove(f, t, pr,   cap) {   # nước thật trên bàn
  H[++NH] = statestr()
  make(0, f, t, pr); LASTF = f; LASTT = t; CAPW = ""; CAPB = ""; recount()
  if (TURN == "b") FM++
  TURN = (TURN == "w") ? "b" : "w"; SEL = -1; HINTT = -1
  status()
}
function status(   n, k, cnt, i, p, minor, other) {
  n = legal(0, TURN)
  if (n == 0) { ST = incheck(TURN) ? "mate" : "stale"; return }
  if (HM >= 100) { ST = "draw50"; return }
  k = poskey(); cnt = 1; for (i = 1; i <= NH; i++) if (substr(H[i], 1, 64) == substr(k, 1, 64) && hkey(H[i]) == k) cnt++
  if (cnt >= 3) { ST = "draw3"; return }
  minor = 0; other = 0
  for (i = 0; i < 64; i++) { p = up(b[s2m(i)]); if (p == "N" || p == "B") minor++; else if (p != "." && p != "K") other++ }
  if (other == 0 && minor <= 1) { ST = "drawmat"; return }
  ST = "play"
}
function hkey(line,   a) { split(line, a, " "); return a[1] a[2] a[3] a[4] }
function targets(sel,   n, k) { delete TG; if (sel < 0) return; n = legal(0, TURN); for (k = 1; k <= n; k++) if (m2s(LF[0, k]) == sel) TG[m2s(LT[0, k])] = 1 }
function visual(i,   p, m, ck) {
  m = s2m(i); p = b[m]; ck = 0
  if (ST != "draw50" && ((p == "K" && TURN == "w") || (p == "k" && TURN == "b")) && incheck(TURN)) ck = 1
  return p " " ((int(i / 8) + i % 8) % 2) " " (i == SEL ? 1 : 0) " " ((i in TG) ? 1 : 0) " " ((i == m2s(LASTF) || i == m2s(LASTT)) && LASTF > 0 ? 1 : 0) " " ck " " (i == HINTT ? 1 : 0)
}
function capstr(s) { return s == "" ? "-" : s }
BEGIN {
  split("-10 10 1 -1 -9 -11 9 11", KD, " "); split("-21 -19 -12 -8 8 12 19 21", ND, " ")
  VAL["P"] = 100; VAL["N"] = 320; VAL["B"] = 330; VAL["R"] = 500; VAL["Q"] = 900; VAL["K"] = 0; VAL["."] = 0
  for (i = 0; i < 120; i++) b[i] = "x"
  for (i = 0; i < 64; i++) { SQM[i] = s2m(i)
    split("P N B R Q", PP, " ")
    for (k = 1; k <= 5; k++) { EV[PP[k], i] = VAL[PP[k]] + pst(PP[k], i, 1); EV[tolower(PP[k]), i] = -(VAL[PP[k]] + pst(PP[k], i, 0)) }
    NPIECE = 20; EV["K", "mid", i] = pst("K", i, 1); EV["k", "mid", i] = pst("K", i, 0)
    NPIECE = 0; EV["K", "end", i] = pst("K", i, 1); EV["k", "end", i] = pst("K", i, 0) }
  EV["K", 0] = 0
  setstate("rnbqkbnrpppppppp................................PPPPPPPPRNBQKBNR w 1111 -1 0 1 0 0")
  SEL = -1; MODE = "ai"; LV = 2; PC = "w"; FLIP = 0; ST = "play"; CAPW = ""; CAPB = ""; NH = 0; HINTT = -1
  while ((getline line < SAVE) > 0) {
    k = substr(line, 1, index(line, " ") - 1); v = substr(line, index(line, " ") + 1)
    if (k == "S") setstate(v); else if (k == "H") H[++NH] = v
    else if (k == "SEL") SEL = v + 0; else if (k == "MODE") MODE = v; else if (k == "LV") LV = v + 0
    else if (k == "PC") PC = v; else if (k == "FLIP") FLIP = v + 0; else if (k == "ST") ST = v
    else if (k == "CAPW") CAPW = (v == "-") ? "" : v; else if (k == "CAPB") CAPB = (v == "-") ? "" : v
    else if (k == "HINT") HINTT = v + 0
  }
  close(SAVE)
  if (ACT == "new") {
    setstate("rnbqkbnrpppppppp................................PPPPPPPPRNBQKBNR w 1111 -1 0 1 0 0")
    SEL = -1; MODE = NMODE; LV = NLV + 0; PC = NPC; FLIP = (MODE == "ai" && PC == "b") ? 1 : 0; ST = "play"; CAPW = ""; CAPB = ""; NH = 0; HINTT = -1
    ACT = "full"
  }
  if (ACT == "perft") { if (FEN != "") setstate(FEN); print perft(ARG + 0, TURN, 0); exit }
  targets(SEL)
  for (i = 0; i < 64; i++) OLD[i] = visual(i)
  oflip = FLIP
  a = ARG + 0; srand()
  myturn = (MODE == "2p" || TURN == PC)
  if (ACT == "tap" && ST == "play" && myturn) {
    p = b[s2m(a)]
    if (SEL >= 0 && (a in TG)) {
      pr = ""; if (up(b[s2m(SEL)]) == "P" && (int(a / 8) == 0 || int(a / 8) == 7)) pr = "Q"
      domove(s2m(SEL), s2m(a), pr)
    } else if (p != "." && side(p) == TURN) { SEL = (SEL == a) ? -1 : a; HINTT = -1 }
    else SEL = -1
  }
  else if (ACT == "ai" && ST == "play" && MODE == "ai" && TURN != PC) {
    d = (LV == 1) ? 1 : (LV == 2 ? 2 : 4); nz = (LV == 1) ? 120 : (LV == 2 ? 12 : 0)
    BUDGET = (LV == 1) ? 200 : (LV == 2 ? 1800 : 6000)
    if (think(TURN, d, nz)) domove(BF, BT, BP)
  }
  else if (ACT == "hint" && ST == "play" && myturn) {
    LVs = LV; LV = 2; BUDGET = 2500; if (think(TURN, 2, 0)) { SEL = m2s(BF); HINTT = m2s(BT) }; LV = LVs
  }
  else if (ACT == "undo" && NH > 0) {
    nb = (MODE == "ai") ? ((TURN == PC) ? 2 : 1) : 1; if (nb > NH) nb = NH
    for (k = 1; k <= nb; k++) { setstate(H[NH]); NH-- }
    CAPW = ""; CAPB = ""; recount()
    SEL = -1; HINTT = -1; status()
  }
  else if (ACT == "flip") FLIP = 1 - FLIP
  else if (ACT == "resign" && ST == "play") ST = (MODE == "2p") ? ("resign" TURN) : "resign" PC
  targets(SEL)
  printf "S %s\n", statestr() > SAVE
  st = NH > 300 ? NH - 299 : 1; for (i = st; i <= NH; i++) printf "H %s\n", H[i] > SAVE
  printf "SEL %d\nMODE %s\nLV %d\nPC %s\nFLIP %d\nST %s\nCAPW %s\nCAPB %s\nHINT %d\n", SEL, MODE, LV, PC, FLIP, ST, capstr(CAPW), capstr(CAPB), HINTT > SAVE
  close(SAVE)
  for (i = 0; i < 64; i++) { nv = visual(i); if (ACT == "full" || FLIP != oflip || nv != OLD[i]) print "Q " i " " nv }
  print "TOP " TURN " " ST " " (incheck(TURN) ? 1 : 0) " " MODE " " LV " " PC " " capstr(CAPW) " " capstr(CAPB) " " FLIP
  if (ST == "play" && MODE == "ai" && TURN != PC && ACT != "undo") print "AI"
  if (ACT == "ai") print "NODES " NODES
}
function recount(   i, p, cnt, k, start, need) {   # quân bị ăn = bộ quân ban đầu trừ quân còn trên bàn
  split("P 8 N 2 B 2 R 2 Q 1", need, " ")
  for (k = 1; k <= 10; k += 2) {
    cw = 0; cb = 0
    for (i = 0; i < 64; i++) { p = b[s2m(i)]; if (p == need[k]) cw++; else if (p == tolower(need[k])) cb++ }
    for (i = cw; i < need[k + 1] + 0; i++) CAPW = CAPW need[k]
    for (i = cb; i < need[k + 1] + 0; i++) CAPB = CAPB need[k]
  }
}
function perft(d, s, ply,   n, k, f, t, pr, c, o) {   # kiểm tra bộ sinh nước (chỉ dùng khi thử)
  if (d == 0) return 1
  n = legal(ply, s); if (d == 1) return n
  o = (s == "w") ? "b" : "w"; c = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]; make(ply, f, t, pr); c += perft(d - 1, o, ply + 1); unmake(ply, f, t) }
  return c
}
