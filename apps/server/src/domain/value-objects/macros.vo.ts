/** Valeurs nutritionnelles immuables. */
export class Macros {
  constructor(
    readonly kcal: number,
    readonly protein: number,
    readonly carbs: number,
    readonly fat: number,
  ) {}

  static zero(): Macros { return new Macros(0, 0, 0, 0); }

  add(o: Macros): Macros {
    return new Macros(this.kcal + o.kcal, this.protein + o.protein, this.carbs + o.carbs, this.fat + o.fat);
  }

  /** Mise à l'échelle (ex. à partir de valeurs pour 100 g). */
  scale(factor: number): Macros {
    const r = (n: number) => Math.round(n * factor);
    return new Macros(r(this.kcal), r(this.protein), r(this.carbs), r(this.fat));
  }
}
