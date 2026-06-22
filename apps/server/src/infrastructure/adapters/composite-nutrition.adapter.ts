import { Injectable } from '@nestjs/common';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { Food } from '../../domain/value-objects/food.vo';
import { UsdaAdapter } from './usda.adapter';
import { OpenFoodFactsAdapter } from './openfoodfacts.adapter';

/**
 * Base nutritionnelle composite : USDA d'abord (génériques fiables), puis Open Food Facts
 * en repli (couverture mondiale : fruits exotiques, plats ethniques, produits de marque).
 * La traduction FR→EN est faite côté app (framework Translation iOS), pas ici.
 *
 * Conforme à l'archi : implémente `NutritionDbPort`, le domaine n'en sait rien.
 */
@Injectable()
export class CompositeNutritionAdapter implements NutritionDbPort {
  constructor(
    private readonly usda: UsdaAdapter,
    private readonly off: OpenFoodFactsAdapter,
  ) {}

  async resolve(name: string): Promise<Food | null> {
    const fromUsda = await this.usda.resolve(name);
    if (fromUsda) return fromUsda;
    // USDA n'a pas trouvé → on tente Open Food Facts (couverture plus large).
    return this.off.searchByName(name);
  }

  async search(query: string): Promise<Food[]> {
    const usda = await this.usda.search(query);
    if (usda.length > 0) return usda;
    const off = await this.off.searchByName(query);
    return off ? [off] : [];
  }
}
