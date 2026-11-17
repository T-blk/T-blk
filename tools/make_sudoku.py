#!/usr/bin/env python3
"""Sinh kho đề Sudoku cho Kindle: kindle/dashboard/lib/sudoku.txt

Mỗi dòng: MỨC|ĐỀ(81 số, 0 = ô trống)|LỜI GIẢI(81 số)
  1 = Dễ (giải được chỉ bằng "ô đơn", nhiều gợi ý)   2 = Vừa (ô đơn + "chỗ duy nhất")
  3 = Khó (cần thử/suy luận sâu hơn)                 4 = Rất khó (ít gợi ý nhất)
Mọi đề đều có đúng MỘT lời giải. Trên Kindle, mỗi ván còn được xáo trộn ngẫu nhiên
(đổi số, xoay, đổi hàng/cột trong cùng khối) nên gần như không bao giờ lặp lại.
    python3 tools/make_sudoku.py [số_đề_mỗi_mức]
"""
import os
import random
import sys

N_PER = int(sys.argv[1]) if len(sys.argv) > 1 else 120
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "kindle", "dashboard", "lib", "sudoku.txt")

PEERS = []
for i in range(81):
    r, c = divmod(i, 9)
    b = (r // 3) * 3 * 9 + (c // 3) * 3
    p = set(r * 9 + k for k in range(9)) | set(k * 9 + c for k in range(9)) | set(b + (k // 3) * 9 + k % 3 for k in range(9))
    p.discard(i)
    PEERS.append(tuple(p))
UNITS = [[r * 9 + k for k in range(9)] for r in range(9)] + [[k * 9 + c for k in range(9)] for c in range(9)] + \
        [[(br * 3 + k // 3) * 9 + bc * 3 + k % 3 for k in range(9)] for br in range(3) for bc in range(3)]


def candidates(g, i):
    used = {g[j] for j in PEERS[i]}
    return [d for d in range(1, 10) if d not in used]


def count_solutions(g, limit=2):
    g = g[:]
    n = [0]

    def rec():
        best, bc = -1, None
        for i in range(81):
            if g[i] == 0:
                cs = candidates(g, i)
                if not cs:
                    return
                if bc is None or len(cs) < len(bc):
                    best, bc = i, cs
                    if len(cs) == 1:
                        break
        if best < 0:
            n[0] += 1
            return
        for d in bc:
            g[best] = d
            rec()
            if n[0] >= limit:
                break
        g[best] = 0

    rec()
    return n[0]


def full_grid():
    g = [0] * 81

    def rec(i):
        if i == 81:
            return True
        ds = candidates(g, i)
        random.shuffle(ds)
        for d in ds:
            g[i] = d
            if rec(i + 1):
                return True
        g[i] = 0
        return False

    rec(0)
    return g


def logic_level(puzzle):
    """1 nếu giải được chỉ bằng ô đơn; 2 nếu cần thêm chỗ duy nhất; 3 nếu không."""
    g = puzzle[:]
    used_hidden = False
    while 0 in g:
        moved = False
        for i in range(81):
            if g[i] == 0:
                cs = candidates(g, i)
                if len(cs) == 1:
                    g[i] = cs[0]
                    moved = True
        if moved:
            continue
        for u in UNITS:
            for d in range(1, 10):
                if any(g[i] == d for i in u):
                    continue
                spots = [i for i in u if g[i] == 0 and d in candidates(g, i)]
                if len(spots) == 1:
                    g[spots[0]] = d
                    moved = True
                    used_hidden = True
        if not moved:
            return 3
    return 2 if used_hidden else 1


def make(level):
    target = {1: 40, 2: 33, 3: 28, 4: 24}[level]
    while True:
        sol = full_grid()
        p = sol[:]
        cells = list(range(81))
        random.shuffle(cells)
        for i in cells:
            if sum(1 for v in p if v) <= target:
                break
            keep = p[i]
            p[i] = 0
            if count_solutions(p) != 1:
                p[i] = keep
        clues = sum(1 for v in p if v)
        lv = logic_level(p)
        if level == 1 and lv == 1 and clues <= 44:
            return p, sol
        if level == 2 and lv == 2 and clues <= 36:
            return p, sol
        if level == 3 and lv == 3 and clues <= 31:
            return p, sol
        if level == 4 and lv == 3 and clues <= 26:
            return p, sol


def main():
    random.seed(20261117)
    lines = []
    for level in (1, 2, 3, 4):
        for k in range(N_PER):
            p, s = make(level)
            lines.append("%d|%s|%s" % (level, "".join(map(str, p)), "".join(map(str, s))))
        print("mức %d: %d đề" % (level, N_PER), file=sys.stderr)
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(OUT, len(lines), "đề")


if __name__ == "__main__":
    main()
