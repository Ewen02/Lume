import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration';
import { NutritionModule } from './infrastructure/nutrition.module';
import { TokenGuard } from './common/auth/token.guard';
import { ChallengeService } from './common/attest/challenge.service';
import { AppAttestGuard } from './common/attest/app-attest.guard';
import { AnalyzeController } from './interfaces/http/analyze.controller';
import { FoodsController } from './interfaces/http/foods.controller';
import { HealthController } from './interfaces/http/health.controller';
import { AttestController } from './interfaces/http/attest.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    // Limite de débit par IP. Deux fenêtres nommées : « global » (tous endpoints)
    // et « analyze » (stricte, car chaque appel /analyze déclenche Claude — coûteux).
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        { name: 'global', ttl: 60_000, limit: config.get<number>('rateLimitGlobalPerMin') ?? 60 },
        { name: 'analyze', ttl: 60_000, limit: config.get<number>('rateLimitAnalyzePerMin') ?? 10 },
      ],
    }),
    NutritionModule,
  ],
  controllers: [AnalyzeController, FoodsController, HealthController, AttestController],
  providers: [
    TokenGuard,
    // ChallengeService est un singleton (l'état des challenges émis vit dans l'instance).
    { provide: ChallengeService, useFactory: () => new ChallengeService() },
    AppAttestGuard,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
