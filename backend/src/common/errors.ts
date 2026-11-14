import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiProperty } from '@nestjs/swagger';
import type { Response } from 'express';

/** Định dạng lỗi thống nhất cho mọi endpoint. */
export class ErrorBody {
  @ApiProperty({ example: 400 })
  statusCode: number;

  @ApiProperty({
    example: 'validation_failed',
    description: 'Mã lỗi ổn định để app xử lý',
  })
  code: string;

  @ApiProperty({ example: 'Dữ liệu không hợp lệ' })
  message: string;

  @ApiProperty({ required: false, type: [String] })
  details?: string[];
}

/** Lỗi nghiệp vụ có mã ổn định. Dùng trong service thay cho HttpException trần. */
export class AppError extends HttpException {
  constructor(status: HttpStatus, code: string, message: string) {
    super({ code, message }, status);
  }
}

const DEFAULT_CODES: Record<number, string> = {
  400: 'bad_request',
  401: 'unauthorized',
  403: 'forbidden',
  404: 'not_found',
  409: 'conflict',
  410: 'gone',
  429: 'too_many_requests',
};

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Error');

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    const body = this.toBody(exception);
    if (body.statusCode >= 500) {
      this.logger.error(
        exception instanceof Error ? exception.stack : String(exception),
      );
    }
    res.status(body.statusCode).json(body);
  }

  private toBody(exception: unknown): ErrorBody {
    if (!(exception instanceof HttpException)) {
      return {
        statusCode: 500,
        code: 'internal_error',
        message: 'Có lỗi xảy ra, thử lại sau',
      };
    }
    const statusCode = exception.getStatus();
    const resp = exception.getResponse();
    const fallbackCode = DEFAULT_CODES[statusCode] ?? 'error';
    if (typeof resp === 'string') {
      return { statusCode, code: fallbackCode, message: resp };
    }
    const r = resp as { code?: string; message?: string | string[] };
    if (Array.isArray(r.message)) {
      // Lỗi từ ValidationPipe
      return {
        statusCode,
        code: 'validation_failed',
        message: 'Dữ liệu không hợp lệ',
        details: r.message,
      };
    }
    return {
      statusCode,
      code: r.code ?? fallbackCode,
      message: r.message ?? exception.message,
    };
  }
}
