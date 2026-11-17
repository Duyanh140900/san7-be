import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { MediaService } from '../media/media.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type { MeDto, NotificationSettingsDto, RegisterDeviceDto, UpdateMeDto, UpdateNotificationSettingsDto } from './users.dto.js';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly realtime: RealtimeService,
  ) {}

  async getMe(userId: string): Promise<MeDto> {
    const [user, aggregate, matches, mvps] = await Promise.all([
      this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: { include: { team: true }, orderBy: { createdAt: 'asc' } },
      },
      }),
      this.prisma.matchPlayerStat.aggregate({ where: { userId }, _sum: { goals: true, assists: true }, _count: { _all: true } }),
      this.prisma.matchPlayerStat.count({ where: { userId, match: { status: 'finished' } } }),
      this.prisma.matchPlayerStat.count({ where: { userId, mvp: true } }),
    ]);
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
      stats: { goals: aggregate._sum.goals ?? 0, assists: aggregate._sum.assists ?? 0, mvps, matches },
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

  async getNotificationSettings(userId: string): Promise<NotificationSettingsDto> {
    const setting = await this.prisma.notificationSettings.upsert({
      where: { userId }, create: { userId }, update: {},
    });
    return { matchUpdates: setting.matchUpdates, teamActivity: setting.teamActivity, community: setting.community };
  }

  async updateNotificationSettings(userId: string, dto: UpdateNotificationSettingsDto): Promise<NotificationSettingsDto> {
    const setting = await this.prisma.notificationSettings.upsert({
      where: { userId },
      create: {
        userId,
        matchUpdates: dto.matchUpdates,
        teamActivity: dto.teamActivity,
        community: dto.community,
      },
      update: dto,
    });
    return { matchUpdates: setting.matchUpdates, teamActivity: setting.teamActivity, community: setting.community };
  }

  async updateMe(userId: string, dto: UpdateMeDto): Promise<MeDto> {
    const avatarUrl = dto.avatarKey ? await this.media.useAvatar(userId, dto.avatarKey) : undefined;
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        name: dto.name?.trim(),
        position: dto.position,
        shirtNumber: dto.shirtNumber,
        area: dto.area?.trim(),
        avatarUrl,
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

  /** Xoá dữ liệu nhận diện, rời đội và thu hồi toàn bộ phiên, nhưng giữ lịch sử đội/trận. */
  async removeAccount(userId: string): Promise<void> {
    const teamIds = await this.prisma.$transaction(async (tx) => {
      const captainTeams = await tx.teamMember.findMany({
        where: { userId, status: 'active', role: 'captain' },
        select: { teamId: true },
      });
      for (const { teamId } of captainTeams) {
        const activeCount = await tx.teamMember.count({
          where: { teamId, status: 'active' },
        });
        if (activeCount > 1) {
          throw new AppError(
            HttpStatus.CONFLICT,
            'captain_must_transfer',
            'Vui lòng chuyển quyền Đội trưởng hoặc giải tán đội trước khi xoá tài khoản',
          );
        }
      }

      const memberships = await tx.teamMember.findMany({
        where: { userId },
        select: { teamId: true },
      });
      await tx.postSchedule.updateMany({
        where: { authorId: userId, status: 'scheduled' },
        data: { status: 'cancelled' },
      });
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      await tx.device.deleteMany({ where: { userId } });
      await tx.notificationSettings.deleteMany({ where: { userId } });
      await tx.teamMember.deleteMany({ where: { userId } });
      await tx.user.update({
        where: { id: userId },
        data: {
          googleSub: `deleted-${userId}`,
          email: `deleted-${userId}@invalid.local`,
          name: 'Người dùng đã xoá',
          avatarUrl: null,
          position: null,
          shirtNumber: null,
          area: null,
        },
      });
      return memberships.map((membership) => membership.teamId);
    });
    for (const teamId of teamIds) this.realtime.evictFromTeam(userId, teamId);
  }
}
