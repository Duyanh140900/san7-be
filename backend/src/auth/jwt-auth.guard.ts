import {
  CanActivate,
  ExecutionContext,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { IS_PUBLIC_KEY, type AuthUser } from '../common/auth.decorators.js';
import { AppError } from '../common/errors.js';

/** Guard toàn cục: mọi endpoint cần access token, trừ khi gắn @Public(). */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    // Guard toàn cục cũng chạy cho tin nhắn WebSocket; gateway tự xác thực lúc kết nối
    if (ctx.getType() !== 'http') return true;
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (isPublic) return true;

    const req = ctx.switchToHttp().getRequest<Request & { user?: AuthUser }>();
    const [scheme, token] = (req.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new AppError(
        HttpStatus.UNAUTHORIZED,
        'unauthorized',
        'Chưa đăng nhập',
      );
    }
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; typ?: string }>(
        token,
      );
      if (payload.typ !== 'access') throw new Error('wrong token type');
      req.user = { userId: payload.sub };
      return true;
    } catch {
      throw new AppError(
        HttpStatus.UNAUTHORIZED,
        'token_expired',
        'Phiên đăng nhập đã hết hạn',
      );
    }
  }
}
