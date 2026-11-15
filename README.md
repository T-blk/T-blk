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

## 2. Kindle

1. **Sạc cho pin sống lại trước** (xem phần cứu pin ở dưới).
2. **Jailbreak**: vào Settings > Device Info xem phiên bản firmware, rồi làm
   theo hướng dẫn cho đúng phiên bản đó tại https://kindlemodding.org.
3. Cài **KUAL** và **MRPI** (hướng dẫn có trên cùng trang).
4. Cắm USB vào máy tính, chép thư mục `kindle/extensions/dashboard` vào
   `extensions/` trên ổ Kindle.
5. Sửa `extensions/dashboard/dash.conf`: đặt `SERVER_URL` thành IP LAN của
   máy chạy server.
6. Mở KUAL > Dashboard > **Vẽ 1 lần (test)**. Hình hiện lên đúng thì chọn
   **Bật dashboard**.
7. Muốn quay về đọc sách thì chọn KUAL > Dashboard > **Tắt dashboard**. Nếu
   đã bị khoá ngoài màn hình thì giữ nút nguồn 20–40 giây để khởi động lại.

## Pin

Ở chế độ `DEEP_SLEEP=1`, giữa hai lần làm mới Kindle ngủ sâu và tắt Wi-Fi.
Làm mới 10 phút/lần thì pin trụ được cỡ vài ngày đến 1–2 tuần, tuỳ tình
trạng pin. Muốn dùng 24/7 thì cứ để cắm sạc. Nếu máy không tự thức dậy, đổi
`RTC_DEV` sang `/dev/rtc0` hoặc đặt `DEEP_SLEEP=0`.

## Gỡ lỗi

- Log nằm ở `extensions/dashboard/dash.log`.
- Kindle phải vào được `SERVER_URL`. Kiểm tra firewall trên máy chạy server.
