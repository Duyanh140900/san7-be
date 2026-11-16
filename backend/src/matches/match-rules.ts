/** Quy tắc thuần của trận đấu (không đụng DB) để dễ kiểm thử. */

export type Outcome = 'W' | 'D' | 'L';

/** Nhãn đánh giá đội đối thủ (khoá cố định, app đổi sang chữ). */
export const REVIEW_TAGS = [
  'on_time',
  'good_play',
  'friendly',
  'fair_pay',
  'full_squad',
] as const;
export type ReviewTag = (typeof REVIEW_TAGS)[number];

/** Kết quả của một đội: thắng / hoà / thua. */
export function outcomeOf(goalsFor: number, goalsAgainst: number): Outcome {
  if (goalsFor === goalsAgainst) return 'D';
  return goalsFor > goalsAgainst ? 'W' : 'L';
}

export interface FeeInput {
  pitchPrice: bigint | null;
  ratioWin: number | null;
  ratioLose: number | null;
  homeScore: number;
  awayScore: number;
}

/**
 * Tiền sân mỗi đội phải trả sau trận. Đội thắng trả `ratioWin`%, đội thua phần còn lại;
 * hoà thì chia đôi. Trả null khi kèo không chia tiền sân (kèo nước, giao hữu, không có giá).
 * Tổng hai phần luôn đúng bằng tiền sân (đội thua nhận phần lẻ).
 */
export function matchFees(m: FeeInput): { home: bigint; away: bigint } | null {
  if (
    m.pitchPrice === null ||
    m.pitchPrice <= 0n ||
    m.ratioWin === null ||
    m.ratioLose === null
  ) {
    return null;
  }
  const price = m.pitchPrice;
  if (m.homeScore === m.awayScore) {
    const home = price / 2n;
    return { home, away: price - home };
  }
  const winner = (price * BigInt(m.ratioWin)) / 100n;
  const loser = price - winner;
  return m.homeScore > m.awayScore
    ? { home: winner, away: loser }
    : { home: loser, away: winner };
}

/** Trạng thái kết quả của trận nhìn từ một đội. */
export type ResultState =
  'none' | 'awaiting_opponent' | 'awaiting_me' | 'confirmed';

export function resultStateOf(
  m: { reportedByTeamId: string | null; confirmedAt: Date | null },
  myTeamId: string,
): ResultState {
  if (m.confirmedAt) return 'confirmed';
  if (!m.reportedByTeamId) return 'none';
  return m.reportedByTeamId === myTeamId ? 'awaiting_opponent' : 'awaiting_me';
}

/**
 * Số bàn/kiến tạo đã ghi cho cầu thủ không được vượt tỉ số của đội.
 * Trả true nếu tổng vượt (cần xoá số liệu cũ khi tỉ số bị sửa nhỏ đi).
 */
export function exceedsScore(values: number[], score: number): boolean {
  return values.reduce((a, b) => a + b, 0) > score;
}

/** Chuỗi bất bại hiện tại từ trận gần nhất (mới nhất đứng đầu). */
export function unbeatenStreak(form: Outcome[]): number {
  let n = 0;
  for (const o of form) {
    if (o === 'L') break;
    n++;
  }
  return n;
}

/** "YYYY-MM" → khoảng [từ, đến) theo giờ VN dạng UTC. Null nếu sai định dạng. */
export function monthRange(period: string): { from: Date; to: Date } | null {
  const m = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(period);
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const OFFSET = 7 * 3_600_000;
  return {
    from: new Date(Date.UTC(y, mo - 1, 1) - OFFSET),
    to: new Date(Date.UTC(y, mo, 1) - OFFSET),
  };
}
