import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { toMoney } from '../common/money.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import { vnShort } from '../common/vn-time.js';
import type { Prisma } from '../generated/prisma/client.js';
import {
  notifyTeamManagers,
  type NotificationRow,
} from '../notifications/notification-writer.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { teamBriefSelect } from '../posts/post-mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { exceedsScore, matchFees, resultStateOf } from './match-rules.js';
import type {
  MatchDetailDto,
  MatchPlayerDto,
  SetResultDto,
  SetStatsDto,
  SubmitReviewDto,
} from './matches.dto.js';

type Tx = Prisma.TransactionClient;

const matchInclude = {
  homeTeam: { select: { ...teamBriefSelect, createdById: true } },
  awayTeam: { select: { ...teamBriefSelect, createdById: true } },
} as const satisfies Prisma.MatchInclude;

type MatchRow = Prisma.MatchGetPayload<{ include: typeof matchInclude }>;

const MANAGERS = ['captain', 'vice'];

/** Mã khoá khoản tiền sân tự ghi cho một đội trong một trận. */
export const feeKey = (matchId: string, teamId: string) =>
  `match-fee:${matchId}:${teamId}`;

interface Effects {
  notes: NotificationRow[];
  /** các đội có quỹ vừa đổi (tiền sân) */
  fundTeams: string[];
}

@Injectable()
export class MatchesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeService,
  ) {}

  async detail(me: TeamMembership, matchId: string): Promise<MatchDetailDto> {
    return this.buildDetail(
      this.prisma,
      me,
      await this.findOwn(this.prisma, me.teamId, matchId),
    );
  }

  /** Nhập (hoặc sửa) tỉ số. Đội kia xác nhận; nhập đúng bằng tỉ số họ đã nhập thì coi như xác nhận. */
  async setResult(
    me: TeamMembership,
    matchId: string,
    dto: SetResultDto,
  ): Promise<MatchDetailDto> {
    const now = new Date();
    const fx = await this.prisma.$transaction(async (tx) => {
      await this.lock(tx, matchId);
      const m = await this.findOwn(tx, me.teamId, matchId);
      this.assertOpen(m, now);
      const agrees =
        m.reportedByTeamId !== null &&
        m.reportedByTeamId !== me.teamId &&
        m.homeScore === dto.homeScore &&
        m.awayScore === dto.awayScore;
      if (agrees) return this.confirmIn(tx, m, me.teamId, now);

      await tx.match.update({
        where: { id: m.id },
        data: {
          homeScore: dto.homeScore,
          awayScore: dto.awayScore,
          reportedByTeamId: me.teamId,
          reportedAt: now,
          confirmedAt: null,
        },
      });
      // Tỉ số nhỏ đi: số bàn/kiến tạo đã ghi vượt tỉ số mới thì xoá để khỏi mâu thuẫn
      await this.trimStats(tx, m.id, m.homeTeamId, dto.homeScore);
      await this.trimStats(tx, m.id, m.awayTeamId, dto.awayScore);

      const mine = m.homeTeamId === me.teamId ? m.homeTeam : m.awayTeam;
      const opp = m.homeTeamId === me.teamId ? m.awayTeam : m.homeTeam;
      const notes = await notifyTeamManagers(
        tx,
        [{ teamId: opp.id, payload: { matchId: m.id, teamId: opp.id } }],
        {
          type: 'match.result_reported',
          category: 'match',
          title: `${mine.name} nhập kết quả ${dto.homeScore} – ${dto.awayScore}`,
          body: 'Xác nhận hoặc sửa tỉ số',
        },
      );
      return { notes, fundTeams: [] };
    });
    return this.finish(me, matchId, fx);
  }

  /** Đội không nhập tỉ số xác nhận: chốt kết quả, trừ tiền sân vào quỹ hai đội. */
  async confirm(me: TeamMembership, matchId: string): Promise<MatchDetailDto> {
    const now = new Date();
    const fx = await this.prisma.$transaction(async (tx) => {
      await this.lock(tx, matchId);
      const m = await this.findOwn(tx, me.teamId, matchId);
      if (m.confirmedAt) return { notes: [], fundTeams: [] };
      this.assertOpen(m, now);
      if (m.reportedByTeamId === null) {
        throw this.conflict('no_result', 'Chưa có đội nào nhập tỉ số');
      }
      if (m.reportedByTeamId === me.teamId) {
        throw this.conflict(
          'own_report',
          'Tỉ số do đội bạn nhập, đang chờ đội kia xác nhận',
        );
      }
      return this.confirmIn(tx, m, me.teamId, now);
    });
    return this.finish(me, matchId, fx);
  }

  /** Số bàn, kiến tạo và cầu thủ hay nhất của đội mình (thay toàn bộ số liệu cũ của đội). */
  async setStats(
    me: TeamMembership,
    matchId: string,
    dto: SetStatsDto,
  ): Promise<MatchDetailDto> {
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await this.lock(tx, matchId);
      const m = await this.findOwn(tx, me.teamId, matchId);
      this.assertStarted(m, now);
      if (m.homeScore === null || m.awayScore === null) {
        throw this.conflict(
          'result_required',
          'Nhập tỉ số trước khi ghi số bàn',
        );
      }
      const myScore = m.homeTeamId === me.teamId ? m.homeScore : m.awayScore;

      const ids = dto.players.map((p) => p.userId);
      if (new Set(ids).size !== ids.length) {
        throw this.bad('duplicate_player', 'Một cầu thủ chỉ ghi một dòng');
      }
      if (
        exceedsScore(
          dto.players.map((p) => p.goals),
          myScore,
        ) ||
        exceedsScore(
          dto.players.map((p) => p.assists),
          myScore,
        )
      ) {
        throw this.bad(
          'stats_exceed_score',
          `Tổng bàn thắng và kiến tạo không được vượt tỉ số của đội (${myScore})`,
        );
      }
      const wanted = [
        ...new Set([...ids, ...(dto.mvpUserId ? [dto.mvpUserId] : [])]),
      ];
      const members = await tx.teamMember.count({
        where: { teamId: me.teamId, status: 'active', userId: { in: wanted } },
      });
      if (members !== wanted.length) {
        throw this.bad('not_member', 'Chỉ chọn được thành viên đang trong đội');
      }
      // Một người chỉ khoác áo một đội trong một trận (khoá chính matchId + userId)
      const other = await tx.matchPlayerStat.findFirst({
        where: {
          matchId: m.id,
          userId: { in: wanted },
          teamId: { not: me.teamId },
        },
        select: { userId: true },
      });
      if (other) {
        throw this.conflict(
          'player_in_other_team',
          'Cầu thủ này đã được đội còn lại ghi số liệu trong trận này',
        );
      }

      const rows = new Map<
        string,
        { goals: number; assists: number; mvp: boolean }
      >();
      for (const p of dto.players) {
        if (p.goals > 0 || p.assists > 0) {
          rows.set(p.userId, {
            goals: p.goals,
            assists: p.assists,
            mvp: false,
          });
        }
      }
      if (dto.mvpUserId) {
        const r = rows.get(dto.mvpUserId) ?? {
          goals: 0,
          assists: 0,
          mvp: false,
        };
        rows.set(dto.mvpUserId, { ...r, mvp: true });
      }
      await tx.matchPlayerStat.deleteMany({
        where: { matchId: m.id, teamId: me.teamId },
      });
      if (rows.size > 0) {
        await tx.matchPlayerStat.createMany({
          data: [...rows].map(([userId, r]) => ({
            matchId: m.id,
            teamId: me.teamId,
            userId,
            ...r,
          })),
        });
      }
    });
    return this.detail(me, matchId);
  }

  /** Đánh giá đội đối thủ (mỗi đội một đánh giá cho mỗi trận, sửa lại được). */
  async review(
    me: TeamMembership,
    matchId: string,
    dto: SubmitReviewDto,
  ): Promise<MatchDetailDto> {
    const now = new Date();
    const m = await this.findOwn(this.prisma, me.teamId, matchId);
    this.assertStarted(m, now);
    const toTeamId = m.homeTeamId === me.teamId ? m.awayTeamId : m.homeTeamId;
    const data = {
      reputation: dto.reputation,
      fairplay: dto.fairplay,
      tags: dto.tags,
      comment: dto.comment || null,
    };
    await this.prisma.teamReview.upsert({
      where: { matchId_fromTeamId: { matchId, fromTeamId: me.teamId } },
      create: {
        ...data,
        matchId,
        fromTeamId: me.teamId,
        toTeamId,
        createdById: me.userId,
      },
      update: { ...data, createdById: me.userId },
    });
    return this.detail(me, matchId);
  }

  // ---------- nội bộ ----------

  /** Chốt tỉ số: ghi trạng thái, trừ tiền sân từng đội, báo đội nhập tỉ số. */
  private async confirmIn(
    tx: Tx,
    m: MatchRow,
    confirmerTeamId: string,
    now: Date,
  ): Promise<Effects> {
    await tx.match.update({
      where: { id: m.id },
      data: { confirmedAt: now, status: 'finished' },
    });
    const fees = matchFees({
      pitchPrice: m.pitchPrice,
      ratioWin: m.ratioWin,
      ratioLose: m.ratioLose,
      homeScore: m.homeScore!,
      awayScore: m.awayScore!,
    });
    const fundTeams: string[] = [];
    if (fees) {
      const sides = [
        { team: m.homeTeam, opp: m.awayTeam, amount: fees.home },
        { team: m.awayTeam, opp: m.homeTeam, amount: fees.away },
      ];
      for (const s of sides) {
        if (s.amount <= 0n) continue;
        const event = await tx.event.findFirst({
          where: { matchId: m.id, teamId: s.team.id },
          select: { id: true },
        });
        await tx.fundTransaction.create({
          data: {
            teamId: s.team.id,
            type: 'expense',
            amount: s.amount,
            category: 'Tiền sân',
            eventId: event?.id ?? null,
            note: `Tiền sân trận vs ${s.opp.name} (tự động)`,
            paid: true,
            paidAt: now,
            createdById: s.team.createdById,
            autoKey: feeKey(m.id, s.team.id),
          },
        });
        await tx.team.update({
          where: { id: s.team.id },
          data: { fundBalance: { decrement: s.amount } },
        });
        fundTeams.push(s.team.id);
      }
    }
    const reporter = m.reportedByTeamId!;
    const confirmer =
      m.homeTeamId === confirmerTeamId ? m.homeTeam : m.awayTeam;
    const notes =
      reporter === confirmerTeamId
        ? []
        : await notifyTeamManagers(
            tx,
            [
              {
                teamId: reporter,
                payload: { matchId: m.id, teamId: reporter },
              },
            ],
            {
              type: 'match.result_confirmed',
              category: 'match',
              title: `${confirmer.name} đã xác nhận tỉ số ${m.homeScore} – ${m.awayScore}`,
              body: vnShort(m.startAt),
            },
          );
    return { notes, fundTeams };
  }

  /** Sau commit: realtime, thông báo, rồi trả chi tiết mới. */
  private async finish(
    me: TeamMembership,
    matchId: string,
    fx: Effects,
  ): Promise<MatchDetailDto> {
    const m = await this.findOwn(this.prisma, me.teamId, matchId);
    for (const id of [m.homeTeamId, m.awayTeamId]) {
      this.realtime.toTeam(id, 'events.changed', {});
    }
    for (const id of fx.fundTeams)
      this.realtime.toTeam(id, 'funds.changed', {});
    await this.notifications.dispatch(fx.notes);
    return this.buildDetail(this.prisma, me, m);
  }

  private async trimStats(
    tx: Tx,
    matchId: string,
    teamId: string,
    score: number,
  ) {
    const rows = await tx.matchPlayerStat.findMany({
      where: { matchId, teamId },
      select: { goals: true, assists: true },
    });
    const data: { goals?: number; assists?: number } = {};
    if (
      exceedsScore(
        rows.map((r) => r.goals),
        score,
      )
    )
      data.goals = 0;
    if (
      exceedsScore(
        rows.map((r) => r.assists),
        score,
      )
    )
      data.assists = 0;
    if (Object.keys(data).length) {
      await tx.matchPlayerStat.updateMany({ where: { matchId, teamId }, data });
    }
  }

  private async buildDetail(
    db: Pick<
      Prisma.TransactionClient,
      | 'teamMember'
      | 'matchPlayerStat'
      | 'teamReview'
      | 'fundTransaction'
      | 'event'
      | 'matchChatRead'
    >,
    me: TeamMembership,
    m: MatchRow,
  ): Promise<MatchDetailDto> {
    const now = new Date();
    const opponentId = m.homeTeamId === me.teamId ? m.awayTeamId : m.homeTeamId;
    const [members, stats, review, fee, event, captain, opponentRead] = await Promise.all([
      db.teamMember.findMany({
        where: { teamId: me.teamId, status: 'active' },
        include: { user: true },
      }),
      db.matchPlayerStat.findMany({
        where: { matchId: m.id, teamId: me.teamId },
      }),
      db.teamReview.findUnique({
        where: { matchId_fromTeamId: { matchId: m.id, fromTeamId: me.teamId } },
      }),
      db.fundTransaction.findUnique({
        where: { autoKey: feeKey(m.id, me.teamId) },
        select: { amount: true },
      }),
      db.event.findFirst({
        where: { matchId: m.id, teamId: me.teamId },
        select: { id: true },
      }),
      db.teamMember.findFirst({
        where: { teamId: opponentId, role: 'captain', status: 'active' },
        select: { user: { select: { name: true, phone: true } } },
      }),
      db.matchChatRead.findUnique({
        where: { matchId_teamId: { matchId: m.id, teamId: opponentId } },
        select: { lastReadAt: true },
      }),
    ]);
    const byUser = new Map(stats.map((s) => [s.userId, s]));
    const roster: MatchPlayerDto[] = members
      .map((mem) => {
        const s = byUser.get(mem.userId);
        return {
          userId: mem.userId,
          name: mem.user.name,
          avatarUrl: mem.user.avatarUrl,
          position: mem.user.position,
          goals: s?.goals ?? 0,
          assists: s?.assists ?? 0,
          mvp: s?.mvp ?? false,
        };
      })
      .sort((a, b) => a.name.localeCompare(b.name, 'vi'));
    const ended = m.endAt <= now;
    const manager = MANAGERS.includes(me.role);
    const cancelled = m.status === 'cancelled';
    return {
      id: m.id,
      startAt: m.startAt,
      endAt: m.endAt,
      location: m.location,
      status: m.status,
      homeTeam: toBrief(m.homeTeam),
      awayTeam: toBrief(m.awayTeam),
      myTeamId: me.teamId,
      opponentCaptainName: captain?.user.name ?? null,
      opponentCaptainPhone: m.confirmedAt ? (captain?.user.phone ?? null) : null,
      opponentLastReadAt: opponentRead?.lastReadAt ?? null,
      homeScore: m.homeScore,
      awayScore: m.awayScore,
      resultState: resultStateOf(m, me.teamId),
      ended,
      canReport: manager && ended && !cancelled && m.confirmedAt === null,
      canEdit: manager && ended && !cancelled,
      pitchPrice: m.pitchPrice === null ? null : toMoney(m.pitchPrice),
      ratioWin: m.ratioWin,
      ratioLose: m.ratioLose,
      myFee: fee ? toMoney(fee.amount) : null,
      roster,
      myReview: review
        ? {
            reputation: review.reputation,
            fairplay: review.fairplay,
            tags: review.tags,
            comment: review.comment,
          }
        : undefined,
      eventId: event?.id ?? null,
    };
  }

  private async lock(tx: Tx, matchId: string) {
    await tx.$queryRaw`SELECT 1 AS locked FROM matches WHERE id = ${matchId}::uuid FOR UPDATE`;
  }

  private async findOwn(
    db: Pick<Prisma.TransactionClient, 'match'>,
    teamId: string,
    matchId: string,
  ): Promise<MatchRow> {
    const m = await db.match.findFirst({
      where: {
        id: matchId,
        OR: [{ homeTeamId: teamId }, { awayTeamId: teamId }],
      },
      include: matchInclude,
    });
    if (!m) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'match_not_found',
        'Không tìm thấy trận đấu',
      );
    }
    return m;
  }

  /** Đã tới giờ kết thúc (nhập tỉ số, thống kê, đánh giá chỉ khi trận đã xong). */
  private assertStarted(m: MatchRow, now: Date) {
    if (m.status === 'cancelled') {
      throw this.conflict('match_cancelled', 'Trận này đã bị huỷ');
    }
    if (m.endAt > now) {
      throw this.conflict('match_not_finished', 'Trận chưa kết thúc');
    }
  }

  /** Còn sửa được tỉ số: trận đã xong và chưa chốt. */
  private assertOpen(m: MatchRow, now: Date) {
    this.assertStarted(m, now);
    if (m.confirmedAt) {
      throw this.conflict('result_confirmed', 'Tỉ số đã được hai đội xác nhận');
    }
  }

  private bad(code: string, message: string) {
    return new AppError(HttpStatus.BAD_REQUEST, code, message);
  }

  private conflict(code: string, message: string) {
    return new AppError(HttpStatus.CONFLICT, code, message);
  }
}

function toBrief(t: MatchRow['homeTeam']) {
  return {
    id: t.id,
    name: t.name,
    crestColor: t.crestColor,
    area: t.area,
    level: t.level,
  };
}
