## Floodlight Night assets & motion

- `PitchImages.forId(id)` selects a stable night-pitch image; `withBottomGradient` keeps copy readable on real photos.
- `PitchImages` contains paths for the logo, welcome art, four pitch photos, player, trophy and default avatar.
- `FloodlightBeams`, `KenBurnsImage`, `StaggeredRise` provide hero beams, slow image zoom and staged entries.
- `ShineSweep` is applied by default to `LimeButton` and `TicketCard`; use `LimeButton(shine: false)` to opt out.
- `FloatingMotion`, `RadarRipple`, `PulseGlow` support 3D art, search/location and LIVE/hot badges.
- Every animation observes the device Reduce motion preference.

# Bộ widget dùng chung v2 "Floodlight Night"

Nền tảng cho các màn đợt B. Import từ `app/lib/core/`. Nền tối, chữ sáng; **không dùng mã màu rời**, lấy từ `AppColors`.

## Màu, font (`core/theme/tokens.dart`)

| Dùng | Tên |
|---|---|
| Lime đèn pha `#C8FF2E` (nút, nhấn) | `AppColors.lime` (cũ: `primary`) |
| Sân đêm `#06110B` (nền) | `AppColors.night` (cũ: `background`) |
| Cỏ `#11402A` | `AppColors.grass` |
| Kèo nóng `#FF6B2C` / Cúp vàng `#FFC83D` / Đội nhà `#2F7BFF` | `hot` / `trophy` / `home` (chữ nhạt: `hotText`, `homeText`) |
| Thẻ đỏ (lỗi) `#FF5A5F` | `AppColors.card` (cũ: `red`) |
| Thẻ `#0E1F16`, ô/nút phụ `#15291E`, khối xanh `#0B2416` | `surfaceCard`, `surfaceHigh`, `surfaceDeep` |
| Chữ chính / nội dung / phụ / mờ | `textMain` / `textBody` / `textMuted` / `textDim` |
| Chữ trên nền lime | `AppColors.ink` |
| Viền mảnh | `AppColors.line` (8%), `lineStrong` (12%), `lineButton` (14%) |

Tên cũ (`text`, `surface`, `border`, `primarySoft`…) vẫn dùng được, đã map sang màu tối.

- Tiêu đề, số liệu: `AppText.display(size)` (Barlow Condensed ExtraBold Italic, tự gọi `.toUpperCase()` cho chữ).
- Tỉ số, đồng hồ: `AppText.score(size)` (Barlow dựng thẳng, số cùng bề rộng, mặc định lime).
- Nhãn nhỏ: `AppText.label`. Nội dung: font mặc định của theme (Be Vietnam Pro).
- Bo góc: `AppRadius.button` 16, `tile` 24, `hero` 28, `pill`. Vùng bấm tối thiểu `AppSizes.tapTarget` 44.
- Theme: `buildAppTheme()` đã tối; `FilledButton`, `OutlinedButton`, input, snackbar, dialog, bottom sheet đã đổi màu.

## Widget

| Widget (file) | Cách dùng |
|---|---|
| `TeamCrest(name:, color:, width:, pattern:, glow:)` (`team_crest.dart`) | Phù hiệu khiên. `color` là "#RRGGBB" áo đội; chữ viết tắt tự lấy từ tên ("FC Mỹ Đình" → MĐ), tự đổi chữ đen/trắng. `pattern` (`CrestPattern`) mặc định tự chọn theo tên. `TeamAvatar`, `TeamAvatarStack` cũng đã đổi font. |
| `StatusChip(StatusKind.hot)` (`status_chip.dart`) | `hot` KÈO NÓNG, `findOpponent` TÌM ĐỐI, `recruit` TUYỂN NGƯỜI, `result` KẾT QUẢ, `live` LIVE. `label:` ghi đè chữ, `overlay: true` khi đè lên ảnh bìa. |
| `LimeButton(label:, onPressed:, icon:, trailingIcon:, loading:, expand:)` (`lime_button.dart`) | Nút chính. `onPressed: null` = vô hiệu, `loading: true` = vòng xoay. `GhostButton` là nút phụ đặt cạnh. |
| `TicketCard(time:, dateLine:, stats: [(label:, value:)], trailing:)` (`ticket_card.dart`) | Thẻ "VÉ VÀO TRẬN" nền lime, đường răng cưa. `notchColor` đổi nếu nền không phải `night`. |
| `LiveTicker(items: [TickerItem(text, color:, live:)])` (`live_ticker.dart`) | Dải LIVE chạy chữ, kéo full chiều ngang (không lề). Rỗng thì tự ẩn. Tự đứng yên khi bật "giảm chuyển động". |
| `Countdown(target:, onFinished:, builder:)`, `CountdownPill(target:, prefix:)`, `formatCountdown(Duration)` (`countdown.dart`) | Đếm ngược theo giờ máy, cập nhật mỗi giây. `CountdownPill` = viên "Tự huỷ sau 12:34" trên ảnh bìa kèo. |
| `AppTabBar` (`app_shell.dart`) | Thanh tab nổi, 4 mục + nút lime "Đăng kèo" (quả bóng quay). `AppShell` đã dùng sẵn, các màn không cần gọi. |
| `BallMark(size:, spin:)`, `LiveDot()` (`brand_mark.dart`) | Quả bóng logo và chấm cam nhấp nháy. |

## Trạng thái hệ thống, màn 34 (`system_state.dart`)

Không tự chiếm cả màn hình; đặt trong `Expanded` / `Center` / `SliverFillRemaining`. `compact: true` để nhét trong danh sách.

| Widget | Dùng khi |
|---|---|
| `OfflineState(onRetry:, retrying:)` | Mất mạng, "Mất điện sân rồi!". |
| `OfflineBanner()` | Dải cam trên cùng khi mất mạng nhưng vẫn còn dữ liệu cũ. |
| `ErrorState(onRetry:, retrying:, code: 500, onReport:)` | Lỗi máy chủ, "Thẻ đỏ cho hệ thống!". `onReport` null thì ẩn nút "Báo lỗi". |
| `EmptyState(message:, primaryLabel:, onPrimary:, secondaryLabel:, onSecondary:)` | Danh sách rỗng, "Sân đang vắng". `title` đổi được. |
| `LoadingState(label:)`, `Skeleton(width:, height:, radius:, circle:)` | Đang tải: bóng quay + khối xám nhấp nháy. `compact` chỉ còn bóng + chữ. |
| `AsyncView(value:, data:, onRetry:)` (`common.dart`) | Đã dùng các widget trên: tải → `LoadingState`, mất mạng (`ApiError.offline`) → `OfflineState`, lỗi khác → `ErrorState`. Màn nào đang dùng `AsyncView` tự đổi giao diện. |

Ảnh/font đóng gói trong `app/assets/` (khai báo ở `pubspec.yaml`), không tải mạng. Ảnh 3D icon bóng, áo, còi, cúp, giày, thẻ vàng, thẻ đỏ, đồng hồ: `assets/images/icon3d_*.webp`.
