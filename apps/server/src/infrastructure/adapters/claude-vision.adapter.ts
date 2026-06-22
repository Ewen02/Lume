import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VisionPort, RecognizedMeal } from '../../domain/ports/vision.port';
import { RecognizedItem } from '../../domain/value-objects/recognized-item.vo';

/** Données de démonstration utilisées tant qu'aucune clé Anthropic n'est configurée. */
const MOCK: RecognizedMeal = {
  dish: 'Poulet riz brocoli',
  items: [
    new RecognizedItem('Poulet grillé', 150, 0.96, 'grilled chicken breast'),
    new RecognizedItem('Riz basmati', 200, 0.91, 'white rice cooked'),
    new RecognizedItem('Brocoli', 80, 0.82, 'broccoli'),
  ],
};

const PROMPT = `Tu es un expert en nutrition qui analyse la photo d'un repas pour un journal alimentaire.

Identifie CHAQUE aliment distinct visible dans l'assiette, séparément (ex. riz, viande, sauce, légumes, garnitures sont des items distincts). Sois exhaustif mais ne devine pas d'aliment invisible.

Pour estimer les portions en grammes, sers-toi des repères visuels (taille de l'assiette ≈ 26 cm, couverts, main, verre) et des densités usuelles. Distingue les états : "cuit" vs "cru", "grillé" vs "frit" (la cuisson change beaucoup les calories).

Réponds UNIQUEMENT avec un objet JSON valide, sans texte ni balise de code, au format exact :
{"dish": "nom du plat en français ou null", "items": [{"food": "nom court en français", "food_en": "specific English name for a nutrition database", "grams": 123, "confidence": 0.0}]}

- "dish" : nom du plat global s'il est identifiable (ex. "Nasi lemak", "Poke bowl saumon"), sinon null.
- "food" : nom court en français pour l'affichage (ex. "Poulet frit épicé").
- "food_en" : nom anglais le plus SPÉCIFIQUE pour USDA/Open Food Facts, en précisant cuisson et type (ex. "fried chicken thigh", "cooked white rice", "dragon fruit raw", "fried shrimp"). Évite les termes trop génériques.
- "grams" : portion estimée en grammes (entier, réaliste pour ce qui est visible).
- "confidence" : ta confiance entre 0 et 1.

Ne renvoie JAMAIS de calories ni de macronutriments : seulement le plat, les aliments, les portions et la confiance.`;

/**
 * Adaptateur de vision. Avec une clé Anthropic : appelle Claude (vision) et n'extrait
 * QUE {food, grams, confidence}. Les macros restent résolues côté domaine (déterministe).
 * Sans clé : renvoie un repas de démonstration.
 */
@Injectable()
export class ClaudeVisionAdapter implements VisionPort {
  constructor(private readonly config: ConfigService) {}

  async recognize(imageBase64: string): Promise<RecognizedMeal> {
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
      return parsed.items.length ? parsed : MOCK;
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

  private parse(text: string): RecognizedMeal {
    const cleaned = text.replace(/```json|```/g, '').trim();
    try {
      const parsed = JSON.parse(cleaned);
      // Nouveau format {dish, items:[...]} ou ancien format [...] : on accepte les deux.
      const arr: any[] = Array.isArray(parsed) ? parsed : (parsed?.items ?? []);
      const dish = typeof parsed?.dish === 'string' && parsed.dish.trim() ? String(parsed.dish).trim() : null;
      if (!Array.isArray(arr)) return { dish, items: [] };
      const items = arr
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
      return { dish, items };
    } catch {
      return { dish: null, items: [] };
    }
  }
}
