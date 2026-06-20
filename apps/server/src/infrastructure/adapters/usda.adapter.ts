import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';

/** Table de secours (macros pour 100 g) si aucune clé USDA n'est configurée. */
const FALLBACK: Food[] = [
  new Food('Poulet grillé', new Macros(165, 31, 0, 4), 'USDA'),
  new Food('Riz basmati cuit', new Macros(130, 3, 28, 0), 'USDA'),
  new Food('Brocoli', new Macros(34, 3, 7, 0), 'USDA'),
  new Food('Œuf entier', new Macros(143, 13, 1, 10), 'USDA'),
  new Food('Banane', new Macros(89, 1, 23, 0), 'USDA'),
  new Food('Skyr nature', new Macros(63, 11, 4, 0), 'USDA'),
  new Food('Amandes', new Macros(579, 21, 22, 50), 'USDA'),
];

@Injectable()
export class UsdaAdapter implements NutritionDbPort {
  constructor(private readonly config: ConfigService) {}
  private get key(): string {
    return this.config.get<string>('usdaApiKey') ?? '';
  }

  async resolve(name: string): Promise<Food | null> {
    const list = await this.search(name);
    return list[0] ?? null;
  }

  async search(query: string): Promise<Food[]> {
    const q = query.trim();
    if (!q) return this.key ? [] : FALLBACK;
    if (!this.key) return this.localSearch(q);
    try {
      const url = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
      url.searchParams.set('api_key', this.key);
      url.searchParams.set('query', q);
      url.searchParams.set('pageSize', '5');
      url.searchParams.set('dataType', 'Foundation,SR Legacy');
      const res = await fetch(url.toString());
      if (!res.ok) return this.localSearch(q);
      const json: any = await res.json();
      const foods: any[] = json?.foods ?? [];
      const mapped = foods.map((f) => this.toFood(f)).filter((f): f is Food => f !== null);
      return mapped.length ? mapped : this.localSearch(q);
    } catch {
      return this.localSearch(q);
    }
  }

  private localSearch(q: string): Food[] {
    const n = q.toLowerCase();
    return FALLBACK.filter(
      (f) => f.name.toLowerCase().includes(n) || n.includes(f.name.toLowerCase().split(' ')[0]),
    );
  }

  /** Mappe une entrée FDC vers Food (macros pour 100 g) via les numéros de nutriments. */
  private toFood(f: any): Food | null {
    const name: string | undefined = f?.description;
    if (!name) return null;
    const nutrients: any[] = f?.foodNutrients ?? [];
    const byNumber = (num: string): number => {
      const hit = nutrients.find(
        (x) => String(x?.nutrientNumber ?? x?.number) === num,
      );
      return hit ? Number(hit.value ?? hit.amount ?? 0) || 0 : 0;
    };
    const kcal = byNumber('208'); // Energy (kcal)
    const protein = byNumber('203'); // Protein
    const carbs = byNumber('205'); // Carbohydrate, by difference
    const fat = byNumber('204'); // Total lipid (fat)
    if (!kcal && !protein && !carbs && !fat) return null;
    return new Food(
      name,
      new Macros(Math.round(kcal), Math.round(protein), Math.round(carbs), Math.round(fat)),
      'USDA',
    );
  }
}
