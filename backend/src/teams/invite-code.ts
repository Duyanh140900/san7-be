import { randomInt } from 'node:crypto';

// Bỏ các ký tự dễ nhầm (0/O, 1/I/L)
const LETTERS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/** Mã mời dạng "CG7-2486": 3 ký tự chữ/số + 4 chữ số. */
export function generateInviteCode(): string {
  let head = '';
  for (let i = 0; i < 3; i++) head += LETTERS[randomInt(LETTERS.length)];
  const tail = String(randomInt(10_000)).padStart(4, '0');
  return `${head}-${tail}`;
}

/** Chuẩn hoá mã người dùng gõ: bỏ khoảng trắng, viết hoa, tự thêm dấu gạch. */
export function normalizeInviteCode(input: string): string {
  const raw = input.replace(/[\s-]/g, '').toUpperCase();
  return raw.length === 7 ? `${raw.slice(0, 3)}-${raw.slice(3)}` : raw;
}

export const INVITE_CODE_PATTERN = /^[A-Z0-9]{3}-\d{4}$/;
