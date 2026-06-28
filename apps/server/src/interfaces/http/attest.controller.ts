import { Controller, Get, UseGuards } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { TokenGuard } from '../../common/auth/token.guard';
import { ChallengeService } from '../../common/attest/challenge.service';

/**
 * Émet un challenge App Attest à usage unique. Le client le signe (attestation/assertion Secure
 * Enclave) et le renvoie sur `/analyze` via l'en-tête `X-App-Attest-Challenge`. Reste protégé par
 * le jeton (Bearer) ; le challenge ne remplace pas le jeton, il s'y ajoute.
 */
@Controller('attest')
@UseGuards(TokenGuard)
export class AttestController {
  constructor(private readonly challenges: ChallengeService) {}

  @Get('challenge')
  @SkipThrottle({ global: true })
  challenge(): { challenge: string } {
    return { challenge: this.challenges.issue() };
  }
}
