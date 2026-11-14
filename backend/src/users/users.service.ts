import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { MeDto, RegisterDeviceDto, UpdateMeDto } from './users.dto.js';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string): Promise<MeDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: { include: { team: true }, orderBy: { createdAt: 'asc' } },
      },
    });
    if (!user)
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'user_not_found',
        'Không tìm thấy tài khoản',
      );
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatarUrl,
      position: user.position,
      shirtNumber: user.shirtNumber,
      area: user.area,
      profileCompleted: user.position !== null,
      teams: user.memberships.map((m) => ({
        teamId: m.teamId,
        name: m.team.name,
        crestColor: m.team.crestColor,
        area: m.team.area,
        level: m.team.level,
        role: m.role,
        status: m.status,
      })),
    };
  }

  async updateMe(userId: string, dto: UpdateMeDto): Promise<MeDto> {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        name: dto.name?.trim(),
        position: dto.position,
        shirtNumber: dto.shirtNumber,
        area: dto.area?.trim(),
      },
    });
    return this.getMe(userId);
  }

  /** Lưu token FCM. Token đã thuộc người khác (đổi tài khoản trên cùng máy) thì chuyển sang người này. */
  async registerDevice(userId: string, dto: RegisterDeviceDto): Promise<void> {
    await this.prisma.device.upsert({
      where: { fcmToken: dto.fcmToken },
      create: { userId, fcmToken: dto.fcmToken, platform: dto.platform },
      update: { userId, platform: dto.platform },
    });
  }
}
