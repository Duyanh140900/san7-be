import { Module } from '@nestjs/common';
import { BookingsController } from '../bookings/bookings.controller.js';
import { BookingsService } from '../bookings/bookings.service.js';
import { PitchesController } from './pitches.controller.js';
import { PitchesService } from './pitches.service.js';

/** Sân và đặt sân (M3). */
@Module({
  controllers: [PitchesController, BookingsController],
  providers: [PitchesService, BookingsService],
})
export class PitchesModule {}
