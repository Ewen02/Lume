import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import { Request } from 'express';

/**
 * Garde par jeton statique : `Authorization: Bearer <API_TOKEN>`.
 * Durcissements : comparaison en temps constant (anti-timing-attack), refus du jeton
 * par défaut `change-me` (un déploiement prod mal configuré ne doit pas être ouvert),
 * message d'erreur générique (ne révèle pas si c'est le schéma, le jeton ou la config).
 */
@Injectable()
export class TokenGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const header = req.headers['authorization'] ?? '';
    const [scheme, token] = header.split(' ');
    const expected = this.config.get<string>('apiToken');

    // Jeton serveur non configuré (ou laissé au défaut) : on refuse TOUT plutôt que d'être ouvert.
    if (!expected || expected === 'change-me') {
      throw new UnauthorizedException('Accès refusé.');
    }
    if (scheme !== 'Bearer' || !token || !TokenGuard.constantTimeEqual(token, expected)) {
      throw new UnauthorizedException('Accès refusé.');
    }
    return true;
  }

  /** Comparaison en temps constant : ne court-circuite pas au premier octet différent. */
  private static constantTimeEqual(a: string, b: string): boolean {
    const ab = Buffer.from(a);
    const bb = Buffer.from(b);
    // `timingSafeEqual` exige des longueurs égales ; comparer la longueur d'abord est acceptable
    // (la longueur du jeton attendu n'est pas un secret exploitable).
    if (ab.length !== bb.length) return false;
    return timingSafeEqual(ab, bb);
  }
}
