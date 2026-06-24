import { Macros } from './macros.vo';
import { Food } from './food.vo';

export interface AnalyzedItem {
  name: string;
  grams: number;
  macros: Macros;
  /**
   * Macros exactes pour 100 g (base de référence). Permet au client de recalculer une
   * portion sans dériver d'une valeur déjà arrondie. `null` si l'aliment n'a pas été trouvé.
   */
  per100g: Macros | null;
  /** Base d'où viennent les macros, ou `null` si l'aliment n'a pas été trouvé (`matched: false`). */
  source: Food['source'] | null;
  matched: boolean;
  /** Confiance de reconnaissance du modèle de vision (0–1). */
  confidence: number;
}

export class AnalyzedMeal {
  constructor(
    readonly items: AnalyzedItem[],
    /** Nom du plat global (ex. "Burger"), ou null. */
    readonly dish: string | null = null,
  ) {}
  get total(): Macros {
    return this.items.reduce((acc, it) => acc.add(it.macros), Macros.zero());
  }
}
