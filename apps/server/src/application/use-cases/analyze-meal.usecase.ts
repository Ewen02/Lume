import { VisionPort } from '../../domain/ports/vision.port';
import { NutritionResolver } from '../../domain/services/nutrition-resolver.service';

export class AnalyzeMealUseCase {
  constructor(private readonly vision: VisionPort, private readonly resolver: NutritionResolver) {}
  async execute(imageBase64: string) {
    const recognized = await this.vision.recognize(imageBase64);
    return this.resolver.resolve(recognized);
  }
}
