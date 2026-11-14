import { createHash, randomBytes } from 'node:crypto';
import { HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AppError } from '../common/errors.js';
import type { Env } from '../common/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { TokenPairDto } from './auth.dto.js';

/** Khoảng cho phép dùng lại refresh token vừa xoay vòng mà không bị coi là lộ. */
export const REUSE_GRACE_MS = 30_000;

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Đổi '15m', '1h', '900' thành số giây. */
export function ttlToSeconds(ttl: string): number {
  const m = /^(\d+)\s*([smhd]?)$/.exec(ttl.trim());
  if (!m) throw new Error(`JWT_ACCESS_TTL không hợp lệ: ${ttl}`);
  const n = Number(m[1]);
  const unit = { '': 1, s: 1, m: 60, h: 3600, d: 86400 }[
    m[2] as '' | 's' | 'm' | 'h' | 'd'
  ];
  return n * unit;
}

/**
 * Access token: JWT ngắn hạn. Refresh token: chuỗi ngẫu nhiên, lưu hash, xoay vòng mỗi lần dùng.
 * Dùng lại refresh token đã thu hồi = dấu hiệu bị lộ → thu hồi toàn bộ phiên của người dùng.
 */
@Injectable()
export class TokenService {
  private readonly accessTtlSeconds: number;
  private readonly refreshTtlMs: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    config: ConfigService<Env, true>,
  ) {
    this.accessTtlSeconds = ttlToSeconds(config.get('JWT_ACCESS_TTL'));
    this.refreshTtlMs = config.get('REFRESH_TOKEN_TTL_DAYS') * 86_400_000;
  }

  async issue(userId: string): Promise<TokenPairDto> {
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + this.refreshTtlMs),
      },
    });
    return { ...(await this.signAccess(userId)), refreshToken };
  }

  async rotate(
    refreshToken: string,
  ): Promise<{ userId: string; tokens: TokenPairDto }> {
    const tokenHash = hashToken(refreshToken);
    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });
    const invalid = new AppError(
      HttpStatus.UNAUTHORIZED,
      'refresh_invalid',
      'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
    );
    if (!existing) throw invalid;
    if (existing.revokedAt) {
      // Vừa thu hồi trong vài giây: thường là app gửi lại vì mất phản hồi
      // hoặc hai request song song, không phải token bị lộ.
      const recent = Date.now() - existing.revokedAt.getTime() < REUSE_GRACE_MS;
      if (!recent) await this.revokeAll(existing.userId);
      throw invalid;
    }
    if (existing.expiresAt.getTime() <= Date.now()) throw invalid;

    const next = randomBytes(48).toString('base64url');
    await this.prisma.$transaction(async (tx) => {
      // Điều kiện revokedAt: null chống hai request refresh song song cùng dùng một token
      const { count } = await tx.refreshToken.updateMany({
        where: { id: existing.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (count === 0) throw invalid;
      await tx.refreshToken.create({
        data: {
          userId: existing.userId,
          tokenHash: hashToken(next),
          expiresAt: new Date(Date.now() + this.refreshTtlMs),
        },
      });
    });
    return {
      userId: existing.userId,
      tokens: {
        ...(await this.signAccess(existing.userId)),
        refreshToken: next,
      },
    };
  }

  async revoke(refreshToken: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: hashToken(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async revokeAll(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async signAccess(userId: string) {
    const accessToken = await this.jwt.signAsync(
      { sub: userId, typ: 'access' },
      { expiresIn: this.accessTtlSeconds },
    );
    return { accessToken, accessTokenExpiresIn: this.accessTtlSeconds };
  }
}
