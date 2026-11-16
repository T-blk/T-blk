# Kindle Dashboard — biến Kindle Paperwhite 2 thành màn hình thông tin thường trực

![preview](docs/preview.png)

## Kiến trúc

```
[Máy tính / Raspberry Pi]                    [Kindle PW2 đã jailbreak]
 server/dashboard_server.py  --- Wi-Fi --->   KUAL > Dashboard > Bật
 render PNG 758x1024 xám                      wget PNG -> eips vẽ lên e-ink
 (giờ, thời tiết, todo, ...)                  ngủ sâu (rtcwake) 10 phút -> lặp
```

Toàn bộ phần xử lý chạy trên server, Kindle chỉ tải ảnh về và hiển thị.
Muốn thêm widget nào (lịch, giá coin, doanh số, chỉ số server, ...) thì sửa
mỗi Python, không phải đụng gì vào Kindle.

## 1. Server

```bash
cd server
pip install -r requirements.txt
cp config.example.json config.json   # sửa thành phố, toạ độ, tiêu đề
python3 dashboard_server.py --render preview.png   # xem trước trên PC
python3 dashboard_server.py                         # chạy server :8080
```

- Thời tiết lấy từ Open-Meteo, miễn phí và không cần API key.
- Danh sách việc lấy từ `server/todo.txt`. Sửa file là lần làm mới sau sẽ cập nhật.
- Muốn có widget mới thì viết thêm vào hàm `render()`.

## 2. Kindle (PW2 firmware 5.12.2.2, đã jailbreak bằng WinterBreak2)

Firmware này dùng bộ jailbreak "hdnext". KUAL **không chạy**, nên dashboard
được làm dưới dạng **scriptlet**: file `.sh` đặt trong `documents/` sẽ hiện
trong thư viện như một cuốn sách, bấm vào là chạy.

1. Cắm Kindle vào Mac, chép file vào Kindle:
   ```bash
   ditto --norsrc --noextattr --noacl kindle/dashboard /Volumes/Kindle/dashboard
   ditto --norsrc --noextattr --noacl kindle/documents /Volumes/Kindle/documents
   find /Volumes/Kindle -name '._*' -delete
   ```
2. Sửa `SERVER_URL` trong `/Volumes/Kindle/dashboard/dash.conf` thành IP của
   Mac (`ipconfig getifaddr en0`), rồi chạy `diskutil eject /Volumes/Kindle`.
3. Trên Kindle (bật Wi-Fi, cùng mạng với Mac), trong thư viện:
   - **Dashboard - Test**: vẽ 1 lần, giao diện Kindle vẫn chạy. Log ghi vào `dashboard/test.log`.
   - **Dashboard - Bat**: tắt giao diện Kindle, làm mới liên tục.
   - **Dashboard - Tat**: tắt dashboard (khi giao diện Kindle còn bấm được).
4. **Thoát khi đang ở chế độ dashboard**: giữ nút nguồn khoảng 20 giây để
   khởi động lại. Dashboard không tự chạy khi máy khởi động.

## Pin

Mặc định `DEEP_SLEEP=0`. Nếu bật `DEEP_SLEEP=1` (chưa thử trên máy thật), giữa hai lần làm mới Kindle ngủ sâu và tắt Wi-Fi.
Làm mới 10 phút/lần thì pin trụ được cỡ vài ngày đến 1–2 tuần, tuỳ tình
trạng pin. Muốn dùng 24/7 thì cứ để cắm sạc. Nếu máy không tự thức dậy, đổi
`RTC_DEV` sang `/dev/rtc0` hoặc đặt `DEEP_SLEEP=0`.

## Gỡ lỗi

- Log nằm ở `dashboard/dash.log` và `dashboard/test.log` trên Kindle.
- Kindle phải vào được `SERVER_URL`. Kiểm tra firewall trên máy chạy server.
