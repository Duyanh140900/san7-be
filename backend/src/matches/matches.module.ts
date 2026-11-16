import { Module } from '@nestjs/common';
import { HonorsController, HonorsService } from './honors.service.js';
import { MatchesController } from './matches.controller.js';
import { MatchesService } from './matches.service.js';
import {
  TeamProfileController,
  TeamProfileService,
} from './team-profile.service.js';

/** Sau trận: kết quả, thống kê, đánh giá, bảng vàng, hồ sơ đội (M4). */
@Module({
  controllers: [MatchesController, TeamProfileController, HonorsController],
  providers: [MatchesService, TeamProfileService, HonorsService],
})
export class MatchesModule {}
