# Google Calculator for iOS 18 (Material 3)

Ứng dụng máy tính viết bằng **SwiftUI** dành cho **iOS 18+**, thiết kế theo ngôn ngữ **Material 3** của Google Calculator. Tích hợp sẵn **XcodeGen** và **GitHub Actions** để tự động biên dịch và đóng gói file `.ipa` trực tiếp trên GitHub mà không cần máy Mac.

## Tính năng chính
- Giao diện Material 3 hỗ trợ tự động chuyển đổi **Sáng / Tối / Theo hệ thống**.
- **Xem trước kết quả trực tiếp (Live Preview)** ngay trong lúc gõ biểu thức.
- Phím ngoặc thông minh `( )`, hỗ trợ nhân ẩn (`2π`, `2(3)`), giai thừa `!`, chế độ `DEG / RAD`.
- Bảng phím khoa học thu gọn / mở rộng mượt mà (`√`, `π`, `^`, `!`, `sin`, `cos`, `tan`, `ln`, `log`, `1/x`).
- Lịch sử tính toán (History Sheet): chạm để nạp lại kết quả, vuốt để xóa.

## Cách đẩy lên GitHub và đóng gói file `.ipa`

### Bước 1: Tạo kho lưu trữ (Repository) trên GitHub
1. Truy cập [GitHub](https://github.com/new) và tạo một repo mới (nên chọn **Public** để dùng miễn phí GitHub Actions macOS).
2. Giải nén file zip này, mở Terminal/Command Prompt trong thư mục `GoogleCalculator-iOS` và chạy:

```bash
git init
git add .
git commit -m "Initial commit: Google Calculator iOS 18"
git branch -M main
git remote add origin https://github.com/<TEN_USER_CUA_BAN>/<TEN_REPO>.git
git push -u origin main
```

### Bước 2: Tải file `.ipa` đã đóng gói
1. Vào tab **Actions** trên repo GitHub của bạn.
2. Chọn workflow **Build & Package iOS IPA** đang chạy (mất khoảng 2–4 phút).
3. Khi hoàn tất (dấu tick xanh), kéo xuống mục **Artifacts** và bấm tải **GoogleCalculator-iOS-IPA**.

*(Tùy chọn)* Để tự động tạo bản phát hành trong mục **Releases**, chỉ cần đẩy thêm tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Bước 3: Cài đặt lên iPhone
File `.ipa` xuất ra là bản chưa ký (unsigned). Bạn có thể cài lên iPhone bằng:
- **Sideloadly** (Windows/macOS) hoặc **AltStore / SideStore** bằng tài khoản Apple ID cá nhân.
