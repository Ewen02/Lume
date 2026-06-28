import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppAttestGuard } from './app-attest.guard';
import { ChallengeService } from './challenge.service';

function fakeConfig(values: Record<string, unknown>): ConfigService {
  return { get: (k: string) => values[k] } as unknown as ConfigService;
}

function contextWith(headers: Record<string, string>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ headers }) }),
  } as unknown as ExecutionContext;
}

describe('AppAttestGuard', () => {
  describe('flag désactivé (défaut)', () => {
    it('laisse passer sans attestation (pass-through)', () => {
      const guard = new AppAttestGuard(fakeConfig({ appAttestEnabled: false }), new ChallengeService());
      expect(guard.canActivate(contextWith({}))).toBe(true);
    });
  });

  describe('flag activé', () => {
    const config = fakeConfig({ appAttestEnabled: true, appAttestTeamId: 'ABCDE12345', appAttestBundleId: 'com.ewen.lume' });

    it('refuse une requête sans challenge', () => {
      const guard = new AppAttestGuard(config, new ChallengeService());
      expect(() => guard.canActivate(contextWith({}))).toThrow(UnauthorizedException);
    });

    it('refuse un challenge jamais émis', () => {
      const guard = new AppAttestGuard(config, new ChallengeService());
      const ctx = contextWith({ 'x-app-attest-challenge': 'bidon', 'x-app-attest-object': 'xxx' });
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
    });

    it('refuse un challenge valide mais réutilisé (anti-rejeu)', () => {
      const challenges = new ChallengeService();
      const guard = new AppAttestGuard(config, challenges);
      const c = challenges.issue();
      // 1re tentative : le challenge est consommé par la garde (puis l'attestation échoue, non branchée).
      const ctx = contextWith({ 'x-app-attest-challenge': c, 'x-app-attest-object': 'xxx' });
      expect(() => guard.canActivate(ctx)).toThrow();
      // 2e tentative avec le même challenge : déjà consommé → rejet « challenge ».
      expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
    });

    it('avec challenge valide, échoue à l\'attestation (crypto non branchée — refus par sécurité)', () => {
      const challenges = new ChallengeService();
      const guard = new AppAttestGuard(config, challenges);
      const c = challenges.issue();
      const ctx = contextWith({ 'x-app-attest-challenge': c, 'x-app-attest-object': 'attestation-factice' });
      // La garde consomme le challenge puis refuse car verifyAttestation() n'est pas implémentée.
      expect(() => guard.canActivate(ctx)).toThrow('Attestation invalide.');
    });

    it('expose l\'App ID attendu = teamId.bundleId', () => {
      const guard = new AppAttestGuard(config, new ChallengeService());
      expect(guard.expectedAppId()).toBe('ABCDE12345.com.ewen.lume');
    });
  });
});
