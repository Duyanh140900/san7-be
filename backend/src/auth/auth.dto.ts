import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';
import { MeDto } from '../users/users.dto.js';

export class GoogleLoginDto {
  @ApiProperty({
    description:
      'ID token lấy từ google_sign_in (serverClientId = Web client ID)',
  })
  @IsString()
  @Length(20, 8192)
  idToken: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @Length(20, 512)
  refreshToken: string;
}

export class TokenPairDto {
  @ApiProperty() accessToken: string;
  @ApiProperty({ description: 'Thời hạn access token (giây)', type: 'integer' })
  accessTokenExpiresIn: number;
  @ApiProperty() refreshToken: string;
}

export class AuthResponseDto extends TokenPairDto {
  @ApiProperty({ type: MeDto }) user: MeDto;
}
