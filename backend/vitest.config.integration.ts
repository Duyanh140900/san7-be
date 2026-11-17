import { defineConfig } from 'vitest/config';

/** Test tích hợp: cần Postgres + Redis thật (tự bỏ qua nếu không kết nối được). */
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['**/*.int-spec.ts'],
    testTimeout: 60_000,
    hookTimeout: 120_000,
    fileParallelism: false,
  },
});
