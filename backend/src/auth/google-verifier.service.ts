import { HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client } from 'google-auth-library';
import { AppError } from '../common/errors.js';
import type { Env } from '../common/env.js';

export interface GoogleProfile {
  sub: string;
  email: string;
  name: string;
  picture: string | null;
}

/** Kiểm tra Google ID token với audience là Web client ID. */
@Injectable()
export class GoogleVerifier {
  private readonly client = new OAuth2Client();
  private readonly audience: string;

  constructor(config: ConfigService<Env, true>) {
    this.audience = config.get('GOOGLE_WEB_CLIENT_ID');
  }

  async verify(idToken: string): Promise<GoogleProfile> {
    let payload;
    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: this.audience,
      });
      payload = ticket.getPayload();
    } catch {
      payload = undefined;
    }
    if (!payload?.sub || !payload.email) {
      throw new AppError(
        HttpStatus.UNAUTHORIZED,
        'google_token_invalid',
        'Token Google không hợp lệ',
      );
    }
    if (payload.email_verified === false) {
      throw new AppError(
        HttpStatus.UNAUTHORIZED,
        'google_email_unverified',
        'Email Google chưa xác minh',
      );
    }
    return {
      sub: payload.sub,
      email: payload.email,
      name: payload.name ?? payload.email.split('@')[0],
      picture: payload.picture ?? null,
    };
  }
}
