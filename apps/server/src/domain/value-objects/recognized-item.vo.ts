/** Sortie du modèle de vision : ce qu'on a vu + estimation de portion. */
export class RecognizedItem {
  constructor(
    /** Nom affiché à l'utilisateur (français). */
    readonly name: string,
    readonly grams: number,
    readonly confidence: number,
    /** Nom de recherche pour la base nutritionnelle (anglais, USDA). Défaut : `name`. */
    readonly queryName: string = name,
  ) {}
}
