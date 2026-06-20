import { Food } from './food.vo';
import { Macros } from './macros.vo';

describe('Food', () => {
  const poulet = new Food('Poulet', new Macros(165, 31, 0, 4), 'USDA');

  it('macrosFor(100) renvoie les valeurs pour 100 g', () => {
    const m = poulet.macrosFor(100);
    expect([m.kcal, m.protein, m.carbs, m.fat]).toEqual([165, 31, 0, 4]);
  });

  it('macrosFor(150) met à l’échelle déterministe', () => {
    const m = poulet.macrosFor(150);
    expect([m.kcal, m.protein, m.carbs, m.fat]).toEqual([248, 47, 0, 6]);
  });

  it('macrosFor(0) renvoie zéro', () => {
    const m = poulet.macrosFor(0);
    expect([m.kcal, m.protein, m.carbs, m.fat]).toEqual([0, 0, 0, 0]);
  });
});
