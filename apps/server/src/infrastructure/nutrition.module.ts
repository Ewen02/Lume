import { Module } from '@nestjs/common';
import { VISION_PORT } from '../domain/ports/vision.port';
import { NUTRITION_DB_PORT, NutritionDbPort } from '../domain/ports/nutrition-db.port';
import { BARCODE_PORT } from '../domain/ports/barcode.port';
import { NutritionResolver } from '../domain/services/nutrition-resolver.service';
import { ClaudeVisionAdapter } from './adapters/claude-vision.adapter';
import { UsdaAdapter } from './adapters/usda.adapter';
import { OpenFoodFactsAdapter } from './adapters/openfoodfacts.adapter';
import { AnalyzeMealUseCase } from '../application/use-cases/analyze-meal.usecase';
import { SearchFoodsUseCase } from '../application/use-cases/search-foods.usecase';
import { LookupBarcodeUseCase } from '../application/use-cases/lookup-barcode.usecase';

@Module({
  providers: [
    { provide: VISION_PORT, useClass: ClaudeVisionAdapter },
    { provide: NUTRITION_DB_PORT, useClass: UsdaAdapter },
    { provide: BARCODE_PORT, useClass: OpenFoodFactsAdapter },
    {
      provide: NutritionResolver,
      useFactory: (db: NutritionDbPort) => new NutritionResolver(db),
      inject: [NUTRITION_DB_PORT],
    },
    {
      provide: AnalyzeMealUseCase,
      useFactory: (vision: any, resolver: NutritionResolver) => new AnalyzeMealUseCase(vision, resolver),
      inject: [VISION_PORT, NutritionResolver],
    },
    {
      provide: SearchFoodsUseCase,
      useFactory: (db: NutritionDbPort) => new SearchFoodsUseCase(db),
      inject: [NUTRITION_DB_PORT],
    },
    {
      provide: LookupBarcodeUseCase,
      useFactory: (bc: any) => new LookupBarcodeUseCase(bc),
      inject: [BARCODE_PORT],
    },
  ],
  exports: [AnalyzeMealUseCase, SearchFoodsUseCase, LookupBarcodeUseCase],
})
export class NutritionModule {}
