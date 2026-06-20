import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';

export class SearchFoodsUseCase {
  constructor(private readonly db: NutritionDbPort) {}
  execute(query: string) { return this.db.search(query); }
}
