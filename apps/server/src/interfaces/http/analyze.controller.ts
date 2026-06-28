import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { SkipThrottle, Throttle } from '@nestjs/throttler';
import { TokenGuard } from '../../common/auth/token.guard';
import { AnalyzeMealUseCase } from '../../application/use-cases/analyze-meal.usecase';
import { AnalyzeDto } from './dto/analyze.dto';

// `/analyze` déclenche un appel Claude (coûteux) → seule la fenêtre stricte « analyze »
// s'applique ; on neutralise la fenêtre « global » plus permissive.
@Controller()
@UseGuards(TokenGuard)
@SkipThrottle({ global: true })
export class AnalyzeController {
  constructor(private readonly analyze: AnalyzeMealUseCase) {}

  @Post('analyze')
  @Throttle({ analyze: {} })
  async run(@Body() dto: AnalyzeDto) {
    const meal = await this.analyze.execute(dto.image);
    // `degraded: true` → l'analyse est un repli de démo (vision indisponible). L'app doit
    // l'afficher comme tel et ne pas enregistrer ces macros en silence.
    return { dish: meal.dish, items: meal.items, total: meal.total, degraded: meal.degraded };
  }
}
