import { Macros } from './macros.vo';

describe('Macros', () => {
  it('zero() est neutre', () => {
    const z = Macros.zero();
    expect([z.kcal, z.protein, z.carbs, z.fat]).toEqual([0, 0, 0, 0]);
  });

  it('add() additionne champ par champ', () => {
    const a = new Macros(100, 10, 20, 5);
    const b = new Macros(50, 4, 6, 2);
    const s = a.add(b);
    expect([s.kcal, s.protein, s.carbs, s.fat]).toEqual([150, 14, 26, 7]);
  });

  it('add() ne mute pas les opérandes', () => {
    const a = new Macros(100, 10, 20, 5);
    a.add(new Macros(1, 1, 1, 1));
    expect(a.kcal).toBe(100);
  });

  it('scale() met à l’échelle et arrondit', () => {
    const m = new Macros(130, 3, 28, 0).scale(2);
    expect([m.kcal, m.protein, m.carbs, m.fat]).toEqual([260, 6, 56, 0]);
  });

  it('scale(0.5) arrondit au plus proche', () => {
    const m = new Macros(165, 31, 0, 5).scale(0.5);
    expect([m.kcal, m.protein, m.carbs, m.fat]).toEqual([83, 16, 0, 3]);
  });
});
