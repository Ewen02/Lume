import { RecognizedItem } from '../value-objects/recognized-item.vo';

export const VISION_PORT = Symbol('VISION_PORT');

/** Reconnaissance d'un repas : nom global du plat (si identifiable) + aliments distincts. */
export interface RecognizedMeal {
  /** Nom du plat global (ex. "Burger", "Nasi lemak"), ou null si non identifiable. */
  dish: string | null;
  items: RecognizedItem[];
  /**
   * Vrai si le résultat provient du repli de démonstration (clé Anthropic absente ou appel
   * vision en échec), et non d'une vraie reconnaissance. À remonter à l'UI pour ne pas
   * présenter un faux repas crédible comme une analyse réelle.
   */
  degraded?: boolean;
}

/** Reconnaissance d'aliments depuis une image (NE renvoie jamais de macros). */
export interface VisionPort {
  recognize(imageBase64: string): Promise<RecognizedMeal>;
}
