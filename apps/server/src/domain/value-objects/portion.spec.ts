import { Portion } from './portion.vo';

describe('Portion', () => {
  it('arrondit les grammes', () => {
    expect(Portion.of(149.6).grams).toBe(150);
  });
  it('rejette 0 et les valeurs négatives', () => {
    expect(() => Portion.of(0)).toThrow();
    expect(() => Portion.of(-5)).toThrow();
  });
  it('rejette les valeurs non finies', () => {
    expect(() => Portion.of(Number.NaN)).toThrow();
    expect(() => Portion.of(Number.POSITIVE_INFINITY)).toThrow();
  });
});
