/**
 * Cache mémoire LRU + TTL, sans dépendance. Process-local (suffisant pour Railway 1 instance ;
 * passer à Redis si multi-instance plus tard). Sert à écraser le coût des appels externes
 * (Claude Vision, USDA/OFF) sur des entrées identiques.
 *
 * - LRU : éviction de l'entrée la moins récemment utilisée quand `maxEntries` est atteint
 *   (l'ordre d'insertion d'une `Map` JS = ordre d'usage si on delete+set à chaque accès).
 * - TTL : une entrée expirée est traitée comme absente (lazy expiration au `get`).
 */
export class LruCache<V> {
  private readonly store = new Map<string, { value: V; expiresAt: number }>();

  constructor(
    private readonly maxEntries: number,
    private readonly ttlMs: number,
    /** Horloge injectable (tests). Par défaut `Date.now`. */
    private readonly now: () => number = () => Date.now(),
  ) {}

  get(key: string): V | undefined {
    const entry = this.store.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.store.delete(key); // expirée → purge à la lecture
      return undefined;
    }
    // Marque comme récemment utilisée (réinsertion en fin de Map).
    this.store.delete(key);
    this.store.set(key, entry);
    return entry.value;
  }

  set(key: string, value: V): void {
    // Réinsère pour fraîcheur LRU, puis évince le plus ancien si on dépasse la capacité.
    this.store.delete(key);
    this.store.set(key, { value, expiresAt: this.now() + this.ttlMs });
    if (this.store.size > this.maxEntries) {
      const oldest = this.store.keys().next().value;
      if (oldest !== undefined) this.store.delete(oldest);
    }
  }

  get size(): number {
    return this.store.size;
  }
}
