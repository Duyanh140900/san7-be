import { PrismaClient } from '../src/generated/prisma/client.js';

export const DEMO_EMAIL_DOMAIN = '@demo.san7.local';
export const DEMO_TEAM_PREFIX = '[DEMO]';

/** Xoá duy nhất dữ liệu demo; tuyệt đối không đụng tới sân OSM hoặc người dùng thật. */
export async function deleteDemoData(prisma: PrismaClient): Promise<void> {
  const demoUsers = await prisma.user.findMany({
    where: { email: { endsWith: DEMO_EMAIL_DOMAIN } },
    select: { id: true },
  });
  const demoUserIds = demoUsers.map((user) => user.id);

  await prisma.$transaction(async (tx) => {
    if (demoUserIds.length) {
      await tx.notification.deleteMany({ where: { userId: { in: demoUserIds } } });
      await tx.reaction.deleteMany({ where: { userId: { in: demoUserIds } } });
      await tx.comment.deleteMany({ where: { userId: { in: demoUserIds } } });
      await tx.postSchedule.deleteMany({ where: { authorId: { in: demoUserIds } } });
    }

    // Quan hệ còn lại của team (posts, bookings, matches, events, statistics, chat)
    // dùng ON DELETE CASCADE theo schema hiện hành.
    await tx.team.deleteMany({ where: { name: { startsWith: DEMO_TEAM_PREFIX } } });
    if (demoUserIds.length) {
      await tx.user.deleteMany({ where: { id: { in: demoUserIds } } });
    }
  });
}
