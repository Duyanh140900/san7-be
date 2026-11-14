import { omitNull } from './omit-null.interceptor.js';

describe('omitNull', () => {
  it('bỏ trường null ở mọi cấp, giữ Date, mảng và giá trị falsy khác', () => {
    const d = new Date('2026-11-14T00:00:00Z');
    expect(
      omitNull({
        a: null,
        b: 0,
        c: false,
        d,
        e: [{ x: null, y: 1 }],
        f: { g: null, h: '' },
      }),
    ).toEqual({ b: 0, c: false, d, e: [{ y: 1 }], f: { h: '' } });
  });
});
