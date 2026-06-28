import { CachingVisionAdapter } from './caching-vision.adapter';
import { VisionPort, RecognizedMeal } from '../../domain/ports/vision.port';
import { RecognizedItem } from '../../domain/value-objects/recognized-item.vo';

/** Vision sous-jacente espionnée : compte les appels réels. */
class SpyVision implements VisionPort {
  calls = 0;
  constructor(private readonly meal: RecognizedMeal) {}
  async recognize(_: string): Promise<RecognizedMeal> {
    this.calls++;
    return this.meal;
  }
}

const realMeal: RecognizedMeal = {
  dish: 'Poke bowl',
  items: [new RecognizedItem('Saumon', 120, 0.9, 'raw salmon')],
};
const demoMeal: RecognizedMeal = { dish: 'Démo', degraded: true, items: [] };

describe('CachingVisionAdapter', () => {
  it('ne rappelle pas Claude pour une image identique (hit par hash)', async () => {
    const spy = new SpyVision(realMeal);
    const cache = new CachingVisionAdapter(spy);
    const a = await cache.recognize('data:image/jpeg;base64,AAAA');
    const b = await cache.recognize('data:image/jpeg;base64,AAAA');
    expect(a).toBe(realMeal);
    expect(b).toBe(realMeal);
    expect(spy.calls).toBe(1); // 2e appel servi par le cache
  });

  it('rappelle Claude pour une image différente (miss)', async () => {
    const spy = new SpyVision(realMeal);
    const cache = new CachingVisionAdapter(spy);
    await cache.recognize('image-1');
    await cache.recognize('image-2');
    expect(spy.calls).toBe(2);
  });

  it('ne met JAMAIS en cache un résultat dégradé (repli de démo)', async () => {
    const spy = new SpyVision(demoMeal);
    const cache = new CachingVisionAdapter(spy);
    await cache.recognize('même-image');
    await cache.recognize('même-image');
    // Le degraded n'est pas mémorisé → la vision est re-tentée à chaque fois.
    expect(spy.calls).toBe(2);
  });
});
