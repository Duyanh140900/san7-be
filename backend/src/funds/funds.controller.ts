import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  CurrentMember,
  TeamScoped,
  TeamRoles,
  type TeamMembership,
} from '../common/team-member.guard.js';
import {
  CreateFineRuleDto,
  CreateFundTxDto,
  FineRuleDto,
  FundSummaryDto,
  FundTxDto,
  FinesDto,
  FinesQuery,
  FundTxPageDto,
  ListFundTxQuery,
} from './funds.dto.js';
import { FundsService } from './funds.service.js';

/** Mọi thành viên xem được quỹ; chỉ đội trưởng và thủ quỹ được ghi. */
@ApiTags('funds')
@TeamScoped()
@Controller('teams/:teamId/funds')
export class FundsController {
  constructor(private readonly funds: FundsService) {}

  @Get('summary')
  @ApiOkResponse({ type: FundSummaryDto })
  summary(@CurrentMember() me: TeamMembership): Promise<FundSummaryDto> {
    return this.funds.summary(me);
  }

  @Get('fines')
  @ApiOkResponse({ type: FinesDto })
  fines(
    @CurrentMember() me: TeamMembership,
    @Query() q: FinesQuery,
  ): Promise<FinesDto> {
    return this.funds.fines(me, q);
  }

  @Get('transactions')
  @ApiOkResponse({ type: FundTxPageDto })
  list(
    @CurrentMember() me: TeamMembership,
    @Query() q: ListFundTxQuery,
  ): Promise<FundTxPageDto> {
    return this.funds.list(me, q);
  }

  @Post('transactions')
  @TeamRoles('captain', 'treasurer')
  @ApiCreatedResponse({ type: [FundTxDto] })
  create(
    @CurrentMember() me: TeamMembership,
    @Body() dto: CreateFundTxDto,
  ): Promise<FundTxDto[]> {
    return this.funds.create(me, dto);
  }

  @Post('transactions/:txId/pay')
  @HttpCode(200)
  @TeamRoles('captain', 'treasurer')
  @ApiOkResponse({ type: FundTxDto })
  markFinePaid(
    @CurrentMember() me: TeamMembership,
    @Param('txId', ParseUUIDPipe) txId: string,
  ): Promise<FundTxDto> {
    return this.funds.markFinePaid(me, txId);
  }

  @Delete('transactions/:txId')
  @HttpCode(204)
  @TeamRoles('captain', 'treasurer')
  @ApiNoContentResponse()
  remove(
    @CurrentMember() me: TeamMembership,
    @Param('txId', ParseUUIDPipe) txId: string,
  ): Promise<void> {
    return this.funds.remove(me, txId);
  }

  @Get('fine-rules')
  @ApiOkResponse({ type: [FineRuleDto] })
  fineRules(@CurrentMember() me: TeamMembership): Promise<FineRuleDto[]> {
    return this.funds.fineRules(me);
  }

  @Post('fine-rules')
  @TeamRoles('captain', 'treasurer')
  @ApiCreatedResponse({ type: FineRuleDto })
  createFineRule(
    @CurrentMember() me: TeamMembership,
    @Body() dto: CreateFineRuleDto,
  ): Promise<FineRuleDto> {
    return this.funds.createFineRule(me, dto);
  }

  @Delete('fine-rules/:ruleId')
  @HttpCode(204)
  @TeamRoles('captain', 'treasurer')
  @ApiNoContentResponse()
  removeFineRule(
    @CurrentMember() me: TeamMembership,
    @Param('ruleId', ParseUUIDPipe) ruleId: string,
  ): Promise<void> {
    return this.funds.removeFineRule(me, ruleId);
  }
}
