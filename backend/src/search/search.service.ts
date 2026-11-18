import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { SearchGroupDto, SearchResponseDto, TrendingSearchDto } from './search.dto.js';

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(query: string, type: 'all' | 'teams' | 'pitches' | 'posts' | 'players' = 'all'): Promise<SearchResponseDto> {
    const q = query.trim();
    const include = (kind: string) => type === 'all' || type === kind;
    const [teams, pitches, posts, players] = await Promise.all([
      include('teams') ? this.prisma.team.findMany({ where: { name: { contains: q, mode: 'insensitive' } }, select: { id: true, name: true, area: true, crestColor: true }, take: 10 }) : [],
      include('pitches') ? this.prisma.pitch.findMany({ where: { OR: [{ name: { contains: q, mode: 'insensitive' } }, { district: { contains: q, mode: 'insensitive' } }, { address: { contains: q, mode: 'insensitive' } }] }, select: { id: true, name: true, district: true }, take: 10 }) : [],
      include('posts') ? this.prisma.post.findMany({ where: { status: 'open', startAt: { gt: new Date() }, OR: [{ area: { contains: q, mode: 'insensitive' } }, { pitchName: { contains: q, mode: 'insensitive' } }, { team: { name: { contains: q, mode: 'insensitive' } } }] }, select: { id: true, area: true, type: true, team: { select: { name: true } } }, take: 10, orderBy: { createdAt: 'desc' } }) : [],
      include('players') ? this.prisma.user.findMany({ where: { name: { contains: q, mode: 'insensitive' } }, select: { id: true, name: true, area: true, avatarUrl: true }, take: 10 }) : [],
    ]);
    const groups: SearchGroupDto[] = [];
    if (include('teams')) groups.push({ kind: 'teams', count: teams.length, items: teams.map((x) => ({ id: x.id, kind: 'teams', title: x.name, subtitle: x.area, imageUrl: null })) });
    if (include('pitches')) groups.push({ kind: 'pitches', count: pitches.length, items: pitches.map((x) => ({ id: x.id, kind: 'pitches', title: x.name, subtitle: x.district, imageUrl: null })) });
    if (include('posts')) groups.push({ kind: 'posts', count: posts.length, items: posts.map((x) => ({ id: x.id, kind: 'posts', title: x.team.name, subtitle: `${x.type} · ${x.area}`, imageUrl: null })) });
    if (include('players')) groups.push({ kind: 'players', count: players.length, items: players.map((x) => ({ id: x.id, kind: 'players', title: x.name, subtitle: x.area, imageUrl: x.avatarUrl })) });
    return { groups };
  }

  trending(): TrendingSearchDto[] {
    return [
      { label: 'Kèo tối thứ 7', query: 'tối thứ 7' },
      { label: 'Sân có đèn gần tôi', query: 'sân có đèn' },
      { label: 'Tìm đối trình độ trung bình', query: 'trung bình' },
    ];
  }
}
