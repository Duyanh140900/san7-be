/** Tạo dữ liệu demo quyết định được và có thể chạy lặp lại an toàn. */
import { fakerVI as faker } from '@faker-js/faker';
import { config } from 'dotenv';
import { PrismaPg } from '@prisma/adapter-pg';
import {
  MatchStatus,
  MemberStatus,
  Position,
  PostDeal,
  PostStatus,
  PostType,
  TeamLevel,
  TeamRole,
  PrismaClient,
} from '../src/generated/prisma/client.js';
import { deleteDemoData, DEMO_EMAIL_DOMAIN, DEMO_TEAM_PREFIX } from './demo-data.js';

config({ path: '../.env', quiet: true });

const TEAM_NAMES = [
  'Sao Đêm FC',
  'Gió Mùa FC',
  'Phố Cổ United',
  'Bình Minh FC',
  'Cỏ Nhân Tạo FC',
  'Bảy Rưỡi FC',
  'Hùng Vương FC',
  'Đồng Đội FC',
  'Đá Vui FC',
  'Sông Hồng FC',
  'Thành Đô FC',
  'Kèo Tối FC',
];
const LEVELS = Object.values(TeamLevel);
const POSITIONS = Object.values(Position);
const START_HOURS = [18, 19, 20, 21];

type DemoUser = { id: string; name: string; position: Position | null };
type DemoTeam = { id: string; name: string; memberIds: string[]; captainId: string };

function atVietnamHour(dayOffset: number, hour: number): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + dayOffset, hour - 7));
}

function randomTeamColor(): string {
  return faker.color.rgb({ prefix: '#' });
}

function nextInviteCode(index: number): string {
  return `DEMO${String(index + 1).padStart(4, '0')}`;
}

function demoPitchPrice(): bigint {
  return BigInt(faker.helpers.arrayElement([350_000, 400_000, 450_000, 500_000]));
}

async function createUsers(prisma: PrismaClient): Promise<DemoUser[]> {
  const users: DemoUser[] = [];
  for (let index = 0; index < 60; index += 1) {
    const position = faker.helpers.arrayElement(POSITIONS);
    const user = await prisma.user.upsert({
      where: { googleSub: `demo-user-${String(index + 1).padStart(3, '0')}` },
      update: {},
      create: {
        googleSub: `demo-user-${String(index + 1).padStart(3, '0')}`,
        email: `player-${String(index + 1).padStart(3, '0')}${DEMO_EMAIL_DOMAIN}`,
        name: faker.person.fullName(),
        position,
        shirtNumber: (index % 30) + 1,
        area: index % 2 ? 'Hà Nội' : 'TP. Hồ Chí Minh',
      },
      select: { id: true, name: true, position: true },
    });
    users.push(user);
  }
  return users;
}

async function createTeams(prisma: PrismaClient, users: DemoUser[]): Promise<DemoTeam[]> {
  const teams: DemoTeam[] = [];
  for (let index = 0; index < TEAM_NAMES.length; index += 1) {
    const members = users.slice(index * 5, index * 5 + 5);
    const captain = members[0];
    const team = await prisma.team.create({
      data: {
        name: `${DEMO_TEAM_PREFIX} ${TEAM_NAMES[index]}`,
        crestColor: randomTeamColor(),
        area: index % 2 ? 'Hà Nội' : 'TP. Hồ Chí Minh',
        level: LEVELS[index % LEVELS.length],
        inviteCode: nextInviteCode(index),
        monthlyDue: BigInt(100_000),
        createdById: captain.id,
        members: {
          create: members.map((member, memberIndex) => ({
            userId: member.id,
            role: memberIndex === 0 ? TeamRole.captain : TeamRole.member,
            status: MemberStatus.active,
            joinedAt: atVietnamHour(-45, 19),
          })),
        },
      },
      select: { id: true, name: true },
    });
    teams.push({ id: team.id, name: team.name, memberIds: members.map((member) => member.id), captainId: captain.id });
  }
  return teams;
}

async function createPosts(prisma: PrismaClient, teams: DemoTeam[], pitchIds: string[]): Promise<void> {
  for (let index = 0; index < 40; index += 1) {
    const team = teams[index % teams.length];
    const type = faker.helpers.arrayElement(Object.values(PostType));
    const startAt = atVietnamHour(1 + (index % 14), START_HOURS[index % START_HOURS.length]);
    const isCancelled = index % 11 === 0;
    const pitchId = pitchIds[index % pitchIds.length];
    const price = demoPitchPrice();
    await prisma.post.create({
      data: {
        teamId: team.id,
        authorId: team.captainId,
        type,
        startAt,
        endAt: new Date(startAt.getTime() + 90 * 60_000),
        pitchId,
        area: index % 2 ? 'Hà Nội' : 'TP. Hồ Chí Minh',
        level: LEVELS[index % LEVELS.length],
        deal: faker.helpers.arrayElement(Object.values(PostDeal)),
        ratioWin: 50,
        ratioLose: 50,
        pitchPrice: price,
        positions: type === PostType.recruit ? [POSITIONS[index % POSITIONS.length]] : [],
        playersNeeded: type === PostType.recruit ? 2 : null,
        body: isCancelled
          ? '[Đã hủy] Đội đổi lịch, hẹn đối thủ vào kèo khác.'
          : faker.helpers.arrayElement([
              'Đá giao lưu vui vẻ, đúng giờ và tôn trọng đối thủ.',
              'Cần đội cùng trình; sân OSM có giá ước lượng để tiện test.',
              'Ai chốt được xin nhắn tin trong app để thống nhất đội hình.',
            ]),
        status: isCancelled ? PostStatus.closed : PostStatus.open,
      },
    });
  }
}

async function createFinishedMatches(prisma: PrismaClient, teams: DemoTeam[], pitchNames: string[]): Promise<void> {
  for (let index = 0; index < 15; index += 1) {
    const home = teams[index % teams.length];
    const away = teams[(index + 5) % teams.length];
    const startAt = atVietnamHour(-1 - index, START_HOURS[index % START_HOURS.length]);
    const homeGoals = home.memberIds.map(() => faker.number.int({ min: 0, max: 2 }));
    const awayGoals = away.memberIds.map(() => faker.number.int({ min: 0, max: 2 }));
    const homeScore = homeGoals.reduce((total, value) => total + value, 0);
    const awayScore = awayGoals.reduce((total, value) => total + value, 0);
    const match = await prisma.match.create({
      data: {
        homeTeamId: home.id,
        awayTeamId: away.id,
        startAt,
        endAt: new Date(startAt.getTime() + 90 * 60_000),
        location: pitchNames[index % pitchNames.length],
        status: MatchStatus.finished,
        pitchPrice: demoPitchPrice(),
        ratioWin: 50,
        ratioLose: 50,
        homeScore,
        awayScore,
        reportedByTeamId: home.id,
        reportedAt: new Date(startAt.getTime() + 100 * 60_000),
        confirmedAt: new Date(startAt.getTime() + 120 * 60_000),
      },
    });

    const allPlayers = [...home.memberIds, ...away.memberIds];
    const mvpId = allPlayers.reduce((best, userId, playerIndex) => {
      const goals = playerIndex < homeGoals.length ? homeGoals[playerIndex] : awayGoals[playerIndex - homeGoals.length];
      const bestIndex = allPlayers.indexOf(best);
      const bestGoals = bestIndex < homeGoals.length ? homeGoals[bestIndex] : awayGoals[bestIndex - homeGoals.length];
      return goals > bestGoals ? userId : best;
    }, allPlayers[0]);
    await prisma.matchPlayerStat.createMany({
      data: allPlayers.map((userId, playerIndex) => ({
        matchId: match.id,
        userId,
        teamId: playerIndex < home.memberIds.length ? home.id : away.id,
        goals: playerIndex < homeGoals.length ? homeGoals[playerIndex] : awayGoals[playerIndex - homeGoals.length],
        assists: faker.number.int({ min: 0, max: 2 }),
        mvp: userId === mvpId,
      })),
    });
    await prisma.matchMessage.createMany({
      data: [
        { matchId: match.id, teamId: home.id, userId: home.captainId, body: 'Đội mình đến sân lúc 18:45 nhé.' },
        { matchId: match.id, teamId: away.id, userId: away.captainId, body: 'Ok, đội mình mang đủ áo bib.' },
        { matchId: match.id, teamId: home.id, userId: home.memberIds[1], body: 'Trận vui quá, hẹn tái đấu!' },
      ],
    });
  }
}

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Refusing to seed demo data when NODE_ENV=production');
  }
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

  faker.seed(20_261_117);
  const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
  });
  try {
    const pitches = await prisma.pitch.findMany({
      where: { source: 'osm' },
      select: { id: true, name: true },
      orderBy: { osmId: 'asc' },
    });
    if (!pitches.length) throw new Error('Chưa có sân OSM. Hãy chạy npm run import:osm trước.');

    await deleteDemoData(prisma);
    const users = await createUsers(prisma);
    const teams = await createTeams(prisma, users);
    await createPosts(prisma, teams, pitches.map((pitch) => pitch.id));
    await createFinishedMatches(prisma, teams, pitches.map((pitch) => pitch.name));

    console.log(`Đã seed demo: ${users.length} người, ${teams.length} đội, 40 kèo, 15 trận hoàn tất.`);
  } finally {
    await prisma.$disconnect();
  }
}

void main();
