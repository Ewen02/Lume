import { AnalyzedItem, AnalyzedMeal } from '../value-objects/analyzed-meal.vo';
import { RecognizedItem } from '../value-objects/recognized-item.vo';
import { NutritionDbPort } from '../ports/nutrition-db.port';
import { Macros } from '../value-objects/macros.vo';

/**
 * Cœur métier : transforme des items reconnus en repas chiffré.
 * Les macros sont TOUJOURS recalculées depuis la base (jamais issues du LLM).
 */
export class NutritionResolver {
  constructor(private readonly db: NutritionDbPort) {}

  async resolve(items: RecognizedItem[]): Promise<AnalyzedMeal> {
    const analyzed: AnalyzedItem[] = [];
    for (const item of items) {
      // On cherche avec le nom anglais (queryName), mais on AFFICHE le nom français (item.name).
      const food = await this.db.resolve(item.queryName);
      if (food) {
        analyzed.push({
          name: item.name,
          grams: item.grams,
          macros: food.macrosFor(item.grams),
          source: food.source,
          matched: true,
        });
      } else {
        analyzed.push({
          name: item.name,
          grams: item.grams,
          macros: Macros.zero(),
          source: 'USDA',
          matched: false,
        });
      }
    }
    return new AnalyzedMeal(analyzed);
  }
}
