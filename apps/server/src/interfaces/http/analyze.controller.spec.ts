import { AnalyzeController } from './analyze.controller';
import { AnalyzeMealUseCase } from '../../application/use-cases/analyze-meal.usecase';
import { AnalyzedMeal } from '../../domain/value-objects/analyzed-meal.vo';
import { Macros } from '../../domain/value-objects/macros.vo';

/** Use-case fake renvoyant un repas connu (on teste la sérialisation du controller). */
class FakeAnalyze extends AnalyzeMealUseCase {
  receivedImage?: string;
  constructor(private readonly meal: AnalyzedMeal) {
    // Dépendances factices : execute est override, elles ne servent pas.
    super({ recognize: async () => ({ dish: null, items: [] }) }, { resolve: async () => meal } as never);
  }
  override execute(image: string) {
    this.receivedImage = image;
    return Promise.resolve(this.meal);
  }
}

describe('AnalyzeController', () => {
  it('sérialise { dish, items, total } et calcule le total', async () => {
    const meal = new AnalyzedMeal(
      [
        { name: 'Poulet', grams: 150, macros: new Macros(248, 46, 0, 5), per100g: new Macros(165, 31, 0, 4), source: 'USDA', matched: true, confidence: 0.9 },
        { name: 'Inconnu', grams: 50, macros: Macros.zero(), per100g: null, source: null, matched: false, confidence: 0.4 },
      ],
      'Poulet riz',
    );
    const ctrl = new AnalyzeController(new FakeAnalyze(meal));

    const res = await ctrl.run({ image: 'data:image/jpeg;base64,xxx' });

    expect(res.dish).toBe('Poulet riz');
    expect(res.items).toHaveLength(2);
    // Le total agrège les macros (l'item non trouvé = 0).
    expect(res.total.kcal).toBe(248);
    expect(res.total.protein).toBe(46);
    // La base per100g exacte est exposée au client (recalcul de portion sans dérive).
    expect(res.items[0].per100g).toEqual(new Macros(165, 31, 0, 4));
    // L'item non trouvé garde source null + matched false + per100g null (cohérence du fix).
    expect(res.items[1].source).toBeNull();
    expect(res.items[1].matched).toBe(false);
    expect(res.items[1].per100g).toBeNull();
  });

  it('transmet l\'image au use-case', async () => {
    const fake = new FakeAnalyze(new AnalyzedMeal([], null));
    const ctrl = new AnalyzeController(fake);
    await ctrl.run({ image: 'img-data' });
    expect(fake.receivedImage).toBe('img-data');
  });
});
