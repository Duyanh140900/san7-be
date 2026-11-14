import { INestApplication, ValidationPipe } from '@nestjs/common';
import {
  DocumentBuilder,
  SwaggerModule,
  type OpenAPIObject,
} from '@nestjs/swagger';
import { AllExceptionsFilter, ErrorBody } from './common/errors.js';

/** Cấu hình dùng chung cho server thật, test e2e và script xuất OpenAPI. */
export function setupApp(app: INestApplication): void {
  app.setGlobalPrefix('v1');
  app.enableShutdownHooks();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
}

export function buildOpenApi(app: INestApplication): OpenAPIObject {
  const config = new DocumentBuilder()
    .setTitle('Sân 7 API')
    .setDescription('API cho app Sân 7: cáp kèo, đặt sân, quản lý đội')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  return SwaggerModule.createDocument(app, config, {
    extraModels: [ErrorBody],
    operationIdFactory: (controllerKey, methodKey) =>
      `${controllerKey.replace(/Controller$/, '')}_${methodKey}`,
  });
}
