# Đầu vào: kết quả "cmp -l" của 2 bản chụp vài hàng bộ nhớ màn hình (cột 1 = vị trí byte, tính từ 1).
# In các khoảng CỘT có điểm ảnh đổi, mỗi dòng "trái rộng" (bước 8 điểm ảnh), chỉ trong [L, R).
# Đổi nhiều quá (>= CAP điểm ảnh) thì in "FULL". Biến: S (byte mỗi hàng), L R, CAP.
{ c = ($1 - 1) % S; if (c >= L && c < R) B[int(c / 8)] = 1; n++ }
END {
  if (n >= CAP) { print "FULL"; exit }
  s = -1; g = 0; last = int(R / 8) + 3
  for (i = int(L / 8); i <= last; i++) {
    if (i in B) { if (s < 0) s = i; e = i; g = 0 }
    else if (s >= 0 && ++g > 2) { print s * 8, (e - s + 1) * 8; s = -1; g = 0 }
  }
  if (s >= 0) print s * 8, (e - s + 1) * 8
}
