import { AnalyzedItem, AnalyzedMeal } from '../value-objects/analyzed-meal.vo';
import { RecognizedMeal } from '../ports/vision.port';
import { NutritionDbPort } from '../ports/nutrition-db.port';
import { Macros } from '../value-objects/macros.vo';

/**
 * Cœur métier : transforme un repas reconnu en repas chiffré.
 * Les macros sont TOUJOURS recalculées depuis la base (jamais issues du LLM).
 */
export class NutritionResolver {
  constructor(private readonly db: NutritionDbPort) {}

  async resolve(meal: RecognizedMeal): Promise<AnalyzedMeal> {
    const analyzed: AnalyzedItem[] = [];
    for (const item of meal.items) {
      // On cherche avec le nom anglais (queryName), mais on AFFICHE le nom français (item.name).
      const food = await this.db.resolve(item.queryName);
      if (food) {
        analyzed.push({
          name: item.name,
          grams: item.grams,
          macros: food.macrosFor(item.grams),
          per100g: food.per100g,
          source: food.source,
          matched: true,
          confidence: item.confidence,
        });
      } else {
        // Aliment introuvable : pas de macros, pas de source (l'UI affiche « non trouvé »).
        analyzed.push({
          name: item.name,
          grams: item.grams,
          macros: Macros.zero(),
          per100g: null,
          source: null,
          matched: false,
          confidence: item.confidence,
        });
      }
    }
    return new AnalyzedMeal(analyzed, meal.dish);
  }
}
