# Công cụ thử (chạy trên máy tính, không cần Kindle)

Kindle dùng BusyBox (`ash`, `awk` rút gọn). Nên thử bằng BusyBox thật (`apt-get install busybox`), không chỉ bash/mawk.

| Tệp | Dùng để |
|---|---|
| `fbsim.c` | Màn hình e-ink giả, đóng vai `fbink` và `eips`. Có 2 lớp: `fb` (bộ nhớ, thứ đã vẽ) và `screen` (thứ người dùng thấy, chỉ đổi khi có lệnh làm mới). Sau mỗi vòng lặp hai lớp phải giống hệt nhau — khác là có nội dung đã vẽ mà chưa bao giờ hiện ra. Biên dịch: `gcc -O2 -o fbsim fbsim.c`; đặt làm `dashboard/bin/fbink` và `eips` trong PATH; biến môi trường `FBSIM_DIR` (thư mục trạng thái), `FBDEV=$FBSIM_DIR/fb`, `FB_SYS=<thư mục có tệp stride=768, bits_per_pixel=8>`, `FBSIM_TRACE=1` để ghi mọi lệnh vẽ. Mỗi ký tự có "nét" riêng theo mã ký tự (đổi một chữ số chỉ đổi ô của chữ số đó), để thử được phần đồng hồ chỉ vẽ lại chữ số đổi. Chiều rộng chữ được ước lượng rộng hơn chữ Inter thật, nên ở mép phải ô đồng hồ thường báo lệch vài cột; bản cũ cũng bị y như vậy, không phải lỗi trên máy. Ảnh PNG có tệp `<ảnh>.raw` ("W H\n" + byte xám) thì dùng điểm ảnh thật. |
| `pychess.py` | Bộ luật cờ vua độc lập bằng Python (đã khớp perft chuẩn) để chấm máy awk. `python3 pychess.py` in các số perft. |
| `referee.py` | Cho `lib/chess.awk` tự đấu, chấm từng nước và kết quả: `python3 referee.py <awk> <số ván> <hạt giống> [giây/nước]`, ví dụ `python3 referee.py "busybox awk"`… (truyền đường dẫn tới awk). |
| `clobber.py` | Rà lỗi "trùng tên biến": shell không có biến cục bộ, hàm A đặt biến, gọi hàm B (B cũng ghi biến đó), rồi A đọc lại. Chạy trong `kindle/dashboard`: `python3 ../../tools/test/clobber.py <tên các hàm cần rà>`. Không mô hình hoá vòng lặp — biến giữ qua nhiều vòng lặp có gọi hàm vẽ thì phải tự xem. |

Kiểm tra nhanh luật cờ vua: `awk -v ACT=perft -v ARG=3 -v CHKEV=1 -v SAVE=/dev/null -f kindle/dashboard/lib/chess.awk` phải in `8902` và `sai_điểm 0`.

Quy ước đặt tên biến trong mã shell: các hàm vẽ chữ (`tx`, `txcap`, `twv`, `tw_sh`, `txt`…) ghi đè các biến ngắn
`_a _c _f _k _n _o _p _r _s _t _v _w _px _bt _lx f r bt fl inv`. Biến nào phải sống qua một lần gọi hàm vẽ thì đặt tên có tiền tố riêng (`SU_`, `CH_`, `GO_`, `GM_`, `CS_`…).
