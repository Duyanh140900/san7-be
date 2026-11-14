import { randomUUID } from 'node:crypto';
import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { toMoney } from '../common/money.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { FundType } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type {
  CreateFineRuleDto,
  CreateFundTxDto,
  FineRuleDto,
  FundSummaryDto,
  FundTxDto,
  FundTxPageDto,
  ListFundTxQuery,
} from './funds.dto.js';

const VN_OFFSET_MS = 7 * 3_600_000;

/** Kỳ YYYY-MM và mốc đầu tháng (UTC) theo giờ Việt Nam. */
export function vnMonth(now: Date): { period: string; start: Date } {
  const vn = new Date(now.getTime() + VN_OFFSET_MS);
  const y = vn.getUTCFullYear();
  const m = vn.getUTCMonth();
  return {
    period: `${y}-${String(m + 1).padStart(2, '0')}`,
    start: new Date(Date.UTC(y, m, 1) - VN_OFFSET_MS),
  };
}

/** Ảnh hưởng của một khoản lên số dư: thu +, chi −, phạt chỉ cộng khi đã nộp. */
export function balanceEffect(
  type: FundType,
  amount: bigint,
  paid: boolean,
): bigint {
  if (type === 'income') return amount;
  if (type === 'expense') return -amount;
  return paid ? amount : 0n;
}

const txInclude = {
  member: { select: { id: true, name: true, avatarUrl: true } },
  event: { select: { id: true, title: true, startAt: true } },
  createdBy: { select: { id: true, name: true, avatarUrl: true } },
} as const;

type TxRow = {
  id: string;
  type: FundType;
  amount: bigint;
  category: string;
  period: string | null;
  note: string | null;
  paid: boolean;
  createdAt: Date;
  member: { id: string; name: string; avatarUrl: string | null } | null;
  event: { id: string; title: string; startAt: Date } | null;
  createdBy: { id: string; name: string; avatarUrl: string | null };
};

function toTxDto(t: TxRow): FundTxDto {
  return {
    id: t.id,
    type: t.type,
    amount: toMoney(t.amount),
    category: t.category,
    member: t.member
      ? {
          userId: t.member.id,
          name: t.member.name,
          avatarUrl: t.member.avatarUrl,
        }
      : null,
    event: t.event,
    period: t.period,
    note: t.note,
    paid: t.paid,
    createdBy: {
      userId: t.createdBy.id,
      name: t.createdBy.name,
      avatarUrl: t.createdBy.avatarUrl,
    },
    createdAt: t.createdAt,
  };
}

@Injectable()
export class FundsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async summary(me: TeamMembership, now = new Date()): Promise<FundSummaryDto> {
    const { period, start } = vnMonth(now);
    const [team, monthSums, unpaidFines, recent, members, duesPaid] =
      await Promise.all([
        this.prisma.team.findUniqueOrThrow({
          where: { id: me.teamId },
          select: { fundBalance: true, monthlyDue: true },
        }),
        this.prisma.fundTransaction.groupBy({
          by: ['type'],
          where: {
            teamId: me.teamId,
            createdAt: { gte: start },
            OR: [
              { type: { in: ['income', 'expense'] } },
              { type: 'fine', paid: true },
            ],
          },
          _sum: { amount: true },
        }),
        this.prisma.fundTransaction.aggregate({
          where: { teamId: me.teamId, type: 'fine', paid: false },
          _sum: { amount: true },
        }),
        this.prisma.fundTransaction.findMany({
          where: { teamId: me.teamId },
          include: txInclude,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: 5,
        }),
        this.prisma.teamMember.findMany({
          where: { teamId: me.teamId, status: 'active' },
          include: {
            user: { select: { id: true, name: true, avatarUrl: true } },
          },
        }),
        this.prisma.fundTransaction.findMany({
          where: { teamId: me.teamId, period, type: 'income' },
          select: { memberId: true },
        }),
      ]);

    const sum = (t: FundType) =>
      monthSums.find((s) => s.type === t)?._sum.amount ?? 0n;
    const paidIds = new Set(duesPaid.map((d) => d.memberId));
    const unpaid = members
      .filter((m) => !paidIds.has(m.userId))
      .map((m) => ({
        userId: m.user.id,
        name: m.user.name,
        avatarUrl: m.user.avatarUrl,
      }));

    return {
      balance: toMoney(team.fundBalance),
      monthIncome: toMoney(sum('income') + sum('fine')),
      monthExpense: toMoney(sum('expense')),
      unpaidFines: toMoney(unpaidFines._sum.amount ?? 0n),
      dues:
        team.monthlyDue > 0n
          ? {
              period,
              amount: toMoney(team.monthlyDue),
              paidCount: members.length - unpaid.length,
              totalCount: members.length,
              unpaid,
            }
          : null,
      recent: recent.map(toTxDto),
    };
  }

  async list(me: TeamMembership, q: ListFundTxQuery): Promise<FundTxPageDto> {
    const take = q.limit ?? 20;
    const cursor = q.cursor ? decodeCursor(q.cursor) : null;
    const rows = await this.prisma.fundTransaction.findMany({
      where: {
        teamId: me.teamId,
        type: q.type,
        ...(cursor && {
          OR: [
            { createdAt: { lt: cursor.createdAt } },
            { createdAt: cursor.createdAt, id: { lt: cursor.id } },
          ],
        }),
      },
      include: txInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: take + 1,
    });
    const page = rows.slice(0, take);
    const last = page.at(-1);
    return {
      items: page.map(toTxDto),
      nextCursor: rows.length > take && last ? encodeCursor(last) : null,
    };
  }

  /** Thêm khoản. Thu nhiều người → nhiều dòng cùng batchId; số dư cập nhật trong cùng transaction. */
  async create(me: TeamMembership, dto: CreateFundTxDto): Promise<FundTxDto[]> {
    const memberIds = [...new Set(dto.memberIds ?? [])];
    this.checkMembersForType(dto.type, memberIds.length);
    if (dto.period && dto.type !== 'income') {
      throw this.bad(
        'period_only_income',
        'Kỳ quỹ tháng chỉ dùng cho khoản thu',
      );
    }
    if (dto.period && memberIds.length === 0) {
      throw this.bad('dues_need_members', 'Chọn người đóng quỹ tháng');
    }

    const amount = BigInt(dto.amount);
    const paid = dto.type === 'fine' ? (dto.paid ?? false) : true;
    const batchId = memberIds.length > 1 ? randomUUID() : null;

    const created = await this.prisma.$transaction(async (tx) => {
      if (memberIds.length) {
        const active = await tx.teamMember.count({
          where: {
            teamId: me.teamId,
            status: 'active',
            userId: { in: memberIds },
          },
        });
        if (active !== memberIds.length) {
          throw this.bad(
            'member_not_in_team',
            'Có người không phải thành viên đội',
          );
        }
      }
      if (dto.eventId) {
        const ok = await tx.event.count({
          where: { id: dto.eventId, teamId: me.teamId },
        });
        if (!ok) throw this.bad('event_not_in_team', 'Lịch không thuộc đội');
      }
      if (dto.period) {
        const dup = await tx.fundTransaction.findMany({
          where: {
            teamId: me.teamId,
            type: 'income',
            period: dto.period,
            memberId: { in: memberIds },
          },
          select: { member: { select: { name: true } } },
        });
        if (dup.length) {
          const names = dup
            .map((d) => d.member?.name)
            .filter(Boolean)
            .join(', ');
          throw new AppError(
            HttpStatus.CONFLICT,
            'dues_already_paid',
            `${names} đã đóng quỹ kỳ ${dto.period}`,
          );
        }
      }

      const targets: (string | null)[] = memberIds.length ? memberIds : [null];
      const ids: string[] = [];
      for (const memberId of targets) {
        const row = await tx.fundTransaction.create({
          data: {
            teamId: me.teamId,
            type: dto.type,
            amount,
            category: dto.category,
            memberId,
            eventId: dto.eventId ?? null,
            period: dto.period ?? null,
            batchId,
            note: dto.note ?? null,
            paid,
            createdById: me.userId,
          },
          select: { id: true },
        });
        ids.push(row.id);
      }
      const delta =
        balanceEffect(dto.type, amount, paid) * BigInt(targets.length);
      if (delta !== 0n) {
        await tx.team.update({
          where: { id: me.teamId },
          data: { fundBalance: { increment: delta } },
        });
      }
      return tx.fundTransaction.findMany({
        where: { id: { in: ids } },
        include: txInclude,
        orderBy: { createdAt: 'asc' },
      });
    });
    this.changed(me.teamId);
    return created.map(toTxDto);
  }

  /** Đánh dấu tiền phạt đã nộp → cộng vào quỹ. */
  async markFinePaid(me: TeamMembership, txId: string): Promise<FundTxDto> {
    const row = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.fundTransaction.updateMany({
        where: { id: txId, teamId: me.teamId, type: 'fine', paid: false },
        data: { paid: true },
      });
      if (count === 0) {
        throw new AppError(
          HttpStatus.NOT_FOUND,
          'unpaid_fine_not_found',
          'Không tìm thấy khoản phạt chưa nộp',
        );
      }
      const t = await tx.fundTransaction.findUniqueOrThrow({
        where: { id: txId },
        include: txInclude,
      });
      await tx.team.update({
        where: { id: me.teamId },
        data: { fundBalance: { increment: t.amount } },
      });
      return t;
    });
    this.changed(me.teamId);
    return toTxDto(row);
  }

  /** Xoá khoản ghi nhầm, hoàn lại ảnh hưởng lên số dư. */
  async remove(me: TeamMembership, txId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const t = await tx.fundTransaction.findFirst({
        where: { id: txId, teamId: me.teamId },
      });
      if (!t) {
        throw new AppError(
          HttpStatus.NOT_FOUND,
          'fund_tx_not_found',
          'Không tìm thấy khoản này',
        );
      }
      await tx.fundTransaction.delete({ where: { id: txId } });
      const delta = balanceEffect(t.type, t.amount, t.paid);
      if (delta !== 0n) {
        await tx.team.update({
          where: { id: me.teamId },
          data: { fundBalance: { decrement: delta } },
        });
      }
    });
    this.changed(me.teamId);
  }

  async fineRules(me: TeamMembership): Promise<FineRuleDto[]> {
    const rules = await this.prisma.fineRule.findMany({
      where: { teamId: me.teamId },
      orderBy: { amount: 'asc' },
    });
    return rules.map((r) => ({
      id: r.id,
      name: r.name,
      amount: toMoney(r.amount),
    }));
  }

  async createFineRule(
    me: TeamMembership,
    dto: CreateFineRuleDto,
  ): Promise<FineRuleDto> {
    const count = await this.prisma.fineRule.count({
      where: { teamId: me.teamId },
    });
    if (count >= 20) {
      throw this.bad('too_many_fine_rules', 'Mỗi đội tối đa 20 luật phạt');
    }
    const r = await this.prisma.fineRule.create({
      data: { teamId: me.teamId, name: dto.name, amount: BigInt(dto.amount) },
    });
    return { id: r.id, name: r.name, amount: toMoney(r.amount) };
  }

  async removeFineRule(me: TeamMembership, ruleId: string): Promise<void> {
    const { count } = await this.prisma.fineRule.deleteMany({
      where: { id: ruleId, teamId: me.teamId },
    });
    if (count === 0) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'fine_rule_not_found',
        'Không tìm thấy luật phạt',
      );
    }
  }

  private checkMembersForType(type: FundType, n: number) {
    if (type === 'expense' && n > 1) {
      throw this.bad('expense_one_payer', 'Khoản chi chỉ có một người chi');
    }
    if (type === 'fine' && n === 0) {
      throw this.bad('fine_needs_member', 'Chọn người bị phạt');
    }
  }

  private bad(code: string, message: string) {
    return new AppError(HttpStatus.BAD_REQUEST, code, message);
  }

  private changed(teamId: string) {
    this.realtime.toTeam(teamId, 'funds.changed', {});
  }
}

function encodeCursor(t: { createdAt: Date; id: string }): string {
  return Buffer.from(`${t.createdAt.toISOString()}|${t.id}`).toString(
    'base64url',
  );
}

function decodeCursor(c: string): { createdAt: Date; id: string } {
  const [iso, id] = Buffer.from(c, 'base64url').toString().split('|');
  const createdAt = new Date(iso ?? '');
  if (!id || Number.isNaN(createdAt.getTime())) {
    throw new AppError(
      HttpStatus.BAD_REQUEST,
      'invalid_cursor',
      'Con trỏ trang không hợp lệ',
    );
  }
  return { createdAt, id };
}
