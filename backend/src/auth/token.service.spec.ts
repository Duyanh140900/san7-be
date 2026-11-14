import { JwtService } from '@nestjs/jwt';
import type { ConfigService } from '@nestjs/config';
import type { Env } from '../common/env.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import {
  hashToken,
  REUSE_GRACE_MS,
  TokenService,
  ttlToSeconds,
} from './token.service.js';

function setup() {
  const tx = {
    refreshToken: {
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      create: vi.fn().mockResolvedValue({}),
    },
  };
  const prisma = {
    refreshToken: {
      create: vi.fn().mockResolvedValue({}),
      findUnique: vi.fn(),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
  };
  const config = {
    get: (k: keyof Env) =>
      ({ JWT_ACCESS_TTL: '15m', REFRESH_TOKEN_TTL_DAYS: 30 })[k as string],
  } as unknown as ConfigService<Env, true>;
  const jwt = new JwtService({ secret: 'test-secret' });
  const service = new TokenService(
    prisma as unknown as PrismaService,
    jwt,
    config,
  );
  return { service, prisma, tx, jwt };
}

describe('ttlToSeconds', () => {
  it('đổi đơn vị', () => {
    expect(ttlToSeconds('15m')).toBe(900);
    expect(ttlToSeconds('1h')).toBe(3600);
    expect(ttlToSeconds('30')).toBe(30);
    expect(() => ttlToSeconds('abc')).toThrow();
  });
});

describe('TokenService', () => {
  it('issue: lưu hash của refresh token, không lưu token gốc', async () => {
    const { service, prisma, jwt } = setup();
    const pair = await service.issue('u1');
    const saved = prisma.refreshToken.create.mock.calls[0][0].data;
    expect(saved.tokenHash).toBe(hashToken(pair.refreshToken));
    expect(saved.tokenHash).not.toBe(pair.refreshToken);
    expect(pair.accessTokenExpiresIn).toBe(900);
    const payload = await jwt.verifyAsync(pair.accessToken);
    expect(payload).toMatchObject({ sub: 'u1', typ: 'access' });
  });

  it('rotate: thu hồi token cũ và cấp token mới', async () => {
    const { service, prisma, tx } = setup();
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'rt1',
      userId: 'u1',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    const { userId, tokens } = await service.rotate('old-token-old-token-old');
    expect(userId).toBe('u1');
    expect(tx.refreshToken.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'rt1', revokedAt: null } }),
    );
    expect(tx.refreshToken.create.mock.calls[0][0].data.tokenHash).toBe(
      hashToken(tokens.refreshToken),
    );
  });

  it('rotate: token đã thu hồi từ lâu bị dùng lại → thu hồi mọi phiên của user', async () => {
    const { service, prisma } = setup();
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'rt1',
      userId: 'u1',
      revokedAt: new Date(Date.now() - REUSE_GRACE_MS - 1000),
      expiresAt: new Date(Date.now() + 60_000),
    });
    await expect(
      service.rotate('reused-token-reused-token'),
    ).rejects.toMatchObject({
      status: 401,
    });
    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 'u1', revokedAt: null } }),
    );
  });

  it('rotate: token vừa xoay vòng bị gửi lại (mất phản hồi) → 401 nhưng không thu hồi hết', async () => {
    const { service, prisma } = setup();
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'rt1',
      userId: 'u1',
      revokedAt: new Date(Date.now() - 2000),
      expiresAt: new Date(Date.now() + 60_000),
    });
    await expect(
      service.rotate('retry-token-retry-token'),
    ).rejects.toMatchObject({ status: 401 });
    expect(prisma.refreshToken.updateMany).not.toHaveBeenCalled();
  });

  it('rotate: token hết hạn hoặc không tồn tại → 401', async () => {
    const { service, prisma } = setup();
    prisma.refreshToken.findUnique.mockResolvedValueOnce(null);
    await expect(service.rotate('missing-token-missing')).rejects.toMatchObject(
      { status: 401 },
    );
    prisma.refreshToken.findUnique.mockResolvedValueOnce({
      id: 'rt1',
      userId: 'u1',
      revokedAt: null,
      expiresAt: new Date(Date.now() - 1),
    });
    await expect(service.rotate('expired-token-expired')).rejects.toMatchObject(
      { status: 401 },
    );
  });

  it('rotate: hai request song song, request thua bị từ chối', async () => {
    const { service, prisma, tx } = setup();
    prisma.refreshToken.findUnique.mockResolvedValue({
      id: 'rt1',
      userId: 'u1',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    tx.refreshToken.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.rotate('race-token-race-token')).rejects.toMatchObject(
      { status: 401 },
    );
    expect(tx.refreshToken.create).not.toHaveBeenCalled();
  });
});
