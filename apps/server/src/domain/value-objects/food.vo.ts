import { Macros } from './macros.vo';

/** Aliment canonique : macros exprimées POUR 100 g. */
export class Food {
  constructor(
    readonly name: string,
    readonly per100g: Macros,
    readonly source: 'USDA' | 'OpenFoodFacts',
    readonly barcode?: string,
  ) {}

  /** Macros déterministes pour une portion donnée. */
  macrosFor(grams: number): Macros {
    return this.per100g.scale(grams / 100);
  }
}
