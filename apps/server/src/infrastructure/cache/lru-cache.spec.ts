import { LruCache } from './lru-cache';

describe('LruCache', () => {
  it('rend une valeur mise en cache (hit)', () => {
    const c = new LruCache<number>(10, 1000);
    c.set('a', 1);
    expect(c.get('a')).toBe(1);
  });

  it('renvoie undefined pour une clé absente (miss)', () => {
    const c = new LruCache<number>(10, 1000);
    expect(c.get('x')).toBeUndefined();
  });

  it('expire une entrée après le TTL', () => {
    let t = 0;
    const c = new LruCache<number>(10, 1000, () => t);
    c.set('a', 1);
    t = 999;
    expect(c.get('a')).toBe(1); // pas encore expirée
    t = 1000;
    expect(c.get('a')).toBeUndefined(); // expirée (>=)
    expect(c.size).toBe(0); // purgée à la lecture
  });

  it('évince la moins récemment utilisée quand la capacité est dépassée', () => {
    const c = new LruCache<number>(2, 1000);
    c.set('a', 1);
    c.set('b', 2);
    c.get('a'); // 'a' devient la plus récente → 'b' est la plus ancienne
    c.set('c', 3); // dépasse la capacité (2) → évince 'b'
    expect(c.get('a')).toBe(1);
    expect(c.get('b')).toBeUndefined();
    expect(c.get('c')).toBe(3);
  });

  it('un set sur une clé existante rafraîchit sa position LRU', () => {
    const c = new LruCache<number>(2, 1000);
    c.set('a', 1);
    c.set('b', 2);
    c.set('a', 10); // 'a' redevient la plus récente
    c.set('c', 3); // évince 'b' (plus ancienne), pas 'a'
    expect(c.get('a')).toBe(10);
    expect(c.get('b')).toBeUndefined();
  });
});
