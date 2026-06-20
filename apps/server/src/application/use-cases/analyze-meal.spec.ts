import { AnalyzeMealUseCase } from './analyze-meal.usecase';
import { NutritionResolver } from '../../domain/services/nutrition-resolver.service';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { VisionPort } from '../../domain/ports/vision.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';
import { RecognizedItem } from '../../domain/value-objects/recognized-item.vo';

class FakeVision implements VisionPort {
  async recognize(): Promise<RecognizedItem[]> {
    return [new RecognizedItem('poulet', 150, 0.95)];
  }
}
class FakeDb implements NutritionDbPort {
  async resolve(): Promise<Food | null> {
    return new Food('Poulet', new Macros(165, 31, 0, 4), 'USDA');
  }
  async search(): Promise<Food[]> { return []; }
}

describe('AnalyzeMealUseCase', () => {
  it('relie vision → résolution déterministe', async () => {
    const usecase = new AnalyzeMealUseCase(new FakeVision(), new NutritionResolver(new FakeDb()));
    const meal = await usecase.execute('data:image/jpeg;base64,xxx');
    expect(meal.items).toHaveLength(1);
    const it = meal.items[0];
    expect(it.name).toBe('Poulet');
    expect(it.grams).toBe(150);
    // 165/100 * 150 = 248 kcal
    expect(it.macros.kcal).toBe(248);
    expect(it.matched).toBe(true);
  });
});
