import {
  createParamDecorator,
  ExecutionContext,
  SetMetadata,
} from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const IS_OPTIONAL_AUTH_KEY = 'isOptionalAuth';
/** Bỏ qua kiểm tra JWT cho endpoint này. */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
/** Cho phép đọc công khai; nếu có Bearer token hợp lệ thì gắn người xem vào request. */
export const OptionalAuth = () => SetMetadata(IS_OPTIONAL_AUTH_KEY, true);

export interface AuthUser {
  userId: string;
}

/** Lấy người dùng đã xác thực từ request. */
export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthUser | undefined => {
    const req = ctx.switchToHttp().getRequest<{ user?: AuthUser }>();
    return req.user;
  },
);
