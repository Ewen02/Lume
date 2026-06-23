import { ConfigService } from '@nestjs/config';
import { OpenFoodFactsAdapter } from './openfoodfacts.adapter';

function fakeConfig(values: Record<string, unknown>): ConfigService {
  return { get: (k: string) => values[k] } as unknown as ConfigService;
}

function offResponse(body: unknown): Response {
  return { ok: true, status: 200, json: async () => body } as unknown as Response;
}

describe('OpenFoodFactsAdapter', () => {
  const adapter = () => new OpenFoodFactsAdapter(fakeConfig({ nutritionTimeoutMs: 1000 }));
  afterEach(() => jest.restoreAllMocks());

  describe('lookup (code-barres)', () => {
    it('retourne null pour un code vide', async () => {
      const spy = jest.spyOn(global, 'fetch');
      expect(await adapter().lookup('')).toBeNull();
      expect(spy).not.toHaveBeenCalled();
    });

    it('mappe un produit trouvé en Food (macros pour 100 g + code-barres)', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        offResponse({
          status: 1,
          product: {
            product_name: 'Muesli croustillant',
            nutriments: { 'energy-kcal_100g': 450, proteins_100g: 8, carbohydrates_100g: 62, fat_100g: 11 },
          },
        }),
      );
      const food = await adapter().lookup('3017620422003');
      expect(food?.name).toBe('Muesli croustillant');
      expect(food?.per100g.kcal).toBe(450);
      expect(food?.source).toBe('OpenFoodFacts');
      expect(food?.barcode).toBe('3017620422003');
    });

    it('convertit l\'énergie kJ → kcal si les kcal manquent', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        offResponse({
          status: 1,
          product: { product_name: 'Produit', nutriments: { energy_100g: 1000 } }, // 1000 kJ ≈ 239 kcal
        }),
      );
      const food = await adapter().lookup('123');
      expect(food?.per100g.kcal).toBe(Math.round(1000 / 4.184));
    });

    it('retourne null si produit introuvable (status 0, pas de product)', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(offResponse({ status: 0 }));
      expect(await adapter().lookup('000')).toBeNull();
    });

    it('retourne null sur HTTP en erreur', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue({ ok: false, status: 404 } as Response);
      expect(await adapter().lookup('123')).toBeNull();
    });

    it('retourne null en cas d\'exception réseau', async () => {
      jest.spyOn(global, 'fetch').mockRejectedValue(new Error('net'));
      expect(await adapter().lookup('123')).toBeNull();
    });
  });

  describe('searchByName', () => {
    it('retourne null pour une requête vide', async () => {
      expect(await adapter().searchByName('  ')).toBeNull();
    });

    it('retient le meilleur produit qui recoupe la requête', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        offResponse({
          products: [
            { product_name: 'Jus d\'orange', nutriments: { 'energy-kcal_100g': 45 } },
            { product_name: 'Lait', nutriments: { 'energy-kcal_100g': 60 } },
          ],
        }),
      );
      const food = await adapter().searchByName('orange');
      expect(food?.name).toBe('Jus d\'orange');
    });

    it('retourne null si aucun produit ne recoupe (évite un faux match)', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(
        offResponse({ products: [{ product_name: 'Lait', nutriments: { 'energy-kcal_100g': 60 } }] }),
      );
      expect(await adapter().searchByName('orange')).toBeNull();
    });
  });
});
