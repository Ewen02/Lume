import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';

// La sonde de santé (Railway healthcheck) ne doit jamais être limitée.
// Avec des throttlers nommés, il faut désactiver chaque fenêtre explicitement.
@Controller('health')
@SkipThrottle({ global: true, analyze: true })
export class HealthController {
  @Get()
  health() {
    return { status: 'ok', service: 'lume-nutrition', ts: new Date().toISOString() };
  }
}
