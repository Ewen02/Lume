import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';

/** Garde simple par jeton statique : Authorization: Bearer <API_TOKEN>. */
@Injectable()
export class TokenGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    const header = req.headers['authorization'] ?? '';
    const [scheme, token] = header.split(' ');
    const expected = this.config.get<string>('apiToken');
    if (scheme !== 'Bearer' || !token || token !== expected) {
      throw new UnauthorizedException('Jeton invalide ou manquant');
    }
    return true;
  }
}
