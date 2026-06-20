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
}
