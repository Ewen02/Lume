import { createHash } from 'node:crypto';
import { VisionPort, RecognizedMeal } from '../../domain/ports/vision.port';
import { LruCache } from '../cache/lru-cache';

/**
 * Décorateur de cache pour la reconnaissance vision (même port `VisionPort`, le domaine l'ignore).
 * Clé = hash SHA-256 de l'image → une photo identique (ex. les 3 retries de l'app, ou un même cliché
 * resoumis) ne re-paie pas l'appel Claude Vision.
 *
 * ⚠️ On ne met JAMAIS en cache un résultat `degraded` (repli de démo : clé Anthropic absente ou appel
 * en échec). Sinon une panne transitoire empoisonnerait le cache et servirait un faux repas de démo
 * à la place d'une vraie analyse une fois la vision rétablie.
 */
export class CachingVisionAdapter implements VisionPort {
  private readonly cache: LruCache<RecognizedMeal>;

  constructor(
    private readonly inner: VisionPort,
    maxEntries = 500,
    ttlMs = 7 * 24 * 60 * 60 * 1000, // 7 j : une image donnée donne toujours la même reconnaissance
  ) {
    this.cache = new LruCache(maxEntries, ttlMs);
  }

  async recognize(imageBase64: string): Promise<RecognizedMeal> {
    const key = createHash('sha256').update(imageBase64).digest('hex');
    const cached = this.cache.get(key);
    if (cached) return cached;

    const result = await this.inner.recognize(imageBase64);
    // Ne cache que les vraies analyses — jamais un repli de démo.
    if (!result.degraded) this.cache.set(key, result);
    return result;
  }
}
