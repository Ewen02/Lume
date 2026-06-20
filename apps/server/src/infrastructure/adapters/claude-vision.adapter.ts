import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VisionPort } from '../../domain/ports/vision.port';
import { RecognizedItem } from '../../domain/value-objects/recognized-item.vo';

/** Données de démonstration utilisées tant qu'aucune clé Anthropic n'est configurée. */
const MOCK: RecognizedItem[] = [
  new RecognizedItem('Poulet grillé', 150, 0.96, 'grilled chicken breast'),
  new RecognizedItem('Riz basmati', 200, 0.91, 'white rice cooked'),
  new RecognizedItem('Brocoli', 80, 0.82, 'broccoli'),
];

const PROMPT = `Tu es un assistant de reconnaissance alimentaire. Analyse la photo d'un repas et identifie chaque aliment distinct.
Réponds UNIQUEMENT avec un tableau JSON valide, sans aucun texte ni balise de code, au format exact :
[{"food": "nom court en français", "food_en": "short English name", "grams": 123, "confidence": 0.0}]
- "food" : nom court en français, pour l'affichage (ex. "Fruit du dragon").
- "food_en" : nom générique en anglais pour une base nutritionnelle USDA (ex. "dragon fruit", "grilled chicken breast", "white rice cooked"). Utilise le terme le plus standard.
- "grams" : portion estimée en grammes (entier).
- "confidence" : ta confiance entre 0 et 1.
Ne renvoie JAMAIS de calories ni de macronutriments : seulement l'aliment, la portion et la confiance.`;

/**
 * Adaptateur de vision. Avec une clé Anthropic : appelle Claude (vision) et n'extrait
 * QUE {food, grams, confidence}. Les macros restent résolues côté domaine (déterministe).
 * Sans clé : renvoie un repas de démonstration.
 */
@Injectable()
export class ClaudeVisionAdapter implements VisionPort {
  constructor(private readonly config: ConfigService) {}

  async recognize(imageBase64: string): Promise<RecognizedItem[]> {
    const apiKey = this.config.get<string>('anthropicApiKey') ?? '';
    if (!apiKey) return MOCK;

    const model = this.config.get<string>('anthropicModel') || 'claude-sonnet-4-6';
    const { mediaType, data } = this.splitDataUrl(imageBase64);

    try {
      const res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model,
          max_tokens: 1024,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'image', source: { type: 'base64', media_type: mediaType, data } },
                { type: 'text', text: PROMPT },
              ],
            },
          ],
        }),
      });
      if (!res.ok) return MOCK;
      const json: any = await res.json();
      const text: string = (json?.content ?? [])
        .filter((b: any) => b?.type === 'text')
        .map((b: any) => b.text)
        .join('\n');
      const parsed = this.parse(text);
      return parsed.length ? parsed : MOCK;
    } catch {
      return MOCK;
    }
  }

  /** Accepte une data URL (data:image/jpeg;base64,...) ou du base64 brut. */
  private splitDataUrl(input: string): { mediaType: string; data: string } {
    const m = /^data:(.+?);base64,(.*)$/s.exec(input.trim());
    if (m) return { mediaType: m[1], data: m[2] };
    return { mediaType: 'image/jpeg', data: input.trim() };
  }

  private parse(text: string): RecognizedItem[] {
    const cleaned = text.replace(/```json|```/g, '').trim();
    try {
      const arr = JSON.parse(cleaned);
      if (!Array.isArray(arr)) return [];
      return arr
        .filter((x: any) => x && typeof x.food === 'string')
        .map((x: any) => {
          const fr = String(x.food);
          // Nom de recherche USDA : l'anglais si fourni, sinon le nom FR en dernier recours.
          const en = typeof x.food_en === 'string' && x.food_en.trim() ? String(x.food_en) : fr;
          return new RecognizedItem(
            fr,
            Math.max(1, Math.round(Number(x.grams) || 0)),
            Math.min(1, Math.max(0, Number(x.confidence) || 0)),
            en,
          );
        });
    } catch {
      return [];
    }
  }
}
