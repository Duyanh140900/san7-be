/**
 * Xuất OpenAPI ra docs/openapi.json (không cần DB). Dùng bởi scripts/gen-api-client.
 * Chạy: npm run openapi
 */
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';

process.env.DATABASE_URL ??=
  'postgresql://openapi:openapi@localhost:5432/openapi';
process.env.JWT_ACCESS_SECRET ??= 'openapi-export-only';
process.env.GOOGLE_WEB_CLIENT_ID ??= 'openapi-export-only';

const { AppModule } = await import('./app.module.js');
const { buildOpenApi, setupApp } = await import('./setup-app.js');

const app = await NestFactory.create(AppModule, { logger: ['error'] });
setupApp(app);
const doc = buildOpenApi(app);
const out = resolve(import.meta.dirname, '../../docs/openapi.json');
writeFileSync(out, JSON.stringify(doc, null, 2) + '\n');
await app.close();
console.log(`Đã ghi ${out}`);
