import { NutritionResolver } from './nutrition-resolver.service';
import { NutritionDbPort } from '../ports/nutrition-db.port';
import { Food } from '../value-objects/food.vo';
import { Macros } from '../value-objects/macros.vo';
import { RecognizedItem } from '../value-objects/recognized-item.vo';

/** Fausse base : connaît "riz" uniquement. */
class FakeDb implements NutritionDbPort {
  async resolve(name: string): Promise<Food | null> {
    if (name.toLowerCase().includes('riz')) {
      return new Food('Riz basmati cuit', new Macros(130, 3, 28, 0), 'USDA');
    }
    return null;
  }
  async search(): Promise<Food[]> { return []; }
}

describe('NutritionResolver', () => {
  const resolver = new NutritionResolver(new FakeDb());
  const meal = (...items: RecognizedItem[]) => ({ dish: null, items });

  it('recalcule les macros depuis la base (jamais depuis l’entrée)', async () => {
    const result = await resolver.resolve(meal(new RecognizedItem('riz', 200, 0.9)));
    const it = result.items[0];
    expect(it.matched).toBe(true);
    expect(it.source).toBe('USDA');
    // 130/100 * 200 = 260 kcal, etc. (déterministe)
    expect([it.macros.kcal, it.macros.protein, it.macros.carbs, it.macros.fat]).toEqual([260, 6, 56, 0]);
    // La base per100g exacte est exposée (le client recalcule sans dériver d'un arrondi).
    expect(it.per100g).toEqual(new Macros(130, 3, 28, 0));
  });

  it('aliment non trouvé → macros à zéro + matched:false', async () => {
    const result = await resolver.resolve(meal(new RecognizedItem('licorne', 100, 0.4)));
    const it = result.items[0];
    expect(it.matched).toBe(false);
    expect([it.macros.kcal, it.macros.protein, it.macros.carbs, it.macros.fat]).toEqual([0, 0, 0, 0]);
    expect(it.per100g).toBeNull();
  });

  it('total ne plante pas avec un item non reconnu (régression du bug as any)', async () => {
    const result = await resolver.resolve(meal(
      new RecognizedItem('riz', 200, 0.9),
      new RecognizedItem('licorne', 100, 0.4),
    ));
    expect(() => result.total).not.toThrow();
    expect(result.total.kcal).toBe(260); // 260 + 0
  });

  it('propage le nom du plat (dish)', async () => {
    const result = await resolver.resolve({ dish: 'Burger', items: [new RecognizedItem('riz', 100, 0.9)] });
    expect(result.dish).toBe('Burger');
  });
});
