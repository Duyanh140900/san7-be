import { Module } from '@nestjs/common';
import { TeamDetailController } from './team-detail.controller.js';
import { TeamsController } from './teams.controller.js';
import { TeamsService } from './teams.service.js';

@Module({
  controllers: [TeamsController, TeamDetailController],
  providers: [TeamsService],
  exports: [TeamsService],
})
export class TeamsModule {}
