export interface AppConfig {
  port: number;
  apiToken: string;
  anthropicApiKey: string;
  usdaApiKey: string;
  anthropicModel: string;
  /** Délai max (ms) des appels aux bases nutritionnelles (USDA, Open Food Facts). */
  nutritionTimeoutMs: number;
  /** Délai max (ms) de l'appel à la vision Claude (plus long, l'analyse d'image prend du temps). */
  visionTimeoutMs: number;
  /** Origine(s) CORS autorisée(s). '*' par défaut (app native sans cookie). */
  corsOrigin: string;
  /** Débit global autorisé : requêtes max par minute et par IP (tous endpoints). */
  rateLimitGlobalPerMin: number;
  /** Débit de `/analyze` : appels Claude (coûteux) max par minute et par IP. */
  rateLimitAnalyzePerMin: number;
}

export default (): AppConfig => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  apiToken: process.env.API_TOKEN ?? 'change-me',
  anthropicApiKey: process.env.ANTHROPIC_API_KEY ?? '',
  usdaApiKey: process.env.USDA_API_KEY ?? '',
  anthropicModel: process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-6',
  nutritionTimeoutMs: parseInt(process.env.NUTRITION_TIMEOUT_MS ?? '8000', 10),
  visionTimeoutMs: parseInt(process.env.VISION_TIMEOUT_MS ?? '30000', 10),
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  rateLimitGlobalPerMin: parseInt(process.env.RATE_LIMIT_GLOBAL_PER_MIN ?? '60', 10),
  rateLimitAnalyzePerMin: parseInt(process.env.RATE_LIMIT_ANALYZE_PER_MIN ?? '10', 10),
});
