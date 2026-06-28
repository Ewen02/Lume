import { ChallengeService } from './challenge.service';

describe('ChallengeService', () => {
  it('émet un challenge consommable une fois', () => {
    const svc = new ChallengeService();
    const c = svc.issue();
    expect(c).toMatch(/^[0-9a-f]{64}$/); // 32 octets hex
    expect(svc.consume(c)).toBe(true);
  });

  it('refuse de consommer un challenge inconnu', () => {
    const svc = new ChallengeService();
    expect(svc.consume('jamais-émis')).toBe(false);
  });

  it('usage unique : un 2e consume du même challenge échoue (anti-rejeu)', () => {
    const svc = new ChallengeService();
    const c = svc.issue();
    expect(svc.consume(c)).toBe(true);
    expect(svc.consume(c)).toBe(false); // déjà consommé
  });

  it('expire un challenge après le TTL', () => {
    let t = 0;
    const svc = new ChallengeService(1000, () => t);
    const c = svc.issue();
    t = 1001;
    expect(svc.consume(c)).toBe(false); // expiré
  });

  it('deux challenges émis sont distincts', () => {
    const svc = new ChallengeService();
    expect(svc.issue()).not.toBe(svc.issue());
  });
});
