import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NutritionDbPort } from '../../domain/ports/nutrition-db.port';
import { Food } from '../../domain/value-objects/food.vo';
import { Macros } from '../../domain/value-objects/macros.vo';
import { fetchWithTimeout } from '../http/fetch-with-timeout';

/** Table de secours (macros pour 100 g) si aucune clé USDA n'est configurée. */
const FALLBACK: Food[] = [
  new Food('Poulet grillé', new Macros(165, 31, 0, 4), 'USDA'),
  new Food('Riz basmati cuit', new Macros(130, 3, 28, 0), 'USDA'),
  new Food('Brocoli', new Macros(34, 3, 7, 0), 'USDA'),
  new Food('Œuf entier', new Macros(143, 13, 1, 10), 'USDA'),
  new Food('Banane', new Macros(89, 1, 23, 0), 'USDA'),
  new Food('Skyr nature', new Macros(63, 11, 4, 0), 'USDA'),
  new Food('Amandes', new Macros(579, 21, 22, 50), 'USDA'),
];

@Injectable()
export class UsdaAdapter implements NutritionDbPort {
  private readonly logger = new Logger(UsdaAdapter.name);

  constructor(private readonly config: ConfigService) {}
  private get key(): string {
    return this.config.get<string>('usdaApiKey') ?? '';
  }
  private get timeoutMs(): number {
    return this.config.get<number>('nutritionTimeoutMs') ?? 8000;
  }

  async resolve(name: string): Promise<Food | null> {
    // `search` renvoie déjà la liste triée par pertinence + fiabilité de source.
    const list = await this.search(name);
    if (list.length === 0) return null;
    // Garde-fou anti-faux-positif : on exige un recouvrement FORT entre la requête et le
    // meilleur candidat. « 1 mot suffit » laissait passer « fried chicken thigh » → « chicken
    // broth » (juste « chicken »), affiché comme `matched:true` avec des macros fausses.
    const words = name.toLowerCase().split(/\s+/).filter((w) => w.length > 2);
    if (words.length === 0) return list[0];
    const top = list[0].name.toLowerCase();
    const overlap = words.filter((w) => top.includes(w)).length;
    // Requête à un seul mot : ce mot doit être présent. Requête multi-mots : au moins la moitié
    // des mots significatifs (et jamais moins de 2), pour rejeter un recoupement accidentel.
    const required = words.length === 1 ? 1 : Math.max(2, Math.ceil(words.length / 2));
    return overlap >= required ? list[0] : null;
  }

  /** Fiabilité d'une source USDA pour des aliments génériques (plus haut = mieux). */
  private static readonly DATATYPE_RANK: Record<string, number> = {
    Foundation: 4,
    'SR Legacy': 3,
    'Survey (FNDDS)': 2,
    Branded: 1,
  };

  async search(query: string): Promise<Food[]> {
    const q = query.trim();
    if (!q) return this.key ? [] : FALLBACK;
    if (!this.key) return this.localSearch(q);
    try {
      const res = await this.fetchSearch(q);
      if (!res.ok) {
        this.logger.warn(`USDA HTTP ${res.status} pour « ${q} » — repli local.`);
        return this.localSearch(q);
      }
      const json: any = await res.json();
      const foods: any[] = json?.foods ?? [];
      // On garde le dataType pour prioriser les sources fiables au moment du tri.
      const mapped = foods
        .map((f) => {
          const food = this.toFood(f);
          return food ? { food, dataType: String(f?.dataType ?? '') } : null;
        })
        .filter((x): x is { food: Food; dataType: string } => x !== null);
      if (mapped.length === 0) return this.localSearch(q);
      // Tri : pertinence du nom d'abord, puis fiabilité de la source.
      const words = q.toLowerCase().split(/\s+/).filter((w) => w.length > 2);
      const ranked = mapped
        .map((m) => ({ ...m, score: this.relevance(words, m.food.name, m.dataType) }))
        .sort((a, b) => b.score - a.score);
      return ranked.map((r) => r.food);
    } catch (err) {
      const reason = (err as Error)?.name === 'AbortError' ? `timeout (${this.timeoutMs} ms)` : (err as Error)?.message;
      this.logger.warn(`USDA échec pour « ${q} » (${reason}) — repli local.`);
      return this.localSearch(q);
    }
  }

  /**
   * Appelle FDC en POST JSON. Le `dataType` part en tableau dans le corps : on évite
   * ainsi le query-string `dataType=Survey+%28FNDDS%29` qui faisait rejeter la requête
   * en HTTP 400 par le nginx d'entrée d'USDA, de façon intermittente.
   * Un seul nouvel essai sur échec transitoire (429/5xx) — au-delà, l'appelant bascule en local.
   */
  private async fetchSearch(q: string): Promise<Response> {
    const url = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
    url.searchParams.set('api_key', this.key);
    const init = {
      timeoutMs: this.timeoutMs,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query: q,
        pageSize: 25,
        // Génériques d'abord (Foundation/SR Legacy/Survey), Branded en dernier recours.
        dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)', 'Branded'],
      }),
    };
    const res = await fetchWithTimeout(url, init);
    // Échec transitoire (throttle/erreur serveur) → un seul nouvel essai après un court délai.
    if (res.status === 429 || res.status >= 500) {
      await new Promise((r) => setTimeout(r, 300));
      return fetchWithTimeout(url, init);
    }
    return res;
  }

  /** Score de pertinence : recouvrement des mots + bonus correspondance exacte + fiabilité source. */
  private relevance(words: string[], name: string, dataType: string): number {
    const n = name.toLowerCase();
    const overlap = words.filter((w) => n.includes(w)).length;
    // Bonus si tous les mots de la requête sont présents (correspondance forte).
    const allWords = words.length > 0 && overlap === words.length ? 3 : 0;
    const sourceRank = UsdaAdapter.DATATYPE_RANK[dataType] ?? 0;
    return overlap * 4 + allWords + sourceRank;
  }

  private localSearch(q: string): Food[] {
    const n = q.toLowerCase();
    return FALLBACK.filter(
      (f) => f.name.toLowerCase().includes(n) || n.includes(f.name.toLowerCase().split(' ')[0]),
    );
  }

  /** Mappe une entrée FDC vers Food (macros pour 100 g) via les numéros de nutriments. */
  private toFood(f: any): Food | null {
    const name: string | undefined = f?.description;
    if (!name) return null;
    const nutrients: any[] = f?.foodNutrients ?? [];
    // Les nutriments USDA portent soit `nutrientNumber`/`number` (ex. "208"),
    // soit `nutrientId` (ex. 1008 = énergie). On accepte les deux conventions.
    const pick = (...nums: string[]): number => {
      const hit = nutrients.find((x) => {
        const id = String(x?.nutrientNumber ?? x?.number ?? x?.nutrientId ?? '');
        return nums.includes(id);
      });
      return hit ? Number(hit.value ?? hit.amount ?? 0) || 0 : 0;
    };
    const kcal = pick('208', '1008'); // Energy (kcal)
    const protein = pick('203', '1003'); // Protein
    const carbs = pick('205', '1005'); // Carbohydrate, by difference
    const fat = pick('204', '1004'); // Total lipid (fat)
    // Une entrée sans énergie n'est pas exploitable pour un journal calorique.
    if (!kcal) return null;
    return new Food(
      name,
      new Macros(Math.round(kcal), Math.round(protein), Math.round(carbs), Math.round(fat)),
      'USDA',
    );
  }
}
