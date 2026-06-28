import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TokenGuard } from './token.guard';

function fakeConfig(token: string): ConfigService {
  return { get: () => token } as unknown as ConfigService;
}

/** ExecutionContext minimal exposant les headers fournis. */
function contextWith(headers: Record<string, string>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ headers }) }),
  } as unknown as ExecutionContext;
}

describe('TokenGuard', () => {
  const guard = new TokenGuard(fakeConfig('secret-token'));

  it('autorise un Bearer correct', () => {
    const ctx = contextWith({ authorization: 'Bearer secret-token' });
    expect(guard.canActivate(ctx)).toBe(true);
  });

  it('rejette un jeton incorrect', () => {
    const ctx = contextWith({ authorization: 'Bearer wrong' });
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('rejette un en-tête absent', () => {
    const ctx = contextWith({});
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('rejette un mauvais schéma (Basic au lieu de Bearer)', () => {
    const ctx = contextWith({ authorization: 'Basic secret-token' });
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('rejette un Bearer sans jeton', () => {
    const ctx = contextWith({ authorization: 'Bearer ' });
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('rejette un jeton de longueur différente (garde-fou timingSafeEqual)', () => {
    const ctx = contextWith({ authorization: 'Bearer secret-tok' }); // plus court
    expect(() => guard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('refuse TOUT accès si le serveur garde le jeton par défaut « change-me »', () => {
    const openGuard = new TokenGuard(fakeConfig('change-me'));
    // Même le « bon » jeton est refusé : un déploiement non configuré ne doit pas être ouvert.
    const ctx = contextWith({ authorization: 'Bearer change-me' });
    expect(() => openGuard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('refuse TOUT accès si le jeton serveur est vide', () => {
    const noTokenGuard = new TokenGuard(fakeConfig(''));
    const ctx = contextWith({ authorization: 'Bearer whatever' });
    expect(() => noTokenGuard.canActivate(ctx)).toThrow(UnauthorizedException);
  });

  it('message d\'erreur générique (ne révèle pas la cause)', () => {
    const ctx = contextWith({ authorization: 'Bearer wrong' });
    expect(() => guard.canActivate(ctx)).toThrow('Accès refusé.');
  });
});
