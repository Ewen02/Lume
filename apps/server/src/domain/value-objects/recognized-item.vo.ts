/** Sortie du modèle de vision : ce qu'on a vu + estimation de portion. */
export class RecognizedItem {
  constructor(
    readonly name: string,
    readonly grams: number,
    readonly confidence: number,
  ) {}
}
