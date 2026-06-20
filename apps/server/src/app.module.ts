import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './config/configuration';
import { NutritionModule } from './infrastructure/nutrition.module';
import { TokenGuard } from './common/auth/token.guard';
import { AnalyzeController } from './interfaces/http/analyze.controller';
import { FoodsController } from './interfaces/http/foods.controller';
import { HealthController } from './interfaces/http/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    NutritionModule,
  ],
  controllers: [AnalyzeController, FoodsController, HealthController],
  providers: [TokenGuard],
})
export class AppModule {}
