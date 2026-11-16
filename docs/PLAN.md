# Sân 7: Hướng dẫn và phương án triển khai

> **Cách dùng tài liệu này**
> - Mở cuộc trò chuyện mới với Claude Code trong thư mục dự án, dán toàn bộ nội dung này vào, rồi dùng câu lệnh mẫu ở mục 15.
> - Nên lưu file này vào gốc repo với tên `docs/PLAN.md` và chép phần "Quy ước" (mục 12) vào `CLAUDE.md`, để mọi phiên sau đều đọc được.

---

## 1. Sản phẩm

App cộng đồng bóng đá sân 7 (tiếng Việt, ưu tiên mobile):
- **Cáp kèo:** Bảng tin như Facebook, đăng kèo tìm đối, tuyển người, pass sân; ảnh/video; bình luận; 5 cảm xúc (Thích, Tim, Đỉnh, Haha, Tiếc); hẹn lịch và tự đăng lại theo ngày.
- **Nhận kèo:** đội khác gửi yêu cầu, chủ kèo so sánh các đội rồi xác nhận; nhắn tin giữa hai đội trưởng.
- **Đặt sân:** bản đồ sân gần đây, chọn khung giờ, giữ chỗ, sau này thu cọc.
- **Quản lý đội:** thành viên và vai trò, lịch và điểm danh, quỹ (thu/chi/phạt), kết quả trận, bảng vàng, đánh giá uy tín.

**Bản vẽ UI (24 màn mobile + 1 desktop, phong cách Apple):**
`docs/design/san7-ui.html` (bản offline, mở bằng trình duyệt) · bản gốc cần đăng nhập Claude: https://claude.ai/artifact/V2U7i6PSSdpKo5GyzhvMsG
Bấm Play trên từng màn để thử luồng. Code giao diện phải bám theo bản vẽ này.

| Số | Màn | Số | Màn |
|---|---|---|---|
| 1 | Bảng tin | 13 | Gửi nhận kèo |
| 2 | Đăng kèo (hẹn lịch, ảnh/video) | 14 | Chi tiết kèo & bình luận |
| 3 | Bản đồ đặt sân | 15 | Xác nhận đặt sân & cọc |
| 4 | Chi tiết sân & chọn giờ | 16 | Đặt sân thành công (vé QR) |
| 5 | Đội bóng & thành tích | 17 | Kết quả trận & đánh giá |
| 6 | Quỹ đội | 18 | Lịch & điểm danh |
| 7 | Vinh danh & sổ phạt | 19 | Thành viên & mời |
| 8 | Thông báo | 20 | Thêm thu / chi / phạt |
| 9 | Xác nhận đối nhận kèo | 21 | Nhắn tin |
| 10 | Kèo của tôi & lịch đăng | 22 | Hồ sơ đội khác |
| 11 | So sánh đội nhận kèo | 23 | Cá nhân & cài đặt |
| 12 | Đăng nhập Google & vào đội | 24 | Danh sách cảm xúc |

---

## 2. Quyết định kỹ thuật (đã chốt)

| Phần | Lựa chọn |
|---|---|
| App | **Flutter** (Dart), Riverpod, go_router, dio |
| Backend | **Node.js + NestJS** (TypeScript) |
| Cơ sở dữ liệu | **PostgreSQL 16 + PostGIS**, truy cập qua **Prisma** (SQL thuần cho truy vấn vị trí) |
| Hàng đợi, lịch hẹn, cache | **Redis + BullMQ** |
| Realtime | **Socket.IO** (`socket_io_client` bên Flutter) |
| Lưu ảnh/video | Kho file **chuẩn S3** chạy trong Docker (Garage hoặc SeaweedFS); sau chuyển **Cloudflare R2** chỉ bằng đổi cấu hình |
| Xử lý video | **ffmpeg** trong một worker riêng, nén 720p, tối đa 60 giây |
| Đăng nhập | **Google Sign-In**: backend kiểm tra ID token bằng `google-auth-library`, cấp JWT riêng (access + refresh). Thêm **Sign in with Apple** trước khi lên App Store |
| Thông báo đẩy | **Firebase Cloud Messaging** (miễn phí) |
| Bản đồ | **MapLibre / flutter_map** + nguồn bản đồ miễn phí |
| API contract | NestJS xuất **OpenAPI**, sinh client Dart bằng `openapi-generator` (dart-dio) |
| Hạ tầng giai đoạn đầu | **Máy Windows cá nhân**: Docker Desktop (WSL2), mở ra ngoài bằng **Cloudflare Tunnel** |
| Hạ tầng sau | VPS Contabo (8GB → 16GB), cùng file docker-compose |

**Không dùng ở giai đoạn đầu:** OTP/SMS, thanh toán online, Supabase, Firebase Firestore.

---

## 3. Cấu trúc repo (monorepo)

```
san7/
├─ CLAUDE.md                 # quy ước cho AI (mục 12)
├─ docs/PLAN.md              # tài liệu này
├─ docker-compose.yml        # postgres, redis, storage, api, worker, caddy
├─ .env.example              # biến môi trường mẫu, KHÔNG commit .env
├─ backend/                  # NestJS
│  ├─ prisma/schema.prisma
│  ├─ prisma/migrations/
│  └─ src/
│     ├─ main.ts
│     ├─ common/             # guards, interceptors, filters, pagination, money utils
│     ├─ auth/  users/  teams/  members/
│     ├─ posts/  requests/  comments/  reactions/  media/  schedules/
│     ├─ pitches/  bookings/
│     ├─ matches/  attendance/  funds/  honors/
│     ├─ chat/  notifications/
│     └─ jobs/               # BullMQ processors
├─ worker/                   # (có thể gộp vào backend) xử lý video ffmpeg
├─ app/                      # Flutter
│  └─ lib/
│     ├─ main.dart
│     ├─ core/               # theme (tokens), router, api client, auth, socket
│     ├─ api/                # client sinh từ OpenAPI (không sửa tay)
│     └─ features/
│        ├─ auth/ feed/ post_create/ post_detail/ requests/
│        ├─ pitches/ booking/
│        ├─ team/ attendance/ funds/ honors/ match_result/
│        ├─ chat/ notifications/ profile/ reactions/
└─ scripts/                  # backup DB, seed dữ liệu sân, gen-api-client
```

---

## 4. Chuẩn bị môi trường trên Windows

1. **Git**, **Node.js 22 LTS**, **pnpm**.
2. **Docker Desktop** (bật WSL2), đặt tự khởi động cùng Windows.
3. **Flutter SDK** (kèm Dart), **Android Studio** + một máy ảo Android hoặc điện thoại thật bật USB debugging. Chạy `flutter doctor` cho tới khi hết lỗi phần Android.
4. **Cloudflare Tunnel** (`cloudflared`), cài khi cần cho người ở xa thử.
5. Tắt chế độ ngủ khi cắm điện, giới hạn Windows Update tự khởi động lại.
6. **Google Cloud Console:** tạo dự án và OAuth Client cho Android (cần SHA-1 của keystore debug và release) và Web (backend dùng để kiểm tra token).
7. **Firebase:** tạo dự án, bật Cloud Messaging, tải `google-services.json` cho Android.

iOS cần máy Mac hoặc dịch vụ build đám mây (Codemagic). Giai đoạn đầu chỉ làm Android.

---

## 5. Docker Compose (các dịch vụ)

| Dịch vụ | Image | Ghi chú |
|---|---|---|
| `postgres` | `postgis/postgis:16-3.4` | volume riêng, healthcheck |
| `redis` | `redis:7-alpine` | bật AOF |
| `storage` | Garage hoặc SeaweedFS (chuẩn S3) | bucket `media` |
| `api` | build từ `backend/` | phụ thuộc postgres, redis, storage |
| `worker` | cùng image với api, chạy processor BullMQ và ffmpeg | giới hạn CPU/RAM |
| `caddy` | `caddy:2` | reverse proxy, HTTPS khi lên VPS |
| (khi cần) `cloudflared` | `cloudflare/cloudflared` | mở ra internet mà không mở cổng modem |

Yêu cầu: mọi cấu hình đọc từ `.env`; cùng một file compose chạy được trên Windows lẫn VPS.

---

## 6. Mô hình dữ liệu (bảng chính)

Quy ước: khoá chính `uuid`; thời gian `timestamptz` (hiển thị theo Asia/Ho_Chi_Minh); **tiền là số nguyên VND (`bigint`)**, không dùng số thực; enum dùng enum của Postgres hoặc Prisma.

- `users`: google_sub (unique), email, name, avatar_url, position, shirt_number, area, created_at
- `devices`: user_id, fcm_token, platform
- `teams`: name, crest_color, area, level (`sieu_yeu|yeu|tby|tb|tbk|gioi`), invite_code, invite_expires_at, created_by
- `team_members`: team_id, user_id, role (`captain|vice|treasurer|member`), status (`pending|active`), joined_at
- `pitches`: name, district, `location geography(Point,4326)`, amenities jsonb, phone (không bắt buộc)
- `bookings`: pitch_id, team_id, start_at, end_at, court_no, status (`held|confirmed|cancelled`), price, deposit, code
- `posts` (kèo): team_id, author_id, type (`find_opponent|recruit|pass_pitch`), start_at, end_at, pitch_id, booking_id, level, deal (`split|loser_pays|drinks|friendly`), ratio_win, ratio_lose, body, status (`open|matched|closed`), schedule_id
- `post_media`: post_id, kind (`image|video`), storage_key, width, height, duration_s, order, processing_status
- `post_schedules`: team_id, template jsonb, weekdays int[], post_time, ends_on, paused, skipped_dates date[]
- `match_requests`: post_id, team_id, people_count, ratio_win, ratio_lose, message, status (`pending|accepted|declined|expired|cancelled`), expires_at
- `matches`: home_team_id, away_team_id, post_id, booking_id, start_at, status, home_score, away_score, home_confirmed, away_confirmed
- `match_stats`: match_id, user_id, goals, assists
- `mvp_votes`: match_id, voter_id, player_id
- `team_reviews`: match_id, from_team_id, to_team_id, reputation (1–5), fairplay (1–5), tags text[]
- `events` (lịch đội, gồm trận và đá nội bộ) + `attendances`: event_id, user_id, status (`go|maybe|no`), note
- `fund_transactions`: team_id, type (`income|expense|fine`), amount, category, member_id, match_id, note, paid, created_by
- `fine_rules`: team_id, name, amount
- `comments`: post_id, parent_id, user_id, body
- `reactions`: target_type (`post|comment`), target_id, user_id, kind (`like|love|fire|haha|sad`); unique (target_type, target_id, user_id)
- `conversations`, `conversation_members`, `messages`
- `notifications`: user_id, type, payload jsonb, read_at

**Chỉ mục cần có:** GIST trên `pitches.location`; `posts (status, start_at)`; `reactions (target_type, target_id)`; `fund_transactions (team_id, created_at)`; `match_requests (post_id, status)`.

**Số liệu tổng hợp** (uy tín đội, tỉ lệ đúng giờ, vua phá lưới, số dư quỹ) tính bằng view hoặc cập nhật trong transaction khi có sự kiện. Không tính lại toàn bộ mỗi lần xem.

---

## 7. API (REST, tiền tố `/v1`)

- **Auth:** `POST /auth/google` (gửi idToken, nhận access + refresh), `POST /auth/refresh`, `POST /auth/logout`
- **Users:** `GET/PATCH /me`, `POST /me/devices`
- **Teams:** CRUD đội, `POST /teams/join` (mã mời), duyệt/từ chối thành viên, đổi vai trò, tạo lại mã mời
- **Posts:** `GET /feed?type=&near=lat,lng&radiusKm=` (phân trang cursor), CRUD kèo, `POST /posts/:id/media` (xin URL tải lên có chữ ký), schedules CRUD + pause/skip
- **Requests:** gửi, huỷ, `GET /posts/:id/requests` (dữ liệu cho màn so sánh), `POST /requests/:id/accept|decline`
- **Comments / Reactions:** CRUD bình luận; `PUT /reactions` (đặt hoặc đổi), `DELETE /reactions`; `GET /reactions?target=` (đếm theo loại + danh sách người)
- **Pitches / Bookings:** `GET /pitches?near=&at=` (kèm khung giờ trống), giữ chỗ, huỷ, đổi giờ
- **Matches:** nhập kết quả, xác nhận từ đội kia, thống kê, bình chọn MVP, đánh giá
- **Attendance:** `PUT /events/:id/attendance`, nhắc người chưa trả lời
- **Funds:** danh sách, thêm thu/chi/phạt (hỗ trợ nhiều người nộp cùng lúc), luật phạt, nhắc đóng quỹ
- **Chat:** danh sách hội thoại, tin nhắn (phân trang)
- **Notifications:** danh sách, đánh dấu đã đọc

**Quy tắc bắt buộc:**
- Phân quyền theo vai trò trong đội bằng guard. Ví dụ: chỉ captain/vice được đăng kèo và chấp nhận yêu cầu; chỉ captain/treasurer được thêm thu chi.
- Thao tác nhiều bước chạy trong **một transaction**. Ví dụ, chấp nhận kèo: cập nhật request → đóng post → tạo match và event → mở điểm danh → từ chối các request khác → gửi thông báo (thông báo đưa vào hàng đợi sau khi commit).
- Validate input bằng `class-validator`, trả lỗi theo một định dạng thống nhất.
- Giới hạn tần suất gọi API (rate limit) cho auth, đăng bài, bình luận.

---

## 8. Realtime và việc chạy nền

**Socket.IO rooms:** `user:{id}` (thông báo), `team:{id}` (điểm danh, quỹ), `conversation:{id}` (chat), `post:{id}` (bình luận, cảm xúc mới). Xác thực socket bằng JWT.

**BullMQ jobs:**

| Job | Khi nào |
|---|---|
| `schedule.publish` | mỗi phút: đăng kèo đến giờ; bỏ qua ngày đã có đối |
| `request.expire` | job trễ 2 giờ sau khi gửi yêu cầu nhận kèo |
| `media.transcode` | sau khi tải video lên: nén 720p, tạo ảnh bìa |
| `push.send` | gửi FCM, gom nhiều thông báo |
| `funds.remind` | theo lịch thủ quỹ đặt |
| `match.prompt_result` | sau giờ kết thúc trận: nhắc nhập kết quả |
| `backup.db` | mỗi đêm: `pg_dump` ra thư mục sao lưu và một nơi khác |

---

## 9. Luồng đăng nhập Google

1. Flutter dùng `google_sign_in` lấy `idToken` (cấu hình `serverClientId` = Web client ID).
2. `POST /v1/auth/google { idToken }`.
3. Backend `verifyIdToken` với audience là Web client ID → lấy `sub, email, name, picture` → upsert `users`.
4. Trả về access token (15 phút) và refresh token (30 ngày, lưu dạng hash, có thể thu hồi).
5. Flutter lưu token bằng `flutter_secure_storage`; dio interceptor tự refresh khi nhận 401.
6. Người dùng mới chưa có hồ sơ cầu thủ hoặc đội thì chuyển sang các bước 2–3 của màn 12.

---

## 10. Kiến trúc app Flutter

- **Theo từng tính năng** (`features/<tên>/{data,domain,presentation}`), Riverpod cho trạng thái, go_router cho điều hướng (thanh tab dùng `StatefulShellRoute`).
- **Theme tokens** lấy từ bản vẽ (đặt ở `core/theme`):
  - Màu: primary `#0066CC`, chữ chính `#1D1D1F`, nền `#F5F5F7`, chữ phụ `#6E6E73`, viền `#E0E0E0`, xanh lá `#248A3D` / `#34C759`, đỏ `#C4000F` / `#D70015`, cam `#FF9500`, thẻ tối `#272729`.
  - Bo góc: thẻ 18, nhóm danh sách 14, nút dạng viên thuốc (999).
  - Font: hệ thống trên iOS; Android dùng Inter (`google_fonts`), có đủ dấu tiếng Việt.
  - Vùng bấm tối thiểu 44px, ẩn thanh cuộn ngang (chỉ vuốt).
- **Thư viện:** `dio`, `riverpod`, `go_router`, `freezed` + `json_serializable`, `google_sign_in`, `flutter_secure_storage`, `socket_io_client`, `firebase_messaging`, `flutter_map`, `geolocator`, `image_picker`, `video_compress`, `video_player`, `cached_network_image`, `intl` (định dạng tiền `1.250.000đ`, ngày tiếng Việt).
- **Client API** sinh từ OpenAPI vào `lib/api/`, không sửa tay; chạy lại `scripts/gen-api-client` mỗi khi backend đổi API.

---

## 11. Lộ trình theo chặng

Mỗi chặng chỉ coi là xong khi: chạy được trên điện thoại Android thật, có test cho logic chính, đã commit.

| Chặng | Nội dung | Màn liên quan |
|---|---|---|
| **M0. Nền móng** | Monorepo, docker-compose, NestJS + Prisma + migration đầu, Flutter khung (theme, router, thanh tab), đăng nhập Google end-to-end, sinh client OpenAPI | 12 |
| **M1. Đội bóng** | Tạo/tham gia đội bằng mã mời, thành viên và vai trò, lịch và điểm danh (realtime), quỹ thu/chi/phạt, luật phạt | 5, 6, 18, 19, 20 |
| **M2. Cáp kèo** | Đăng kèo (chưa media), Bảng tin theo khu vực, chi tiết, gửi/huỷ nhận kèo, so sánh, chấp nhận (transaction), thông báo trong app + FCM | 1, 2, 8, 9, 11, 13, 14 |
| **M3. Đặt sân giữ chỗ** | Seed dữ liệu sân, bản đồ + danh sách, khung giờ trống, giữ chỗ, vé có mã, huỷ/đổi | 3, 4, 15 (bản trả tại sân), 16 |
| **M4. Sau trận** | Nhập kết quả + xác nhận chéo, ghi bàn/kiến tạo/MVP, đánh giá uy tín, bảng vàng, trừ tiền sân vào quỹ | 7, 17, 22 |
| **M5. Cộng đồng** | Ảnh/video (tải lên S3, nén), bình luận, cảm xúc + danh sách, chat, hẹn lịch đăng + Kèo của tôi, trang cá nhân | 10, 21, 23, 24 |
| **M6. Ra mắt** | Sign in with Apple, build iOS, chuyển lên VPS, sao lưu tự động, theo dõi lỗi (Sentry), chính sách riêng tư, đưa lên store | — |
| **Sau đó** | Thanh toán cọc qua cổng đối tác, trang quản lý cho chủ sân, gói Pro, đẩy bài | 15 |

---

## 12. Quy ước (chép vào `CLAUDE.md`)

- Giao tiếp và nội dung giao diện bằng **tiếng Việt**; tên biến, hàm, bảng bằng tiếng Anh.
- Tiền luôn là **số nguyên VND**; hiển thị `1.250.000đ`. Thời gian lưu UTC, hiển thị giờ Việt Nam.
- Backend: mỗi module NestJS có controller, service, DTO và test cho service. Logic nhiều bước dùng `prisma.$transaction`. Không viết logic nghiệp vụ trong controller.
- Mọi endpoint ghi dữ liệu đều có guard kiểm tra vai trò trong đội.
- Không commit `.env`, khoá, keystore. Có `.env.example`.
- Migration Prisma tạo bằng `prisma migrate dev`, không sửa migration đã commit.
- Flutter: không gọi `dio` trực tiếp trong widget, đi qua repository + provider. Không sửa code trong `lib/api/` (code sinh tự động).
- Giao diện bám bản vẽ (link ở mục 1) và theme tokens ở mục 10.
- Sau mỗi thay đổi lớn: chạy test, `flutter analyze`, lint backend; dùng `/code-review` trước khi chốt chặng.
- Commit nhỏ, thông điệp rõ ràng; mỗi chặng một nhánh.

---

## 13. Bảo mật và vận hành

- JWT ngắn hạn + refresh token có thể thu hồi; rate limit cho auth và đăng bài.
- URL tải lên S3 có chữ ký, giới hạn loại và dung lượng file (ảnh ≤ 10MB, video ≤ 60 giây / 100MB trước khi nén).
- Kiểm tra quyền xem dữ liệu đội (quỹ, thành viên) ở mọi endpoint.
- Sao lưu Postgres mỗi đêm, giữ 7 bản, chép thêm ra ổ khác hoặc lên mạng.
- Không mở cổng modem; dùng Cloudflare Tunnel.
- Ghi log có cấu trúc (pino); thêm Sentry ở M6.

---

## 14. Skills nên cài cho Claude Code

Đã kiểm tra nguồn ngày 14/11/2026. Đọc lướt `SKILL.md` trước khi cài.

| Skill | Nguồn | Dùng cho | Cài đặt |
|---|---|---|---|
| **dart-flutter** (plugin chính thức của Flutter team: 10 skill Flutter + 15 skill Dart + Dart MCP server; đã cài sẵn phần skill vào `~/.claude/skills`) | [flutter/skills](https://github.com/flutter/skills), [dart-lang/skills](https://github.com/dart-lang/skills) | Kiến trúc, routing, layout, JSON, test Flutter | Trong Claude Code CLI: `/plugin marketplace add flutter/skills` rồi `/plugin install dart-flutter@dart-flutter`. Hoặc `npx skills add flutter/skills`. Cần Flutter/Dart trong PATH để chạy MCP server. Xem thêm [docs.flutter.dev/ai/get-started](https://docs.flutter.dev/ai/get-started) |
| **supabase-postgres-best-practices** (chính thức của Supabase, áp dụng cho mọi Postgres) | [supabase/agent-skills](https://github.com/supabase/agent-skills) | Thiết kế schema, index, migration, khoá, truy vấn chậm | `npx skills add supabase/agent-skills --skill supabase-postgres-best-practices` |
| **nestjs-expert** (MIT) | [Jeffallan/claude-skills](https://github.com/Jeffallan/claude-skills) | Module, DTO, guard, Prisma, Swagger, test NestJS | `npx skills add Jeffallan/claude-skills --skill nestjs-expert` |
| **nestjs-patterns, docker-patterns, redis-patterns** | [affaan-m/ECC (everything-claude-code)](https://github.com/affaan-m/ECC) | Mẫu NestJS, Docker Compose, Redis/BullMQ | Chỉ chép 3 thư mục `skills/<tên>` vào `~/.claude/skills/`. **Không cài cả bộ ECC** (hơn 1.000 skill, có hook) |

**Đã có sẵn trên máy (cài trước đó):**
- `awesome-design-md`: file `apple/DESIGN.md` làm nguồn theme tokens.
- `impeccable`: `/impeccable critique` và `/impeccable polish` để rà giao diện. Có hướng dẫn cho iOS/Android native.
- `playwright-cli`: kiểm tra trang tài liệu Swagger hoặc trang quản trị web sau này.
- `design-taste-frontend`: chỉ dành cho web, không dùng cho app Flutter.

**Có sẵn trong Claude Code:** `/code-review`, `/security-review`, `/simplify`.

---

## 15. Câu lệnh mẫu để bắt đầu phiên mới

```
Đây là kế hoạch dự án Sân 7 (dán docs/PLAN.md). Tôi làm một mình trên Windows,
đã cài Docker Desktop, Node 22, Flutter, Android Studio.
Hãy làm chặng M0:
1. Tạo monorepo theo mục 3, docker-compose theo mục 5, .env.example.
2. NestJS + Prisma, migration đầu cho users, devices, teams, team_members.
3. Đăng nhập Google theo mục 9 (backend + Flutter), sinh client OpenAPI.
4. Flutter: theme tokens mục 10, router + thanh tab 5 mục như bản vẽ, màn 12.
5. Tạo CLAUDE.md từ mục 12.
Làm từng bước, chạy thử sau mỗi bước, hỏi tôi khi cần Client ID của Google.
```

Các chặng sau: "Làm chặng M1 theo docs/PLAN.md, bám màn 5, 6, 18, 19, 20 trong bản vẽ."

---

## 16. Chi phí tóm tắt

| Giai đoạn | Một lần | Hàng tháng |
|---|---|---|
| Demo (máy Windows) | tên miền ~0,3–1 triệu (không bắt buộc) | ~0 đồng + gói Claude |
| Beta (VPS, lên store) | Google Play ~650 nghìn, Apple ~2,5 triệu/năm | ~1–5 triệu |
| Tăng trưởng | đăng ký doanh nghiệp, pháp lý | ~15–50 triệu |

Ba cách tiết kiệm lớn nhất: chưa làm video ở bản đầu, đăng nhập Google thay cho SMS, dùng bản đồ miễn phí. Các con số là ước tính, kiểm tra lại giá nhà cung cấp trước khi chốt.
