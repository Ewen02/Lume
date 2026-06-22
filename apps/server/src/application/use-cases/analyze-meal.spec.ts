import { AnalyzeMealUseCase } from './analyze-meal.usecase';
import { NutritionResolver } from '../../domain/services/nutrition-resolver.service';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { VisionPort, RecognizedMeal } from '../../domain/ports/vision.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';
import { RecognizedItem } from '../../domain/value-objects/recognized-item.vo';

class FakeVision implements VisionPort {
  async recognize(): Promise<RecognizedMeal> {
    // Nom du plat + aliment (FR affiché, EN pour la recherche).
    return { dish: 'Poulet rôti', items: [new RecognizedItem('Poulet grillé', 150, 0.95, 'grilled chicken')] };
  }
}
class FakeDb implements NutritionDbPort {
  resolvedWith?: string;
  async resolve(name: string): Promise<Food | null> {
    this.resolvedWith = name;
    return new Food('Chicken, broilers or fryers', new Macros(165, 31, 0, 4), 'USDA');
  }
  async search(): Promise<Food[]> {
    return [];
  }
}

describe('AnalyzeMealUseCase', () => {
  it('relie vision → résolution déterministe', async () => {
    const db = new FakeDb();
    const usecase = new AnalyzeMealUseCase(new FakeVision(), new NutritionResolver(db));
    const meal = await usecase.execute('data:image/jpeg;base64,xxx');
    expect(meal.items).toHaveLength(1);
    const it = meal.items[0];
    // Affiche le nom FRANÇAIS du LLM, pas le nom anglais de la base USDA.
    expect(it.name).toBe('Poulet grillé');
    // …mais la recherche en base utilise le nom ANGLAIS (queryName).
    expect(db.resolvedWith).toBe('grilled chicken');
    expect(it.grams).toBe(150);
    // 165/100 * 150 = 248 kcal
    expect(it.macros.kcal).toBe(248);
    expect(it.matched).toBe(true);
  });
});
