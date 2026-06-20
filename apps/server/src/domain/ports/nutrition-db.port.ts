import { Food } from '../value-objects/food.vo';

export const NUTRITION_DB_PORT = Symbol('NUTRITION_DB_PORT');

/** Base nutritionnelle de référence (macros pour 100 g). */
export interface NutritionDbPort {
  resolve(name: string): Promise<Food | null>;
  search(query: string): Promise<Food[]>;
}
