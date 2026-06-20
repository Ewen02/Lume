import { Macros } from './macros.vo';
import { Food } from './food.vo';

export interface AnalyzedItem {
  name: string;
  grams: number;
  macros: Macros;
  source: Food['source'];
  matched: boolean;
}

export class AnalyzedMeal {
  constructor(readonly items: AnalyzedItem[]) {}
  get total(): Macros {
    return this.items.reduce((acc, it) => acc.add(it.macros), Macros.zero());
  }
}
