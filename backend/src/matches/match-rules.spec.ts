import { matchFeeTerms } from '../posts/requests.service.js';
import {
  exceedsScore,
  matchFees,
  monthRange,
  outcomeOf,
  resultStateOf,
  unbeatenStreak,
} from './match-rules.js';

const base = {
  pitchPrice: 600_000n,
  ratioWin: 40,
  ratioLose: 60,
};

describe('matchFees', () => {
  it('đội thắng trả theo tỷ lệ thắng, đội thua trả phần còn lại', () => {
    expect(matchFees({ ...base, homeScore: 3, awayScore: 2 })).toEqual({
      home: 240_000n,
      away: 360_000n,
    });
    expect(matchFees({ ...base, homeScore: 0, awayScore: 1 })).toEqual({
      home: 360_000n,
      away: 240_000n,
    });
  });

  it('hoà thì chia đôi, tổng luôn đúng bằng tiền sân (phần lẻ về đội khách)', () => {
    expect(matchFees({ ...base, homeScore: 1, awayScore: 1 })).toEqual({
      home: 300_000n,
      away: 300_000n,
    });
    const odd = matchFees({
      ...base,
      pitchPrice: 500_001n,
      homeScore: 2,
      awayScore: 2,
    })!;
    expect(odd.home + odd.away).toBe(500_001n);
    const split = matchFees({
      ...base,
      pitchPrice: 333_333n,
      ratioWin: 33,
      ratioLose: 67,
      homeScore: 1,
      awayScore: 0,
    })!;
    expect(split.home + split.away).toBe(333_333n);
  });

  it('thua trả sân (0–100): đội thua trả hết, thắng không mất gì', () => {
    expect(
      matchFees({
        ...base,
        ratioWin: 0,
        ratioLose: 100,
        homeScore: 2,
        awayScore: 1,
      }),
    ).toEqual({ home: 0n, away: 600_000n });
  });

  it('không chia khi thiếu giá hoặc tỷ lệ', () => {
    expect(
      matchFees({ ...base, pitchPrice: null, homeScore: 1, awayScore: 0 }),
    ).toBeNull();
    expect(
      matchFees({ ...base, pitchPrice: 0n, homeScore: 1, awayScore: 0 }),
    ).toBeNull();
    expect(
      matchFees({ ...base, ratioWin: null, homeScore: 1, awayScore: 0 }),
    ).toBeNull();
  });
});

describe('matchFeeTerms', () => {
  const post = {
    deal: 'split',
    pitchPrice: 600_000n,
    ratioWin: 40,
    ratioLose: 60,
  };

  it('đội nhận không đề xuất: giữ tỷ lệ của kèo', () => {
    expect(matchFeeTerms(post, { ratioWin: null, ratioLose: null })).toEqual({
      pitchPrice: 600_000n,
      ratioWin: 40,
      ratioLose: 60,
    });
  });

  it('tỷ lệ đề xuất đã được chấp nhận thay tỷ lệ của kèo', () => {
    expect(matchFeeTerms(post, { ratioWin: 50, ratioLose: 50 })).toMatchObject({
      ratioWin: 50,
      ratioLose: 50,
    });
  });

  it('kèo nước, giao hữu hoặc không có giá: không chia tiền sân', () => {
    const none = { pitchPrice: null, ratioWin: null, ratioLose: null };
    expect(
      matchFeeTerms(
        { ...post, deal: 'drinks' },
        { ratioWin: null, ratioLose: null },
      ),
    ).toEqual(none);
    expect(
      matchFeeTerms(
        { ...post, deal: 'friendly' },
        { ratioWin: null, ratioLose: null },
      ),
    ).toEqual(none);
    expect(
      matchFeeTerms(
        { ...post, pitchPrice: null },
        { ratioWin: null, ratioLose: null },
      ),
    ).toEqual(none);
  });
});

describe('quy tắc nhỏ', () => {
  it('outcomeOf', () => {
    expect(outcomeOf(3, 2)).toBe('W');
    expect(outcomeOf(1, 1)).toBe('D');
    expect(outcomeOf(0, 4)).toBe('L');
  });

  it('resultStateOf nhìn từ từng đội', () => {
    const none = { reportedByTeamId: null, confirmedAt: null };
    expect(resultStateOf(none, 'a')).toBe('none');
    const reported = { reportedByTeamId: 'a', confirmedAt: null };
    expect(resultStateOf(reported, 'a')).toBe('awaiting_opponent');
    expect(resultStateOf(reported, 'b')).toBe('awaiting_me');
    expect(
      resultStateOf({ reportedByTeamId: 'a', confirmedAt: new Date() }, 'b'),
    ).toBe('confirmed');
  });

  it('exceedsScore: tổng vượt tỉ số thì true', () => {
    expect(exceedsScore([2, 1], 3)).toBe(false);
    expect(exceedsScore([2, 2], 3)).toBe(true);
    expect(exceedsScore([], 0)).toBe(false);
  });

  it('unbeatenStreak dừng ở trận thua đầu tiên', () => {
    expect(unbeatenStreak(['W', 'D', 'W', 'L', 'W'])).toBe(3);
    expect(unbeatenStreak(['L', 'W'])).toBe(0);
    expect(unbeatenStreak([])).toBe(0);
  });

  it('monthRange theo giờ VN, từ chối định dạng sai', () => {
    const r = monthRange('2026-11')!;
    expect(r.from.toISOString()).toBe('2026-10-31T17:00:00.000Z');
    expect(r.to.toISOString()).toBe('2026-11-30T17:00:00.000Z');
    expect(monthRange('2026-12')!.to.toISOString()).toBe(
      '2026-12-31T17:00:00.000Z',
    );
    expect(monthRange('2026-13')).toBeNull();
    expect(monthRange('2026-1')).toBeNull();
  });
});
