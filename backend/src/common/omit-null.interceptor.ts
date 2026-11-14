import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { map, type Observable } from 'rxjs';

/**
 * Bỏ các trường có giá trị null khỏi JSON trả về.
 * Quy ước API: trường tuỳ chọn không có giá trị thì vắng mặt, không trả null
 * (client Dart sinh từ OpenAPI xử lý "vắng mặt" an toàn hơn "null").
 */
@Injectable()
export class OmitNullInterceptor implements NestInterceptor {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(map(omitNull));
  }
}

export function omitNull(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(omitNull);
  // Chỉ đi vào object thường; Date, Decimal, Buffer... giữ nguyên để toJSON của chúng chạy
  if (
    value === null ||
    typeof value !== 'object' ||
    Object.getPrototypeOf(value) !== Object.prototype
  ) {
    return value;
  }
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value)) {
    if (v !== null && v !== undefined) out[k] = omitNull(v);
  }
  return out;
}
