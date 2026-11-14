# Xuất OpenAPI từ backend rồi sinh lại client Dart vào app/lib/api.
# Chạy từ gốc repo:  powershell -File scripts/gen-api-client.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Push-Location "$root/backend"
try { npm run openapi } finally { Pop-Location }

Push-Location "$root/app"
try {
  if (Test-Path lib/api) { Remove-Item -Recurse -Force lib/api }
  dart run swagger_parser
  dart format lib/api --line-length 100 | Out-Null
} finally { Pop-Location }

Write-Host 'Đã sinh lại app/lib/api từ docs/openapi.json'
