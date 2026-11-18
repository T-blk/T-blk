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
function attacked(m, by,   d, t, p, k, n_, k_, q_, r_, b_) {   # ô m có bị bên "by" tấn công không (không gọi hàm con: nhanh trên awk của Kindle)
  if (by == "w") { if (b[m + 9] == "P" || b[m + 11] == "P") return 1; n_ = "N"; k_ = "K"; q_ = "Q"; r_ = "R"; b_ = "B" }
  else { if (b[m - 9] == "p" || b[m - 11] == "p") return 1; n_ = "n"; k_ = "k"; q_ = "q"; r_ = "r"; b_ = "b" }
  for (k = 1; k <= 8; k++) { if (b[m + ND[k]] == n_) return 1; if (b[m + KD[k]] == k_) return 1 }
  for (k = 1; k <= 4; k++) { d = KD[k]; t = m + d; while (b[t] == ".") t += d; p = b[t]; if (p == q_ || p == r_) return 1 }
  for (k = 5; k <= 8; k++) { d = KD[k]; t = m + d; while (b[t] == ".") t += d; p = b[t]; if (p == q_ || p == b_) return 1 }
  return 0
}
function incheck(s) { return (s == "w") ? attacked(KW, "b") : attacked(KB, "w") }
function addm(ply, f, t, pr) { n = ++MN[ply]; MF[ply, n] = f; MT[ply, n] = t; MP[ply, n] = pr }
function gen(ply, s, co,   m, p, P, d, t, k, q, dir, st, pr, i, n) {   # nước giả hợp lệ; co=1: chỉ nước ăn quân/phong cấp (cho nút lá)
  n = 0
  for (i = 0; i < 64; i++) { m = SQM[i]; p = b[m]; if (p == "." || SD[p] != s) continue
    P = UPC[p]
    if (P == "P") {
      if (s == "w") { dir = -10; st = 8; pr = 2 } else { dir = 10; st = 3; pr = 9 }
      t = m + dir
      if (b[t] == ".") {
        if (int(t / 10) == pr) { MN[ply] = n; addm(ply, m, t, "Q"); addm(ply, m, t, "N"); addm(ply, m, t, "R"); addm(ply, m, t, "B"); n = MN[ply] }
        else if (!co) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = ""
          if (int(m / 10) == st && b[t + dir] == ".") { n++; MF[ply, n] = m; MT[ply, n] = t + dir; MP[ply, n] = "" } } }
      for (k = -1; k <= 1; k += 2) { t = m + dir + k; q = b[t]
        if (q != "." && q != "x" && SD[q] != s) {
          if (int(t / 10) == pr) { MN[ply] = n; addm(ply, m, t, "Q"); addm(ply, m, t, "N"); addm(ply, m, t, "R"); addm(ply, m, t, "B"); n = MN[ply] }
          else { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" } }
        else if (t == EP) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" } }
    } else if (P == "N") {
      for (k = 1; k <= 8; k++) { t = m + ND[k]; q = b[t]; if (q == "x") continue; if (q == "." ? !co : SD[q] != s) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" } }
    } else if (P == "K") {
      for (k = 1; k <= 8; k++) { t = m + KD[k]; q = b[t]; if (q == "x") continue; if (q == "." ? !co : SD[q] != s) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" } }
      if (co) continue
      if (s == "w" && m == 95) {
        if (CWK && b[96] == "." && b[97] == "." && b[98] == "R" && !attacked(95, "b") && !attacked(96, "b") && !attacked(97, "b")) { n++; MF[ply, n] = 95; MT[ply, n] = 97; MP[ply, n] = "" }
        if (CWQ && b[94] == "." && b[93] == "." && b[92] == "." && b[91] == "R" && !attacked(95, "b") && !attacked(94, "b") && !attacked(93, "b")) { n++; MF[ply, n] = 95; MT[ply, n] = 93; MP[ply, n] = "" } }
      if (s == "b" && m == 25) {
        if (CBK && b[26] == "." && b[27] == "." && b[28] == "r" && !attacked(25, "w") && !attacked(26, "w") && !attacked(27, "w")) { n++; MF[ply, n] = 25; MT[ply, n] = 27; MP[ply, n] = "" }
        if (CBQ && b[24] == "." && b[23] == "." && b[22] == "." && b[21] == "r" && !attacked(25, "w") && !attacked(24, "w") && !attacked(23, "w")) { n++; MF[ply, n] = 25; MT[ply, n] = 23; MP[ply, n] = "" } }
    } else {
      for (k = (P == "B" ? 5 : 1); k <= (P == "R" ? 4 : 8); k++) { d = KD[k]; t = m + d
        while (1) { q = b[t]
          if (q == ".") { if (!co) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" }; t += d; continue }
          if (q != "x" && SD[q] != s) { n++; MF[ply, n] = m; MT[ply, n] = t; MP[ply, n] = "" }
          break } }
    }
  }
  MN[ply] = n
}
function make(ply, f, t, pr,   p, c) {   # đi quân, lưu đủ để hoàn lại; SC = điểm thế cờ được cập nhật dần (khỏi tính lại cả bàn)
  p = b[f]; c = b[t]
  U_P[ply] = p; U_C[ply] = c; U_EP[ply] = EP; U_1[ply] = CWK; U_2[ply] = CWQ; U_3[ply] = CBK; U_4[ply] = CBQ
  U_KW[ply] = KW; U_KB[ply] = KB; U_HM[ply] = HM; U_X[ply] = 0; U_SC[ply] = SC
  SC -= EVM[p, f]; if (c != ".") SC -= EVM[c, t]
  b[t] = p; b[f] = "."
  if (p == "P") {
    if (t == EP) { U_X[ply] = t + 10; b[t + 10] = "."; SC -= EVM["p", t + 10] }
    if (pr != "") b[t] = pr
    EP = (f - t == 20) ? f - 10 : -1; HM = 0
  } else if (p == "p") {
    if (t == EP) { U_X[ply] = t - 10; b[t - 10] = "."; SC -= EVM["P", t - 10] }
    if (pr != "") b[t] = tolower(pr)
    EP = (t - f == 20) ? f + 10 : -1; HM = 0
  } else {
    EP = -1; HM = (c != ".") ? 0 : HM + 1
    if (p == "K") { KW = t; CWK = 0; CWQ = 0
      if (f == 95 && t == 97) { b[96] = "R"; b[98] = "."; SC += EVM["R", 96] - EVM["R", 98] }
      else if (f == 95 && t == 93) { b[94] = "R"; b[91] = "."; SC += EVM["R", 94] - EVM["R", 91] } }
    else if (p == "k") { KB = t; CBK = 0; CBQ = 0
      if (f == 25 && t == 27) { b[26] = "r"; b[28] = "."; SC += EVM["r", 26] - EVM["r", 28] }
      else if (f == 25 && t == 23) { b[24] = "r"; b[21] = "."; SC += EVM["r", 24] - EVM["r", 21] } }
  }
  SC += EVM[b[t], t]
  if (f == 98 || t == 98) CWK = 0; if (f == 91 || t == 91) CWQ = 0; if (f == 28 || t == 28) CBK = 0; if (f == 21 || t == 21) CBQ = 0
}
function unmake(ply, f, t,   p) {
  p = U_P[ply]; b[f] = p; b[t] = U_C[ply]
  if (U_X[ply]) b[U_X[ply]] = (p == "P") ? "p" : "P"
  if (p == "K") { if (f == 95 && t == 97) { b[98] = "R"; b[96] = "." } else if (f == 95 && t == 93) { b[91] = "R"; b[94] = "." } }
  else if (p == "k") { if (f == 25 && t == 27) { b[28] = "r"; b[26] = "." } else if (f == 25 && t == 23) { b[21] = "r"; b[24] = "." } }
  EP = U_EP[ply]; CWK = U_1[ply]; CWQ = U_2[ply]; CBK = U_3[ply]; CBQ = U_4[ply]
  KW = U_KW[ply]; KB = U_KB[ply]; HM = U_HM[ply]; SC = U_SC[ply]
}
function legal(ply, s,   k, n2, f, t, pr, ok) {   # lọc nước hợp lệ vào LF/LT/LP[ply]
  gen(ply, s, 0); n2 = 0
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
function evalfull(   i, m, p, v) { v = 0; for (i = 0; i < 64; i++) { m = SQM[i]; p = b[m]; if (p != ".") v += EVM[p, m] }; return v }
function initeval(   i, m, p, np, ph) {   # chọn bảng điểm vua theo giai đoạn ván (một lần ở gốc), tính điểm ban đầu
  np = 0; for (i = 0; i < 64; i++) { p = b[SQM[i]]; if (p != "." && p != "P" && p != "p" && p != "K" && p != "k") np++ }
  ph = (np > 10) ? "mid" : "end"
  for (i = 0; i < 64; i++) { m = SQM[i]; EVM["K", m] = EV["K", ph, i]; EVM["k", m] = -EV["k", ph, i] }
  SC = evalfull()
}
function evalpos() { return SC }   # điểm theo bên trắng
function order(ply, n,   k, j, sc, t1, t2, t3, ts, c) {   # ăn quân giá trị cao trước
  for (k = 1; k <= n; k++) { c = b[LT[ply, k]]; sc[k] = (c != ".") ? VALP[c] * 10 - VALP[b[LF[ply, k]]] : ((LF[ply, k] == KLF[ply] && LT[ply, k] == KLT[ply]) ? 50 : 0); if (LP[ply, k] == "Q") sc[k] += 8000 }   # nước "sát thủ" (vừa gây cắt tỉa ở độ sâu này) xét sớm
  for (k = 2; k <= n; k++) { if (sc[k] <= sc[k - 1]) continue; j = k
    while (j > 1 && sc[j] > sc[j - 1]) { ts = sc[j]; sc[j] = sc[j - 1]; sc[j - 1] = ts
      t1 = LF[ply, j]; LF[ply, j] = LF[ply, j - 1]; LF[ply, j - 1] = t1
      t2 = LT[ply, j]; LT[ply, j] = LT[ply, j - 1]; LT[ply, j - 1] = t2
      t3 = LP[ply, j]; LP[ply, j] = LP[ply, j - 1]; LP[ply, j - 1] = t3; j-- } }
}
function now(   t) { "date +%s" | getline t; close("date +%s"); return t + 0 }
function chktime() { NCHK = NODES + 250; if (NODES > BUDGET || now() >= TEND) ABORT = 1 }   # hết giờ nghĩ -> dừng, dùng nước tốt nhất đã có
# Chỉ cần thử "vua có bị chiếu sau nước này không" khi: đang bị chiếu, đi vua, bắt tốt qua đường, hoặc quân đi
# nằm thẳng hàng/chéo với vua (có thể đang bị ghim). Các nước khác chắc chắn hợp lệ -> khỏi kiểm tra (nhanh hơn nhiều).
function qs(s, alpha, beta, ply, qd,   sp, n, k, sc, f, t, pr, o, ic, nl, known, full, kq, d, need) {   # ở lá: chỉ xét ăn quân (đang bị chiếu thì xét mọi nước để thấy chiếu hết)
  if (++NODES >= NCHK) chktime()
  known = (qd > 0 || ply < 6); ic = known ? incheck(s) : 0; full = (SAFE || ic || !known)
  if (!ic) { sp = (s == "b") ? -SC : SC
    if (sp >= beta) return sp; if (sp > alpha) alpha = sp
    if (qd <= 0) return alpha }
  o = (s == "w") ? "b" : "w"; kq = (s == "w") ? KW : KB
  gen(ply, s, !ic); n = MN[ply]
  for (k = 1; k <= n; k++) { LF[ply, k] = MF[ply, k]; LT[ply, k] = MT[ply, k]; LP[ply, k] = MP[ply, k] }
  order(ply, n); nl = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]
    if (pr != "" && pr != "Q") continue
    if (!ic && pr == "" && sp + VALP[b[t]] + 150 < alpha) continue      # ăn quân này cũng không đủ gỡ -> bỏ qua (delta pruning)
    need = (full || f == kq || t == EP)
    if (!need) { d = f - kq; if (d < 0) d = -d; need = (d % 10 == 0 || d % 11 == 0 || d % 9 == 0 || int(f / 10) == int(kq / 10)) }
    make(ply, f, t, pr); if (need && incheck(s)) { unmake(ply, f, t); continue }
    nl++; sc = -qs(o, -beta, -alpha, ply + 1, (qd > 0 ? qd - 1 : 0)); unmake(ply, f, t)
    if (sc >= beta) return sc; if (sc > alpha) alpha = sc }
  if (ic && nl == 0) return -100000 + ply
  if (ic && alpha == -9999999) return (s == "b") ? -SC : SC
  return alpha
}
function search(s, depth, alpha, beta, ply,   n, k, sc, f, t, pr, o, best, nl, ic, kq, d, need) {
  if (++NODES >= NCHK) chktime()
  if (depth <= 0 || ABORT) return (LV >= 2) ? qs(s, alpha, beta, ply, LV == 3 ? 3 : 1) : ((s == "w") ? SC : -SC)
  o = (s == "w") ? "b" : "w"; kq = (s == "w") ? KW : KB; ic = attacked(kq, o)
  gen(ply, s, 0); n = MN[ply]
  for (k = 1; k <= n; k++) { LF[ply, k] = MF[ply, k]; LT[ply, k] = MT[ply, k]; LP[ply, k] = MP[ply, k] }
  order(ply, n); best = -999999; nl = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]
    if (pr != "" && pr != "Q" && pr != "N") continue
    need = (SAFE || ic || f == kq || t == EP)
    if (!need) { d = f - kq; if (d < 0) d = -d; need = (d % 10 == 0 || d % 11 == 0 || d % 9 == 0 || int(f / 10) == int(kq / 10)) }
    make(ply, f, t, pr); if (need && incheck(s)) { unmake(ply, f, t); continue }
    nl++; sc = -search(o, depth - 1, -beta, -alpha, ply + 1); unmake(ply, f, t)
    if (sc > best) best = sc; if (sc > alpha) alpha = sc
    if (alpha >= beta) { if (b[t] == ".") { KLF[ply] = f; KLT[ply] = t }; break } }
  if (nl == 0) return ic ? -100000 + ply : 0
  return best
}
function think(s, depth, noise, tlim,   n, k, sc, f, t, pr, o, bs, alpha, d, rf, rt, rp, rs, j, done, nf, nt, np_) {   # -> BF BT BP
  n = legal(0, s); if (n == 0) return 0
  initeval()
  order(0, n); o = (s == "w") ? "b" : "w"
  for (k = 1; k <= n; k++) { rf[k] = LF[0, k]; rt[k] = LT[0, k]; rp[k] = LP[0, k] }
  BF = rf[1]; BT = rt[1]; BP = rp[1]; ABORT = 0; NODES = 0; NCHK = 250; TEND = now() + tlim; DEPTH_DONE = 0
  delete HK; for (k = 1; k <= NH; k++) HK[hkey(H[k])] = 1      # các thế cờ đã xuất hiện trong ván (để tránh đi lặp khi đang hơn)
  for (d = 1; d <= depth; d++) {                 # đào sâu dần; hết giờ thì dùng kết quả tốt nhất đã có
    bs = -9999999; alpha = -9999999; done = 0
    for (k = 1; k <= n; k++) { f = rf[k]; t = rt[k]; pr = rp[k]
      if (pr != "" && pr != "Q") { rs[k] = -9999999; continue }
      # cửa sổ alpha-beta ở gốc (mức có "nhiễu" thì nới thêm đúng bằng độ nhiễu để các nước sát nhau vẫn có điểm thật)
      make(0, f, t, pr); sc = -search(o, d - 1, -9999999, -(alpha - noise), 1)
      if (sc > 0 && ((boardstr() o CWK CWQ CBK CBQ EP) in HK)) sc = int(sc / 8)   # nước này quay về thế cũ -> coi như gần hoà
      unmake(0, f, t)
      if (ABORT && d > 1) break
      if (sc > alpha) alpha = sc
      if (noise) sc += int(rand() * noise)
      rs[k] = sc; done++
      if (sc > bs) { bs = sc; nf = f; nt = t; np_ = pr } }
    # độ sâu này xong, hoặc bị dừng giữa chừng nhưng đã xét xong nước tốt nhất lần trước (nước đầu) -> kết quả vẫn dùng được
    if (done > 0 && (!ABORT || d == 1 || done >= 1)) { BF = nf; BT = nt; BP = np_ }
    if (ABORT) break
    DEPTH_DONE = d
    for (k = 2; k <= n; k++) { j = k                 # nước tốt lên đầu cho lần sau (cắt tỉa nhiều hơn)
      while (j > 1 && rs[j] > rs[j - 1]) { sc = rs[j]; rs[j] = rs[j - 1]; rs[j - 1] = sc; sc = rf[j]; rf[j] = rf[j - 1]; rf[j - 1] = sc
        sc = rt[j]; rt[j] = rt[j - 1]; rt[j - 1] = sc; sc = rp[j]; rp[j] = rp[j - 1]; rp[j - 1] = sc; j-- } }
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
  split("P N B R Q K", PP, " ")
  for (k = 1; k <= 6; k++) { u = PP[k]; l = tolower(u); SD[u] = "w"; SD[l] = "b"; UPC[u] = u; UPC[l] = u; VALP[u] = VAL[u]; VALP[l] = VAL[u] }
  SD["."] = ""; SD["x"] = ""; VALP["."] = 0; SC = 0
  for (i = 0; i < 64; i++) { m = SQM[i]; for (k = 1; k <= 5; k++) { u = PP[k]; EVM[u, m] = EV[u, i]; EVM[tolower(u), m] = EV[tolower(u), i] }; EVM["K", m] = 0; EVM["k", m] = 0 }
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
  if (ACT == "perft") { if (FEN != "") setstate(FEN); initeval(); print perft(ARG + 0, TURN, 0); if (CHKEV) print "sai_điểm " BADEV + 0; exit }
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
    BUDGET = 400000                                   # chặn trên phòng xa; giới hạn chính là thời gian (giây)
    tl = (TLIM != "") ? TLIM + 0 : ((LV == 1) ? 2 : (LV == 2 ? 5 : 10)); if (DMAX != "") d = DMAX + 0   # TLIM/DMAX: chỉ dùng khi thử
    if (think(TURN, d, nz, tl)) domove(BF, BT, BP)
  }
  else if (ACT == "hint" && ST == "play" && myturn) {
    LVs = LV; LV = 2; BUDGET = 400000; if (think(TURN, 2, 0, 4)) { SEL = m2s(BF); HINTT = m2s(BT) }; LV = LVs
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
  if (ACT == "ai") print "NODES " NODES " sâu " DEPTH_DONE
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
  if (CHKEV && SC != evalfull()) BADEV++          # thử: điểm cập nhật dần phải bằng điểm tính lại cả bàn
  if (d == 0) return 1
  n = legal(ply, s); if (d == 1 && !CHKEV) return n
  o = (s == "w") ? "b" : "w"; c = 0
  for (k = 1; k <= n; k++) { f = LF[ply, k]; t = LT[ply, k]; pr = LP[ply, k]; make(ply, f, t, pr); c += perft(d - 1, o, ply + 1); unmake(ply, f, t) }
  return c
}
