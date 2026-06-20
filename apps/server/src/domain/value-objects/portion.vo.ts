export class Portion {
  private constructor(readonly grams: number) {}
  static of(grams: number): Portion {
    if (grams <= 0 || !Number.isFinite(grams)) throw new Error('Portion invalide');
    return new Portion(Math.round(grams));
  }
}
