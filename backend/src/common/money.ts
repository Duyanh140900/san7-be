/** Tiền lưu bigint (VND). JSON không có bigint nên API trả số nguyên thường (an toàn tới ~9 triệu tỷ). */
export function toMoney(v: bigint): number {
  return Number(v);
}

/** Giới hạn một khoản tiền: 1đ tới 1 tỷ. */
export const MAX_AMOUNT = 1_000_000_000;
