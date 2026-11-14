import type { PrismaService } from '../prisma/prisma.service.js';
import type { UsersService } from '../users/users.service.js';
import { AuthService } from './auth.service.js';
import type { GoogleVerifier } from './google-verifier.service.js';
import type { TokenService } from './token.service.js';

describe('AuthService.loginWithGoogle', () => {
  it('upsert user theo google sub, không ghi đè tên đã đổi, rồi cấp token', async () => {
    const prisma = {
      user: { upsert: vi.fn().mockResolvedValue({ id: 'u1' }) },
    };
    const google = {
      verify: vi.fn().mockResolvedValue({
        sub: 'g-123',
        email: 'a@gmail.com',
        name: 'Anh A',
        picture: 'https://x/y.png',
      }),
    };
    const tokens = {
      issue: vi
        .fn()
        .mockResolvedValue({
          accessToken: 'at',
          accessTokenExpiresIn: 900,
          refreshToken: 'rt',
        }),
    };
    const me = { id: 'u1', profileCompleted: false, teams: [] };
    const users = { getMe: vi.fn().mockResolvedValue(me) };
    const service = new AuthService(
      prisma as unknown as PrismaService,
      google as unknown as GoogleVerifier,
      tokens as unknown as TokenService,
      users as unknown as UsersService,
    );

    const res = await service.loginWithGoogle('id-token');

    const arg = prisma.user.upsert.mock.calls[0][0];
    expect(arg.where).toEqual({ googleSub: 'g-123' });
    expect(arg.create).toMatchObject({ name: 'Anh A', email: 'a@gmail.com' });
    expect(arg.update).not.toHaveProperty('name');
    expect(tokens.issue).toHaveBeenCalledWith('u1');
    expect(res).toMatchObject({
      accessToken: 'at',
      refreshToken: 'rt',
      user: me,
    });
  });

  it('token Google sai → không tạo user', async () => {
    const prisma = { user: { upsert: vi.fn() } };
    const google = { verify: vi.fn().mockRejectedValue(new Error('bad')) };
    const service = new AuthService(
      prisma as unknown as PrismaService,
      google as unknown as GoogleVerifier,
      {} as TokenService,
      {} as UsersService,
    );
    await expect(service.loginWithGoogle('x')).rejects.toThrow();
    expect(prisma.user.upsert).not.toHaveBeenCalled();
  });
});
