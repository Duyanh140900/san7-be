#!/usr/bin/env sh
# Xuất OpenAPI từ backend rồi sinh lại client Dart vào app/lib/api.
# Chạy từ gốc repo:  sh scripts/gen-api-client.sh
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$root/backend" && npm run openapi)
(cd "$root/app" && rm -rf lib/api && dart run swagger_parser && dart format lib/api --line-length 100 >/dev/null)

echo "Đã sinh lại app/lib/api từ docs/openapi.json"
