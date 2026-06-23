import { FoodsController } from './foods.controller';
import { SearchFoodsUseCase } from '../../application/use-cases/search-foods.usecase';
import { LookupBarcodeUseCase } from '../../application/use-cases/lookup-barcode.usecase';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';

/** Capture l'argument reçu par le use-case pour vérifier le bornage. */
class SpySearch extends SearchFoodsUseCase {
  lastQuery?: string;
  constructor() {
    super({ resolve: async () => null, search: async () => [] });
  }
  override execute(q: string) {
    this.lastQuery = q;
    return Promise.resolve([new Food('Banane', new Macros(89, 1, 23, 0), 'USDA')]);
  }
}

class SpyBarcode extends LookupBarcodeUseCase {
  lastCode?: string;
  constructor() {
    super({ lookup: async () => null });
  }
  override execute(code: string) {
    this.lastCode = code;
    return Promise.resolve(null);
  }
}

describe('FoodsController', () => {
  it('enveloppe les résultats de recherche dans { results }', async () => {
    const search = new SpySearch();
    const ctrl = new FoodsController(search, new SpyBarcode());
    const res = await ctrl.search('banane');
    expect(res.results).toHaveLength(1);
    expect(res.results[0].name).toBe('Banane');
  });

  it('borne la longueur de la requête (≤ 120 caractères)', async () => {
    const search = new SpySearch();
    const ctrl = new FoodsController(search, new SpyBarcode());
    await ctrl.search('a'.repeat(500));
    expect(search.lastQuery!.length).toBe(120);
  });

  it('gère une requête absente sans planter', async () => {
    const search = new SpySearch();
    const ctrl = new FoodsController(search, new SpyBarcode());
    await ctrl.search(undefined as unknown as string);
    expect(search.lastQuery).toBe('');
  });

  it('borne la longueur du code-barres (≤ 32 caractères)', async () => {
    const bc = new SpyBarcode();
    const ctrl = new FoodsController(new SpySearch(), bc);
    await ctrl.barcode('9'.repeat(100));
    expect(bc.lastCode!.length).toBe(32);
  });

  it('enveloppe le produit dans { product }', async () => {
    const ctrl = new FoodsController(new SpySearch(), new SpyBarcode());
    const res = await ctrl.barcode('123');
    expect(res).toHaveProperty('product');
  });
});
