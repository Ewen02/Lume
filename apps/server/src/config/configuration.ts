export interface AppConfig {
  port: number;
  apiToken: string;
  anthropicApiKey: string;
  usdaApiKey: string;
  anthropicModel: string;
}

export default (): AppConfig => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  apiToken: process.env.API_TOKEN ?? 'change-me',
  anthropicApiKey: process.env.ANTHROPIC_API_KEY ?? '',
  usdaApiKey: process.env.USDA_API_KEY ?? '',
  anthropicModel: process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-6',
});
