import { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';
import type { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeGateway } from './realtime.gateway.js';
import { RealtimeService } from './realtime.service.js';

const jwt = new JwtService({ secret: 'test-secret' });

function setup(member: unknown, match: unknown = null) {
  const prisma = {
    teamMember: {
      findUnique: vi.fn().mockResolvedValue(member),
      findFirst: vi.fn().mockResolvedValue(member),
    },
    match: { findUnique: vi.fn().mockResolvedValue(match) },
  };
  const gateway = new RealtimeGateway(
    jwt,
    prisma as unknown as PrismaService,
    new RealtimeService(),
  );
  return { gateway, prisma };
}

function socket(token?: unknown) {
  return {
    handshake: { auth: { token } },
    data: {} as Record<string, unknown>,
    join: vi.fn(),
    leave: vi.fn(),
    emit: vi.fn(),
    disconnect: vi.fn(),
  };
}

describe('RealtimeGateway', () => {
  it('kết nối bằng access token hợp lệ → vào room user:{id}', async () => {
    const { gateway } = setup(null);
    const s = socket(await jwt.signAsync({ sub: 'u1', typ: 'access' }, { expiresIn: '1h' }));
    await gateway.handleConnection(s as unknown as Socket);
    expect(s.data.userId).toBe('u1');
    expect(s.join).toHaveBeenCalledWith('user:u1');
    expect(s.disconnect).not.toHaveBeenCalled();
  });

  it('token sai hoặc thiếu → báo auth:error và ngắt', async () => {
    const { gateway } = setup(null);
    for (const t of [undefined, 'garbage']) {
      const s = socket(t);
      await gateway.handleConnection(s as unknown as Socket);
      expect(s.emit).toHaveBeenCalledWith('auth:error', {
        code: 'token_expired',
      });
      expect(s.disconnect).toHaveBeenCalledWith(true);
    }
  });

  it('ngắt socket đúng lúc access token hết hạn', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-17T00:00:00.000Z'));
    const { gateway } = setup(null);
    const s = socket(await jwt.signAsync({ sub: 'u1', typ: 'access' }, { expiresIn: '1s' }));
    await gateway.handleConnection(s as unknown as Socket);
    await vi.advanceTimersByTimeAsync(1000);
    expect(s.emit).toHaveBeenCalledWith('auth:error', { code: 'token_expired' });
    expect(s.disconnect).toHaveBeenCalledWith(true);
    gateway.handleDisconnect(s as unknown as Socket);
    vi.useRealTimers();
  });

  it('team:join chỉ cho thành viên active', async () => {
    const active = setup({ status: 'active' });
    const s1 = socket();
    s1.data.userId = 'u1';
    await expect(
      active.gateway.joinTeam(s1 as unknown as Socket, { teamId: 't1' }),
    ).resolves.toEqual({ ok: true });
    expect(s1.join).toHaveBeenCalledWith('team:t1');

    for (const m of [null, { status: 'pending' }]) {
      const g = setup(m);
      const s = socket();
      s.data.userId = 'u1';
      await expect(
        g.gateway.joinTeam(s as unknown as Socket, { teamId: 't1' }),
      ).resolves.toEqual({ ok: false });
      expect(s.join).not.toHaveBeenCalled();
    }
  });

  it('team:join khi chưa xác thực → từ chối', async () => {
    const { gateway, prisma } = setup({ status: 'active' });
    const s = socket();
    await expect(
      gateway.joinTeam(s as unknown as Socket, { teamId: 't1' }),
    ).resolves.toEqual({ ok: false });
    expect(prisma.teamMember.findUnique).not.toHaveBeenCalled();
  });

  it('match:join chỉ cho thành viên active của một trong hai đội', async () => {
    const match = { homeTeamId: 'h', awayTeamId: 'a' };
    const ok = setup({ teamId: 'h' }, match);
    const s1 = socket();
    s1.data.userId = 'u1';
    await expect(
      ok.gateway.joinMatch(s1 as unknown as Socket, { matchId: 'm1' }),
    ).resolves.toEqual({ ok: true });
    expect(s1.join).toHaveBeenCalledWith('match:m1');
    expect(ok.prisma.teamMember.findFirst).toHaveBeenCalledWith({
      where: { userId: 'u1', status: 'active', teamId: { in: ['h', 'a'] } },
      select: { teamId: true },
    });

    // người ngoài hai đội
    const outsider = setup(null, match);
    const s2 = socket();
    s2.data.userId = 'u2';
    await expect(
      outsider.gateway.joinMatch(s2 as unknown as Socket, { matchId: 'm1' }),
    ).resolves.toEqual({ ok: false });
    expect(s2.join).not.toHaveBeenCalled();

    // trận không tồn tại / chưa xác thực
    const noMatch = setup({ teamId: 'h' }, null);
    const s3 = socket();
    s3.data.userId = 'u1';
    await expect(
      noMatch.gateway.joinMatch(s3 as unknown as Socket, { matchId: 'x' }),
    ).resolves.toEqual({ ok: false });
    await expect(
      ok.gateway.joinMatch(socket() as unknown as Socket, { matchId: 'm1' }),
    ).resolves.toEqual({ ok: false });
  });
});
