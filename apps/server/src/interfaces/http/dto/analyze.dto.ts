import { IsNotEmpty, IsString } from 'class-validator';

export class AnalyzeDto {
  /** Image du repas encodée en base64. */
  @IsString()
  @IsNotEmpty()
  image!: string;
}
