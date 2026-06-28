import { CachingNutritionDbAdapter } from './caching-nutrition-db.adapter';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';

/** Base sous-jacente espionnée : compte les appels réels (pour prouver le cache). */
class SpyDb implements NutritionDbPort {
  resolveCalls = 0;
  searchCalls = 0;
  constructor(private readonly food: Food | null) {}
  async resolve(_: string): Promise<Food | null> {
    this.resolveCalls++;
    return this.food;
  }
  async search(_: string): Promise<Food[]> {
    this.searchCalls++;
    return this.food ? [this.food] : [];
  }
}

describe('CachingNutritionDbAdapter', () => {
  const chicken = new Food('Grilled chicken', new Macros(165, 31, 0, 4), 'USDA');

  it('ne tape la base qu\'une fois pour deux resolve identiques (hit)', async () => {
    const spy = new SpyDb(chicken);
    const cache = new CachingNutritionDbAdapter(spy);
    const a = await cache.resolve('grilled chicken');
    const b = await cache.resolve('grilled chicken');
    expect(a).toBe(chicken);
    expect(b).toBe(chicken);
    expect(spy.resolveCalls).toBe(1); // 2e appel servi par le cache
  });

  it('normalise la clé (casse + espaces)', async () => {
    const spy = new SpyDb(chicken);
    const cache = new CachingNutritionDbAdapter(spy);
    await cache.resolve('  Grilled Chicken ');
    await cache.resolve('grilled chicken');
    expect(spy.resolveCalls).toBe(1);
  });

  it('mémorise aussi les « non trouvé » (null) pour ne pas re-payer', async () => {
    const spy = new SpyDb(null);
    const cache = new CachingNutritionDbAdapter(spy);
    expect(await cache.resolve('licorne')).toBeNull();
    expect(await cache.resolve('licorne')).toBeNull();
    expect(spy.resolveCalls).toBe(1); // le null est mis en cache
  });

  it('cache search séparément de resolve', async () => {
    const spy = new SpyDb(chicken);
    const cache = new CachingNutritionDbAdapter(spy);
    await cache.search('chicken');
    await cache.search('chicken');
    expect(spy.searchCalls).toBe(1);
    // resolve n'a pas été touché par le cache de search
    await cache.resolve('chicken');
    expect(spy.resolveCalls).toBe(1);
  });
});
