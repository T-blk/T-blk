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

Mặc định **Kindle tự vẽ dashboard**, không cần máy tính:
- đồng hồ, thứ và ngày (đồng hồ của Kindle, cập nhật mỗi phút);
- **lịch tháng để bàn**, có gạch chân dưới những ngày có sự kiện;
- **sự kiện Apple Calendar** (link ICS công khai của iCloud, hoặc Google Calendar);
- thời tiết (Open-Meteo, lấy qua Wi-Fi);
- **ảnh của bạn**, đổi theo chu kỳ (`dashboard/photos/`).

Chữ được vẽ bằng FBInk (lấy từ gói KOReader) với phông Noto Sans, có đầy đủ
dấu tiếng Việt. Ảnh được vẽ bằng `eips`.

### Lịch Apple (iCloud)
Trên Mac, mở app **Lịch**, chuột phải vào lịch ở cột trái → **Chia sẻ lịch…**
→ tick **Lịch công khai** → sao chép link `webcal://…`. Dán link vào `ICS_URL`
trong `dashboard/dash.conf`. Muốn lấy nhiều lịch thì dán nhiều link, cách nhau
bằng dấu cách. Lưu ý: ai có link cũng xem được lịch đó.

Hỗ trợ: sự kiện thường, sự kiện cả ngày, giờ UTC, lặp ngày/tuần
(BYDAY)/tháng/năm, INTERVAL, COUNT, UNTIL, EXDATE. Chưa hỗ trợ các quy tắc lặp
phức tạp như "thứ Hai đầu tiên của tháng".

### Ảnh
```bash
python3 tools/prepare_photos.py ~/Pictures/cho-kindle kindle/dashboard/photos
```
Script tạo 4 cỡ ảnh thang xám (khung dọc, khung ngang, toàn màn hình dọc, toàn màn hình ngang). Sau đó chép thư
mục `photos` vào Kindle. Ảnh HEIC từ iPhone cần cài thêm `pip3 install pillow-heif`.

KUAL **không chạy** trên bộ jailbreak "hdnext", nên dashboard là các
**scriptlet**: file `.sh` trong `documents/` hiện như sách, bấm vào là chạy.

1. Cắm Kindle vào Mac và chép file:
   ```bash
   ditto --norsrc --noextattr --noacl kindle/dashboard /Volumes/Kindle/dashboard
   ditto --norsrc --noextattr --noacl kindle/documents /Volumes/Kindle/documents
   find /Volumes/Kindle -name '._*' -delete
   diskutil eject /Volumes/Kindle
   ```
2. Sửa tuỳ ý trong `/Volumes/Kindle/dashboard/`:
   - `dash.conf`: thành phố và toạ độ, link lịch, đèn nền, hướng màn hình, chu kỳ làm mới.
   - `todo.txt`: danh sách việc (hiện khi không có link lịch).
3. Trên Kindle, trong thư viện:
   - **Dashboard - Test**: vẽ 1 lần, giao diện Kindle vẫn chạy và sẽ vẽ đè lên. Log ghi vào `dashboard/test.log`.
   - **Dashboard - Bat**: tắt giao diện Kindle, chạy dashboard có cảm ứng.
   - **Dashboard - Tat**: tắt dashboard (khi giao diện Kindle còn bấm được).
   - **Dashboard - Do cam ung**: dò cảm ứng 25 giây, ghi vào `dashboard/touch.log`.
   - **Dashboard - Tu chay: Bat / Tat**: bật hoặc tắt tự chạy khi khởi động.
4. **Thoát**: chạm **Về Home** hoặc bấm nút nguồn. Nếu cả hai không ăn, giữ
   nút nguồn khoảng 20 giây để khởi động lại.

### Chạm trên màn hình (khi đang chạy "Dashboard - Bat")
| Chạm vào | Tác dụng |
|---|---|
| **Về Home** (góc trên phải) hoặc bấm nút nguồn | thoát về giao diện Kindle |
| **– / +** cạnh chữ "Đèn" | giảm hoặc tăng đèn nền |
| nửa trái / nửa phải **lịch tháng** | tháng trước / tháng sau |
| **tiêu đề lịch** ("Tháng …") | về tháng hiện tại |
| **phần sự kiện** | trang sự kiện tiếp theo |
| **ảnh** | xem ảnh toàn màn hình. Ở đó chạm trái/phải để xem ảnh trước/sau, chạm phía trên để quay lại |

Sau `IDLE_RESET_MIN` phút không chạm, dashboard tự quay về tháng hiện tại và trang 1.

### Cài đặt trong `dash.conf`
- `ICS_URL`: nhiều link cách nhau bằng dấu cách. Gắn nhãn bằng `CV=webcal://…` để hiện `[CV]` trước sự kiện.
- `ORIENTATION=ngang`: bố cục nằm ngang (thử nghiệm). Chữ bị ngược thì đổi `ROTATE_LAND` giữa 1 và 3. Chạm bị lệch thì đặt `LAND_TOUCH_INVERT=1`.
- `LIGHT_DAY` / `LIGHT_NIGHT`, `NIGHT_START` / `NIGHT_END`, `REFRESH_NIGHT_MIN`, `NIGHT_INVERT`: đèn nền và chế độ ban đêm.
- `TOUCH_*`: hiệu chỉnh toạ độ chạm (chạy "Do cam ung" rồi xem `touch.log`).

### Tự chạy khi khởi động
Bấm **Dashboard - Tu chay: Bat** (cần làm một lần). Từ đó, mỗi lần Kindle
khởi động thì 45 giây sau dashboard tự bật. Muốn tắt: bấm
**Dashboard - Tu chay: Tat**, hoặc xoá file `dashboard/AUTOSTART` qua USB.
Scriptlet này ghi một file vào `/etc/upstart` của Kindle, kết quả ghi vào
`dashboard/autostart.log`.

Muốn hiện những thứ Kindle không tự lấy được (lịch, Notion...), điền
`SERVER_URL` trong `dash.conf` để chuyển sang chế độ tải ảnh từ
`server/dashboard_server.py`.

## Pin

Ở chế độ Bat, Kindle không ngủ (đồng hồ cập nhật mỗi phút) nên pin chỉ trụ
khoảng một đến vài ngày, chưa đo trên máy thật. Muốn dùng 24/7 thì cứ để cắm
sạc. Muốn tiết kiệm pin thì tăng `REFRESH_MIN` trong `dash.conf`.

## Gỡ lỗi

- Log nằm ở `dashboard/dash.log` và `dashboard/test.log` trên Kindle.
- Log ghi rõ thời tiết lấy được qua `curl https` hay `wget http`, hoặc báo `fetch failed`.
- Chế độ server: Kindle phải vào được `SERVER_URL`. Kiểm tra IP của Mac (IP có thể đổi) và tường lửa.
