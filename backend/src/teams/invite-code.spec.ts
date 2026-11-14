import {
  generateInviteCode,
  INVITE_CODE_PATTERN,
  normalizeInviteCode,
} from './invite-code.js';

describe('invite code', () => {
  it('sinh mã đúng định dạng XXX-0000', () => {
    for (let i = 0; i < 200; i++) {
      expect(generateInviteCode()).toMatch(INVITE_CODE_PATTERN);
    }
  });

  it('chuẩn hoá mã người dùng gõ', () => {
    expect(normalizeInviteCode(' cg7 2486 ')).toBe('CG7-2486');
    expect(normalizeInviteCode('cg7-2486')).toBe('CG7-2486');
    expect(normalizeInviteCode('abc')).toBe('ABC');
  });
});
