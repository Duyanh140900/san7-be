/** Kiểm tra biến môi trường khi khởi động. Thiếu biến bắt buộc thì dừng ngay. */
export interface Env {
  NODE_ENV: string;
  PORT: number;
  DATABASE_URL: string;
  REDIS_URL: string;
  JWT_ACCESS_SECRET: string;
  JWT_ACCESS_TTL: string;
  REFRESH_TOKEN_TTL_DAYS: number;
  GOOGLE_WEB_CLIENT_ID: string;
  LOG_LEVEL: string;
  /** JSON service account Firebase (base64 hoặc thô); rỗng = tắt push */
  FIREBASE_SERVICE_ACCOUNT: string;
}

const REQUIRED = [
  'DATABASE_URL',
  'JWT_ACCESS_SECRET',
  'GOOGLE_WEB_CLIENT_ID',
] as const;

export function validateEnv(raw: Record<string, string | undefined>): Env {
  const missing = REQUIRED.filter((k) => !raw[k]);
  if (missing.length) {
    throw new Error(`Thiếu biến môi trường: ${missing.join(', ')}`);
  }
  const nodeEnv = String(raw.NODE_ENV ?? 'development');
  const secret = String(raw.JWT_ACCESS_SECRET);
  if (nodeEnv === 'production' && secret.length < 32) {
    throw new Error(
      'JWT_ACCESS_SECRET phải dài ít nhất 32 ký tự khi chạy production',
    );
  }
  return {
    NODE_ENV: nodeEnv,
    PORT: Number(raw.PORT ?? 3000),
    DATABASE_URL: String(raw.DATABASE_URL),
    REDIS_URL: String(raw.REDIS_URL ?? 'redis://localhost:6379'),
    JWT_ACCESS_SECRET: secret,
    JWT_ACCESS_TTL: String(raw.JWT_ACCESS_TTL ?? '15m'),
    REFRESH_TOKEN_TTL_DAYS: Number(raw.REFRESH_TOKEN_TTL_DAYS ?? 30),
    GOOGLE_WEB_CLIENT_ID: String(raw.GOOGLE_WEB_CLIENT_ID),
    LOG_LEVEL: String(raw.LOG_LEVEL ?? 'info'),
    FIREBASE_SERVICE_ACCOUNT: String(raw.FIREBASE_SERVICE_ACCOUNT ?? ''),
  };
}
