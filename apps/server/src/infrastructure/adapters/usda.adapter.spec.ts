import { ConfigService } from '@nestjs/config';
import { UsdaAdapter } from './usda.adapter';

function fakeConfig(values: Record<string, unknown>): ConfigService {
  return { get: (k: string) => values[k] } as unknown as ConfigService;
}

function usdaResponse(foods: unknown[]): Response {
  return { ok: true, status: 200, json: async () => ({ foods }) } as unknown as Response;
}

describe('UsdaAdapter', () => {
  afterEach(() => jest.restoreAllMocks());

  describe('sans clé API', () => {
    const adapter = () => new UsdaAdapter(fakeConfig({ usdaApiKey: '' }));

    it('cherche dans la table locale (jamais d\'appel réseau)', async () => {
      const spy = jest.spyOn(global, 'fetch');
      const res = await adapter().search('poulet');
      expect(spy).not.toHaveBeenCalled();
      expect(res.some((f) => f.name.toLowerCase().includes('poulet'))).toBe(true);
    });

    it('resolve renvoie le 1er aliment local correspondant', async () => {
      const food = await adapter().resolve('banane');
      expect(food?.name.toLowerCase()).toContain('banane');
      expect(food?.source).toBe('USDA');
    });
  });

  describe('avec clé API', () => {
    const adapter = () => new UsdaAdapter(fakeConfig({ usdaApiKey: 'k', nutritionTimeoutMs: 1000 }));

    it('mappe les nutriments USDA (convention nutrientId) en macros pour 100 g', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        usdaResponse([
          {
            description: 'Chicken breast, grilled',
            dataType: 'Foundation',
            foodNutrients: [
              { nutrientId: 1008, value: 165 }, // énergie
              { nutrientId: 1003, value: 31 }, // protéine
              { nutrientId: 1005, value: 0 }, // glucides
              { nutrientId: 1004, value: 4 }, // lipides
            ],
          },
        ]),
      );
      const list = await adapter().search('grilled chicken');
      expect(list).toHaveLength(1);
      expect(list[0].per100g.kcal).toBe(165);
      expect(list[0].per100g.protein).toBe(31);
      expect(list[0].per100g.fat).toBe(4);
    });

    it('accepte aussi la convention nutrientNumber (chaînes "208"…)', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        usdaResponse([
          {
            description: 'Rice, white, cooked',
            dataType: 'SR Legacy',
            foodNutrients: [
              { nutrientNumber: '208', value: 130 },
              { nutrientNumber: '203', value: 3 },
              { nutrientNumber: '205', value: 28 },
              { nutrientNumber: '204', value: 0 },
            ],
          },
        ]),
      );
      const list = await adapter().search('white rice');
      expect(list[0].per100g.kcal).toBe(130);
      expect(list[0].per100g.carbs).toBe(28);
    });

    it('rejette une entrée sans énergie (inexploitable)', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        usdaResponse([{ description: 'Eau', dataType: 'Foundation', foodNutrients: [] }]),
      );
      // Aucune entrée valide → repli local (peut être vide selon la requête).
      const list = await adapter().search('zzzznoexist');
      expect(list.every((f) => f.per100g.kcal > 0)).toBe(true);
    });

    it('replie sur la table locale si HTTP en erreur', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue({ ok: false, status: 503 } as Response);
      const list = await adapter().search('poulet');
      expect(list.some((f) => f.name.toLowerCase().includes('poulet'))).toBe(true);
    });

    it('replie sur la table locale en cas d\'exception', async () => {
      jest.spyOn(global, 'fetch').mockRejectedValue(new Error('boom'));
      const list = await adapter().search('riz');
      expect(Array.isArray(list)).toBe(true);
    });

    it('appelle FDC en POST avec dataType en tableau dans le corps (pas en query-string)', async () => {
      // Régression : le query-string `dataType=Survey+(FNDDS)` faisait rejeter la requête
      // en HTTP 400 par le nginx d'USDA de façon intermittente. On envoie donc en POST JSON.
      const spy = jest.spyOn(global, 'fetch').mockResolvedValue(usdaResponse([]));
      await adapter().search('chicken');
      const [url, init] = spy.mock.calls[0] as [URL, RequestInit];
      expect(String(url)).not.toContain('dataType');
      expect(init.method).toBe('POST');
      const body = JSON.parse(String(init.body));
      expect(Array.isArray(body.dataType)).toBe(true);
      expect(body.dataType).toContain('Survey (FNDDS)');
      expect(body.query).toBe('chicken');
    });

    it('réessaie une fois sur échec transitoire (5xx) avant de réussir', async () => {
      const spy = jest
        .spyOn(global, 'fetch')
        .mockResolvedValueOnce({ ok: false, status: 503 } as Response)
        .mockResolvedValueOnce(
          usdaResponse([
            { description: 'Chicken', dataType: 'Foundation', foodNutrients: [{ nutrientId: 1008, value: 165 }] },
          ]),
        );
      const list = await adapter().search('chicken');
      expect(spy).toHaveBeenCalledTimes(2);
      expect(list[0].name).toBe('Chicken');
    });

    it('priorise le candidat dont le nom recoupe le mieux la requête', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        usdaResponse([
          { description: 'Chicken soup', dataType: 'Branded', foodNutrients: [{ nutrientId: 1008, value: 50 }] },
          { description: 'Grilled chicken breast', dataType: 'Foundation', foodNutrients: [{ nutrientId: 1008, value: 165 }] },
        ]),
      );
      const food = await adapter().resolve('grilled chicken breast');
      expect(food?.name).toBe('Grilled chicken breast');
    });
  });
});
