import { Module } from '@nestjs/common';
import { VISION_PORT, VisionPort } from '../domain/ports/vision.port';
import { NUTRITION_DB_PORT, NutritionDbPort } from '../domain/ports/nutrition-db.port';
import { BARCODE_PORT, BarcodePort } from '../domain/ports/barcode.port';
import { NutritionResolver } from '../domain/services/nutrition-resolver.service';
import { ClaudeVisionAdapter } from './adapters/claude-vision.adapter';
import { UsdaAdapter } from './adapters/usda.adapter';
import { OpenFoodFactsAdapter } from './adapters/openfoodfacts.adapter';
import { CompositeNutritionAdapter } from './adapters/composite-nutrition.adapter';
import { AnalyzeMealUseCase } from '../application/use-cases/analyze-meal.usecase';
import { SearchFoodsUseCase } from '../application/use-cases/search-foods.usecase';
import { LookupBarcodeUseCase } from '../application/use-cases/lookup-barcode.usecase';

@Module({
  providers: [
    UsdaAdapter,
    OpenFoodFactsAdapter,
    { provide: VISION_PORT, useClass: ClaudeVisionAdapter },
    // Base composite : USDA en premier, Open Food Facts en repli.
    {
      provide: NUTRITION_DB_PORT,
      useFactory: (usda: UsdaAdapter, off: OpenFoodFactsAdapter) =>
        new CompositeNutritionAdapter(usda, off),
      inject: [UsdaAdapter, OpenFoodFactsAdapter],
    },
    { provide: BARCODE_PORT, useClass: OpenFoodFactsAdapter },
    {
      provide: NutritionResolver,
      useFactory: (db: NutritionDbPort) => new NutritionResolver(db),
      inject: [NUTRITION_DB_PORT],
    },
    {
      provide: AnalyzeMealUseCase,
      useFactory: (vision: VisionPort, resolver: NutritionResolver) => new AnalyzeMealUseCase(vision, resolver),
      inject: [VISION_PORT, NutritionResolver],
    },
    {
      provide: SearchFoodsUseCase,
      useFactory: (db: NutritionDbPort) => new SearchFoodsUseCase(db),
      inject: [NUTRITION_DB_PORT],
    },
    {
      provide: LookupBarcodeUseCase,
      useFactory: (bc: BarcodePort) => new LookupBarcodeUseCase(bc),
      inject: [BARCODE_PORT],
    },
  ],
  exports: [AnalyzeMealUseCase, SearchFoodsUseCase, LookupBarcodeUseCase],
})
export class NutritionModule {}
