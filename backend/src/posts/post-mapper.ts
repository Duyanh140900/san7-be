import { toMoney } from '../common/money.js';
import { vnShort } from '../common/vn-time.js';
import type { Prisma } from '../generated/prisma/client.js';
import type { RequestStatus } from '../generated/prisma/enums.js';
import type { PostDto, TeamBriefDto } from './posts.dto.js';

/** Yêu cầu nhận kèo sống tối đa 2 giờ. */
export const REQUEST_TTL_MS = 2 * 3_600_000;

export const teamBriefSelect = {
  id: true,
  name: true,
  crestColor: true,
  area: true,
  level: true,
} as const satisfies Prisma.TeamSelect;

/** Điều kiện "yêu cầu còn chờ" (chưa trả lời và chưa quá hạn). */
export const livePending = (now: Date) =>
  ({
    status: 'pending',
    expiresAt: { gt: now },
  }) as const satisfies Prisma.MatchRequestWhereInput;

export const postInclude = (now: Date) =>
  ({
    team: { select: teamBriefSelect },
    _count: { select: { requests: { where: livePending(now) } } },
  }) as const satisfies Prisma.PostInclude;

export type PostRow = Prisma.PostGetPayload<{
  include: ReturnType<typeof postInclude>;
}>;

export function toPostDto(p: PostRow): PostDto {
  return {
    id: p.id,
    type: p.type,
    team: p.team satisfies TeamBriefDto,
    startAt: p.startAt,
    endAt: p.endAt,
    pitchName: p.pitchName,
    area: p.area,
    level: p.level,
    deal: p.deal,
    ratioWin: p.ratioWin,
    ratioLose: p.ratioLose,
    pitchPrice: p.pitchPrice === null ? null : toMoney(p.pitchPrice),
    positions: p.positions,
    playersNeeded: p.playersNeeded,
    body: p.body,
    status: p.status,
    createdAt: p.createdAt,
    requestCount: p._count.requests,
  };
}

/** Trạng thái thực: yêu cầu còn "pending" nhưng đã quá hạn thì coi là hết hạn. */
export function effectiveStatus(
  r: { status: RequestStatus; expiresAt: Date },
  now: Date,
): RequestStatus {
  return r.status === 'pending' && r.expiresAt <= now ? 'expired' : r.status;
}

/** Hạn của yêu cầu: 2 giờ sau khi gửi, nhưng không quá giờ bắt đầu trận. */
export function requestExpiry(now: Date, startAt: Date): Date {
  return new Date(Math.min(now.getTime() + REQUEST_TTL_MS, startAt.getTime()));
}

/** "Kèo T7 22/11 · 19:00 · Phúc La" cho nội dung thông báo. */
export function postLine(p: {
  startAt: Date;
  pitchName: string | null;
}): string {
  const when = `Kèo ${vnShort(p.startAt)}`;
  return p.pitchName ? `${when} · ${p.pitchName}` : when;
}
