import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../app.module';

/**
 * Vérifie le rate-limiting de bout en bout : `/analyze` (Claude, coûteux) est strictement
 * limité, `/health` est exempté. Les limites sont basses via l'env pour un test rapide.
 */
describe('Rate limiting (e2e)', () => {
  let app: INestApplication;
  const token = 'test-token';

  // La résolution nutritionnelle peut taper des bases distantes (USDA/OFF) → marge de temps.
  jest.setTimeout(30_000);

  beforeAll(async () => {
    process.env.API_TOKEN = token;
    process.env.ANTHROPIC_API_KEY = ''; // /analyze renvoie le repas de démo (pas d'appel vision)
    process.env.RATE_LIMIT_ANALYZE_PER_MIN = '1'; // 1 seule résolution réelle → test rapide
    process.env.RATE_LIMIT_GLOBAL_PER_MIN = '50';

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  const img =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAP//////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAAAv/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8AvwA=';

  function analyze() {
    return request(app.getHttpServer())
      .post('/analyze')
      .set('Authorization', `Bearer ${token}`)
      .send({ image: img });
  }

  it('limite /analyze : passe sous la limite puis renvoie 429', async () => {
    // 1ʳᵉ requête autorisée (limite = 1/min).
    const first = await analyze();
    expect(first.status).toBeLessThan(400);
    // Les suivantes dépassent la fenêtre → 429 (instantané, sans toucher le handler).
    const second = await analyze();
    expect(second.status).toBe(429);
    const third = await analyze();
    expect(third.status).toBe(429);
  });

  it('exempte /health du rate-limiting (healthcheck)', async () => {
    // Bien au-delà de toute limite : la sonde reste disponible.
    for (let i = 0; i < 10; i++) {
      const res = await request(app.getHttpServer()).get('/health');
      expect(res.status).toBe(200);
    }
  });
});
