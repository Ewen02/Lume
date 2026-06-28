import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { Food } from '../../domain/value-objects/food.vo';
import { LruCache } from '../cache/lru-cache';

/**
 * Décorateur de cache pour la base nutritionnelle (pattern hexagonal : implémente le même port,
 * le domaine ne sait rien du cache). Mémorise `resolve`/`search` par nom normalisé → évite de
 * re-taper USDA/Open Food Facts pour un aliment déjà résolu. Le résultat est déterministe et stable,
 * donc on cache aussi les « non trouvé » (`null`) — une absence est une réponse utile à ne pas re-payer.
 */
export class CachingNutritionDbAdapter implements NutritionDbPort {
  private readonly resolveCache: LruCache<Food | null>;
  private readonly searchCache: LruCache<Food[]>;

  constructor(
    private readonly inner: NutritionDbPort,
    maxEntries = 2000,
    ttlMs = 24 * 60 * 60 * 1000, // 24 h : les macros d'un aliment ne bougent pas
  ) {
    this.resolveCache = new LruCache(maxEntries, ttlMs);
    this.searchCache = new LruCache(maxEntries, ttlMs);
  }

  /** Clé normalisée : insensible à la casse et aux espaces superflus. */
  private key(name: string): string {
    return name.trim().toLowerCase();
  }

  async resolve(name: string): Promise<Food | null> {
    const k = this.key(name);
    const cached = this.resolveCache.get(k);
    if (cached !== undefined) return cached; // undefined = absent du cache (≠ null = « non trouvé » mémorisé)
    const result = await this.inner.resolve(name);
    this.resolveCache.set(k, result);
    return result;
  }

  async search(query: string): Promise<Food[]> {
    const k = this.key(query);
    const cached = this.searchCache.get(k);
    if (cached !== undefined) return cached;
    const result = await this.inner.search(query);
    this.searchCache.set(k, result);
    return result;
  }
}
