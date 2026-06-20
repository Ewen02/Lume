import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { TokenGuard } from '../../common/auth/token.guard';
import { AnalyzeMealUseCase } from '../../application/use-cases/analyze-meal.usecase';
import { AnalyzeDto } from './dto/analyze.dto';

@Controller()
@UseGuards(TokenGuard)
export class AnalyzeController {
  constructor(private readonly analyze: AnalyzeMealUseCase) {}

  @Post('analyze')
  async run(@Body() dto: AnalyzeDto) {
    const meal = await this.analyze.execute(dto.image);
    return { items: meal.items, total: meal.total };
  }
}
