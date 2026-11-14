import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiProperty, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../common/auth.decorators.js';
import { PrismaService } from '../prisma/prisma.service.js';

class HealthDto {
  @ApiProperty({ example: 'ok' }) status: string;
  @ApiProperty() db: boolean;
}

@ApiTags('health')
@Public()
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiOkResponse({ type: HealthDto })
  async check(): Promise<HealthDto> {
    const db = await this.prisma.$queryRaw`SELECT 1`.then(
      () => true,
      () => false,
    );
    return { status: db ? 'ok' : 'degraded', db };
  }
}
