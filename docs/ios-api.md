# Kindle Dashboard — API điều khiển cho ứng dụng iOS (v1)

Tài liệu cho nhóm xây ứng dụng iOS kết nối, điều khiển và cài đặt Kindle Dashboard qua mạng Wi-Fi nội bộ.
Áp dụng từ bản dashboard **2026.11.17.05** trở lên. Mã máy chủ: `kindle/dashboard/remote_srv.sh`.

## 1. Mô hình kết nối

- Kindle chạy một máy chủ HTTP rất nhỏ (busybox `nc`, xử lý **từng yêu cầu một**), cổng mặc định **8080**.
- Chỉ hoạt động khi người dùng bật **Cài đặt → Điều khiển từ điện thoại** trên Kindle (hoặc `REMOTE=1`).
  Màn hình đó hiện địa chỉ `http://<IP>:8080` và **mã PIN 4 số**.
- Chỉ trong mạng LAN (cùng Wi-Fi). Không có máy chủ trung gian, không có HTTPS.
- Xác thực: tham số `k=<PIN>` trên mọi yêu cầu (trừ `/hello`). Sai PIN → `403`.
- Mọi yêu cầu là **GET**; phản hồi JSON UTF-8, có `Content-Length`, `Connection: close`.

## 2. Dò tìm Kindle trong mạng

Kindle không quảng bá Bonjour/mDNS. Hai cách:

1. **Nhập tay** IP (hiện trên Kindle) — luôn có.
2. **Quét dải /24** của Wi-Fi điện thoại: gọi `GET http://<ip>:8080/hello` với timeout ngắn (≈300 ms), song song tối đa ~16 kết nối.
   Máy trả lời đúng định dạng dưới đây là Kindle Dashboard.

```
GET /hello
200 {"app":"kindle-dashboard","api":1,"ver":"2026.11.17.05","port":8080,"auth":"pin"}
```

Lưu `ip`, `port`, `pin` vào Keychain sau lần ghép nối đầu.

## 3. Các endpoint

| Phương thức | Đường dẫn | Mô tả |
|---|---|---|
| GET | `/hello` | Dò tìm, không cần PIN |
| GET | `/api?k=PIN` | Trạng thái hiện tại + chẩn đoán |
| GET | `/settings?k=PIN` | Toàn bộ cài đặt, giá trị hiện tại, các lựa chọn hợp lệ |
| GET | `/c?k=PIN&a=ACTION&v=VALUE` | Gửi lệnh |
| GET | `/c?k=PIN&a=set&key=KEY&v=VALUE` | Đổi một cài đặt |
| GET | `/?k=PIN` | Trang web điều khiển dựng sẵn (dự phòng, không cần cho app) |

### 3.1 `GET /api` — trạng thái

```json
{
  "ok": true,
  "view": "main",            // main | status | settings | msg | photo | reader | ...
  "status": "toilet",        // mã trạng thái đang bật, rỗng nếu không
  "layout": "the",
  "page": "main",
  "batt": "87",              // % pin (chuỗi)
  "ver": "2026.11.17.05",
  "diag": [["Pin","87% · không sạc"], ["Hao pin","0.89 %/giờ · còn ~3.3 ngày"], ["Wi-Fi","..."], ...]
}
```

`diag` là danh sách cặp `[nhãn, giá trị]` đã định dạng sẵn tiếng Việt — hiển thị nguyên văn (bảng 2 cột). Kindle cập nhật mỗi ~15 phút.

### 3.2 `GET /settings` — cài đặt

```json
{
  "ok": true,
  "settings": [
    { "group": "look", "key": "LAYOUT", "label": "Bố cục", "value": "the",
      "options": [ {"value":"codien","label":"Cổ điển"}, {"value":"toigian","label":"Tối giản"}, ... ] },
    ...
  ]
}
```

- `group`: `look` (Giao diện) · `power` (Pin & đèn) · `auto` (Tự động theo giờ) · `main` (Chung) — dùng để chia mục trong app.
- Hiển thị mỗi cài đặt như một danh sách chọn (`options`); `label` là tiếng Việt, hiển thị nguyên văn.
- Danh sách sinh tự động từ Kindle → **không hard-code**; bản dashboard mới có thể thêm khoá.

### 3.3 `GET /c?a=set&key=KEY&v=VALUE` — đổi cài đặt

- `KEY` chỉ gồm `A-Z` và `_`; `VALUE` phải là một `options[].value` của khoá đó (chữ thường/số). Sai → bỏ qua (ghi log trên Kindle).
- Phản hồi `{"ok":true}` nghĩa là **đã nhận lệnh**, không phải đã áp dụng xong. Đọc lại `/settings` sau ~2–3 giây để xác nhận.
- Lỗi đầu vào: `400 {"ok":false,"error":"key"}` hoặc `{"ok":false,"error":"value"}`.
- Lưu ý:
  - `LAYOUT`: đổi bố cục sẽ đặt lại `CLOCK_STYLE`, `EVENT_STYLE`, `PHOTO_STYLE` về `auto`.
  - `ORIENTATION`: xoay màn hình mất vài giây; không có bước xác nhận khi đổi từ điện thoại.
  - `REMOTE=0`: tắt máy chủ — app sẽ mất kết nối (hiện cảnh báo trước khi gửi).

### 3.4 `GET /c?a=ACTION&v=VALUE` — lệnh

| `a` | `v` | Tác dụng |
|---|---|---|
| `status` | `taptrung` `hop` `goidien` `roidi` `toilet` `cafe` `antrua` `ngutrua` `vengay` | Bật màn hình trạng thái |
| `back` | — | Thoát trạng thái / về màn hình chính |
| `layout` | `codien` `toigian` `thuysi` `the` `anh` `chu` `lich` | Đổi bố cục (như `set LAYOUT`) |
| `page` | `main` `tin` `bloc` `dem` `pomo` `news` | Chuyển trang |
| `light` | `up` / `down` | Đèn nền ±2 nấc (0–24) |
| `msg` | văn bản (URL-encode, ≤ 400 ký tự, tiếng Việt OK) | Hiện lời nhắn to trên Kindle; người dùng chạm để đóng |
| `refresh` | — | Vẽ lại toàn màn hình |
| `home` | — | Thoát dashboard, về giao diện Kindle (máy chủ dừng theo) |

Tên hiển thị gợi ý cho trạng thái: Tập trung · Đang họp · Điện thoại · Ra ngoài · Toilet · Cà phê · Ăn trưa · Ngủ trưa · Tan làm.

## 4. Yêu cầu phía iOS

**Info.plist**

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Kết nối tới Kindle Dashboard trong mạng Wi-Fi nhà bạn.</string>
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key><true/>
</dict>
```

- iOS 14+: lần gọi mạng LAN đầu tiên sẽ hiện hộp thoại quyền **Mạng cục bộ** — gọi `/hello` khi người dùng bấm “Tìm Kindle” để hộp thoại xuất hiện đúng lúc.
- Không cần `NSBonjourServices` (không dùng Bonjour).
- `URLSession`: `timeoutIntervalForRequest` 3–5 s; **không gửi song song tới cùng một Kindle** (máy chủ xử lý tuần tự) — xếp hàng lệnh, mỗi lệnh xong mới gửi lệnh kế.
- Thông báo lỗi gợi ý: “Không kết nối được Kindle — kiểm tra Kindle đang mở dashboard, đã bật Điều khiển từ điện thoại và cùng Wi-Fi”.

**Ví dụ Swift**

```swift
struct KindleClient {
    let base: URL      // http://192.168.1.23:8080
    let pin: String

    func send(_ action: String, _ value: String = "") async throws {
        var c = URLComponents(url: base.appendingPathComponent("c"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "k", value: pin), .init(name: "a", value: action), .init(name: "v", value: value)]
        let (_, r) = try await URLSession.shared.data(from: c.url!)
        guard (r as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    func set(_ key: String, _ value: String) async throws {
        var c = URLComponents(url: base.appendingPathComponent("c"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "k", value: pin), .init(name: "a", value: "set"),
                        .init(name: "key", value: key), .init(name: "v", value: value)]
        _ = try await URLSession.shared.data(from: c.url!)
    }
}
```

Lưu ý `URLQueryItem` mã hoá `+` không thành `%2B` — với `msg`, thay `+` bằng `%2B` thủ công (máy chủ hiểu `+` là dấu cách).

## 5. Gợi ý màn hình ứng dụng

1. **Ghép nối**: “Tìm Kindle” (quét `/hello`) hoặc nhập IP → nhập PIN → thử `/api`.
2. **Trang chính**: pin + trạng thái hiện tại (`/api`), lưới 9 nút trạng thái + “Tôi đã quay lại”, ô gửi lời nhắn.
3. **Giao diện**: bố cục, đồng hồ, sự kiện, ảnh, tương phản… (nhóm `look` từ `/settings`).
4. **Pin & đèn / Tự động**: nhóm `power`, `auto`.
5. **Chẩn đoán**: bảng `diag`.
6. Widget / Shortcuts (App Intents): “Bật Toilet trên Kindle”, “Gửi lời nhắn tới Kindle”.
7. Làm mới `/api` mỗi 30 giây khi app mở; không chạy nền.

## 6. Giới hạn & bảo mật

- PIN 4 số, truyền rõ qua HTTP trong LAN — mức “không để người lạ trong cùng Wi-Fi bấm nhầm”, không phải bảo mật mạnh.
- Khi tính năng bật, Kindle giữ Wi-Fi luôn mở → tốn pin hơn; app nên hiển thị pin để người dùng biết.
- Kindle có thể đang ngủ sâu ban đêm (không trả lời) — coi là “tạm offline”, không báo lỗi gắt.
- Thay đổi API sẽ tăng số `api` trong `/hello`; app nên kiểm tra `api == 1`.
