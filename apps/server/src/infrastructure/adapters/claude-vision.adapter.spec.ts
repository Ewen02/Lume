import { ConfigService } from '@nestjs/config';
import { ClaudeVisionAdapter } from './claude-vision.adapter';

/** ConfigService minimal pour les tests (juste `get`). */
function fakeConfig(values: Record<string, unknown>): ConfigService {
  return { get: (k: string) => values[k] } as unknown as ConfigService;
}

/** Construit une réponse Anthropic (un bloc text contenant le JSON fourni). */
function anthropicResponse(text: string): Response {
  return {
    ok: true,
    status: 200,
    json: async () => ({ content: [{ type: 'text', text }] }),
  } as unknown as Response;
}

describe('ClaudeVisionAdapter', () => {
  afterEach(() => jest.restoreAllMocks());

  it('renvoie un repas de démo si aucune clé Anthropic', async () => {
    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: '' }));
    const spy = jest.spyOn(global, 'fetch');
    const meal = await adapter.recognize('data:image/jpeg;base64,xxx');
    expect(meal.items.length).toBeGreaterThan(0);
    // Sans clé, on n'appelle jamais l'API.
    expect(spy).not.toHaveBeenCalled();
  });

  it('parse la réponse et n\'extrait QUE food/grams/confidence (règle d\'or)', async () => {
    // Le LLM renvoie AUSSI des champs interdits (kcal, protein) — ils doivent être IGNORÉS.
    const json = JSON.stringify({
      dish: 'Poke bowl',
      items: [{ food: 'Saumon cru', food_en: 'raw salmon', grams: 120, confidence: 0.9, kcal: 9999, protein: 50 }],
    });
    jest.spyOn(global, 'fetch').mockResolvedValue(anthropicResponse(json));

    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: 'k', visionTimeoutMs: 1000 }));
    const meal = await adapter.recognize('data:image/jpeg;base64,xxx');

    expect(meal.dish).toBe('Poke bowl');
    expect(meal.items).toHaveLength(1);
    const item = meal.items[0];
    expect(item.name).toBe('Saumon cru');
    expect(item.queryName).toBe('raw salmon'); // l'anglais sert à la recherche en base
    expect(item.grams).toBe(120);
    expect(item.confidence).toBeCloseTo(0.9);
    // RÈGLE D'OR : RecognizedItem ne porte AUCUNE macro, peu importe ce que le LLM a renvoyé.
    expect((item as unknown as Record<string, unknown>).kcal).toBeUndefined();
    expect((item as unknown as Record<string, unknown>).protein).toBeUndefined();
    expect(JSON.stringify(item)).not.toContain('9999');
  });

  it('borne grammes et confidence (valeurs aberrantes du LLM)', async () => {
    const json = JSON.stringify({
      items: [{ food: 'X', grams: -5, confidence: 5 }],
    });
    jest.spyOn(global, 'fetch').mockResolvedValue(anthropicResponse(json));

    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: 'k' }));
    const meal = await adapter.recognize('img');
    expect(meal.items[0].grams).toBeGreaterThanOrEqual(1); // grammes >= 1
    expect(meal.items[0].confidence).toBeLessThanOrEqual(1); // confidence clampée à 1
    expect(meal.items[0].confidence).toBeGreaterThanOrEqual(0);
  });

  it('replie sur la démo si la réponse HTTP est en erreur', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({ ok: false, status: 500 } as Response);
    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: 'k' }));
    const meal = await adapter.recognize('img');
    expect(meal.items.length).toBeGreaterThan(0); // MOCK de démo
  });

  it('replie sur la démo si le JSON est illisible', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(anthropicResponse('ceci n\'est pas du JSON'));
    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: 'k' }));
    const meal = await adapter.recognize('img');
    expect(meal.items.length).toBeGreaterThan(0); // MOCK de démo
  });

  it('replie sur la démo en cas d\'exception réseau', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('network'));
    const adapter = new ClaudeVisionAdapter(fakeConfig({ anthropicApiKey: 'k' }));
    const meal = await adapter.recognize('img');
    expect(meal.items.length).toBeGreaterThan(0);
  });
});
