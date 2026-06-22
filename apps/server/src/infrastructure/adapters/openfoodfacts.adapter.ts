import { Injectable } from '@nestjs/common';
import { BarcodePort } from '../../domain/ports/barcode.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';

/** Lookup code-barres via l'API publique Open Food Facts (aucune clé requise). */
@Injectable()
export class OpenFoodFactsAdapter implements BarcodePort {
  async lookup(code: string): Promise<Food | null> {
    const c = (code ?? '').trim();
    if (!c) return null;
    try {
      const url = `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(c)}.json?fields=product_name,nutriments`;
      const res = await fetch(url, { headers: { 'User-Agent': 'Lume/0.1 (perso)' } });
      if (!res.ok) return null;
      const json: any = await res.json();
      if (json?.status !== 1 && !json?.product) return null;
      const p: any = json.product ?? {};
      const n: any = p.nutriments ?? {};
      const num = (k: string): number => Number(n[k] ?? 0) || 0;
      const kcal = num('energy-kcal_100g') || Math.round(num('energy_100g') / 4.184);
      const macros = new Macros(
        Math.round(kcal),
        Math.round(num('proteins_100g')),
        Math.round(num('carbohydrates_100g')),
        Math.round(num('fat_100g')),
      );
      const name: string = p.product_name || `Produit ${c}`;
      return new Food(name, macros, 'OpenFoodFacts', c);
    } catch {
      return null;
    }
  }

  /**
   * Recherche par nom dans Open Food Facts (fallback quand USDA ne trouve pas).
   * Renvoie le meilleur produit avec des macros pour 100 g, ou null.
   */
  async searchByName(query: string): Promise<Food | null> {
    const q = (query ?? '').trim();
    if (!q) return null;
    try {
      // API v2 (JSON fiable). On filtre par pertinence : le nom du produit doit
      // recouper la requête (OFF ne trie pas toujours par pertinence).
      const url = new URL('https://world.openfoodfacts.org/api/v2/search');
      url.searchParams.set('search_terms', q);
      url.searchParams.set('page_size', '15');
      url.searchParams.set('fields', 'product_name,nutriments');
      const res = await fetch(url.toString(), { headers: { 'User-Agent': 'Lume/0.1 (perso)' } });
      if (!res.ok) return null;
      const json: any = await res.json();
      const products: any[] = json?.products ?? [];
      const words = q.toLowerCase().split(/\s+/).filter((w) => w.length > 2);
      let best: Food | null = null;
      let bestScore = 0;
      for (const p of products) {
        const food = this.toFoodFromProduct(p);
        if (!food) continue;
        const name = food.name.toLowerCase();
        const score = words.filter((w) => name.includes(w)).length;
        if (score > bestScore) {
          bestScore = score;
          best = food;
        }
      }
      // Aucun mot de la requête retrouvé → on préfère ne rien renvoyer (évite un faux match).
      return bestScore > 0 ? best : null;
    } catch {
      return null;
    }
  }

  private toFoodFromProduct(p: any): Food | null {
    const name: string = p?.product_name ?? '';
    if (!name.trim()) return null;
    const n: any = p?.nutriments ?? {};
    const num = (k: string): number => Number(n[k] ?? 0) || 0;
    const kcal = num('energy-kcal_100g') || Math.round(num('energy_100g') / 4.184);
    if (!kcal) return null; // produit sans valeur énergétique → inexploitable
    const macros = new Macros(
      Math.round(kcal),
      Math.round(num('proteins_100g')),
      Math.round(num('carbohydrates_100g')),
      Math.round(num('fat_100g')),
    );
    return new Food(name, macros, 'OpenFoodFacts');
  }
}
