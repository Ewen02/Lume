import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

/**
 * Borne de sécurité dure sur l'image base64 (~14 Mo de caractères). Constante figée :
 * `@MaxLength` est évalué à la compilation, donc non configurable par env (à dessein).
 * Reste sous la limite du body Express (16 Mo, voir main.ts).
 */
const MAX_IMAGE_CHARS = 14_000_000;

export class AnalyzeDto {
  /** Image du repas encodée en base64 (data URL ou base64 brut). */
  @IsString()
  @IsNotEmpty()
  @MaxLength(MAX_IMAGE_CHARS, { message: 'Image trop volumineuse.' })
  image!: string;
}
