import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { UsersService } from '../users/users.service.js';
import type { AuthResponseDto, TokenPairDto } from './auth.dto.js';
import { GoogleVerifier } from './google-verifier.service.js';
import { TokenService } from './token.service.js';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly google: GoogleVerifier,
    private readonly tokens: TokenService,
    private readonly users: UsersService,
  ) {}

  /** Đăng nhập Google: kiểm tra ID token → tạo/cập nhật user → cấp cặp token. */
  async loginWithGoogle(idToken: string): Promise<AuthResponseDto> {
    const profile = await this.google.verify(idToken);
    const user = await this.prisma.user.upsert({
      where: { googleSub: profile.sub },
      create: {
        googleSub: profile.sub,
        email: profile.email,
        name: profile.name,
        avatarUrl: profile.picture,
      },
      // Không ghi đè tên: người dùng có thể đã đổi tên hiển thị trong app
      update: { email: profile.email, avatarUrl: profile.picture },
    });
    const { accessToken, accessTokenExpiresIn, refreshToken } =
      await this.tokens.issue(user.id);
    return {
      accessToken,
      accessTokenExpiresIn,
      refreshToken,
      user: await this.users.getMe(user.id),
    };
  }

  async refresh(refreshToken: string): Promise<TokenPairDto> {
    const { tokens } = await this.tokens.rotate(refreshToken);
    return tokens;
  }

  logout(refreshToken: string): Promise<void> {
    return this.tokens.revoke(refreshToken);
  }
}
