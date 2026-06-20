import { RecognizedItem } from '../value-objects/recognized-item.vo';

export const VISION_PORT = Symbol('VISION_PORT');

/** Reconnaissance d'aliments depuis une image (NE renvoie jamais de macros). */
export interface VisionPort {
  recognize(imageBase64: string): Promise<RecognizedItem[]>;
}
