import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { SearchQuery, SearchResponseDto, TrendingSearchDto } from './search.dto.js';
import { SearchService } from './search.service.js';

@ApiTags('search')
@ApiBearerAuth()
@Controller('search')
export class SearchController {
  constructor(private readonly search: SearchService) {}
  @Get()
  @ApiOkResponse({ type: SearchResponseDto })
  find(@Query() q: SearchQuery): Promise<SearchResponseDto> { return this.search.search(q.q, q.type); }
  @Get('trending')
  @ApiOkResponse({ type: [TrendingSearchDto] })
  trending(): TrendingSearchDto[] { return this.search.trending(); }
}
