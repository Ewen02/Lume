import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { ChallengeService } from './challenge.service';

/**
 * Garde App Attest, **gatée par le flag `appAttestEnabled`** :
 * - flag OFF (défaut, compte Apple gratuit) → laisse passer (le `TokenGuard` reste la seule barrière).
 * - flag ON → exige un en-tête `X-App-Attest-Challenge` correspondant à un challenge émis et non
 *   encore consommé (anti-rejeu). La vérification cryptographique complète de l'attestation
 *   (chaîne X.509 Apple + CBOR) se branche ici (`verifyAttestation`) et nécessite un vrai device.
 *
 * Découpage volontaire : la partie testable sans device (challenge à usage unique, présence/format
 * des en-têtes, App ID attendu) est couverte ; la crypto device-bound est isolée derrière un seam.
 */
@Injectable()
export class AppAttestGuard implements CanActivate {
  constructor(
    private readonly config: ConfigService,
    private readonly challenges: ChallengeService,
  ) {}

  canActivate(ctx: ExecutionContext): boolean {
    if (!this.config.get<boolean>('appAttestEnabled')) return true; // flag OFF → pass-through

    const req = ctx.switchToHttp().getRequest<Request>();
    const challenge = (req.headers['x-app-attest-challenge'] as string | undefined) ?? '';
    const attestation = (req.headers['x-app-attest-object'] as string | undefined) ?? '';

    // 1) Challenge à usage unique : émis par le serveur, pas encore consommé, non expiré.
    if (!challenge || !this.challenges.consume(challenge)) {
      throw new UnauthorizedException('Attestation requise ou expirée.');
    }
    // 2) Attestation présente.
    if (!attestation) {
      throw new UnauthorizedException('Attestation manquante.');
    }
    // 3) Vérification crypto de l'attestation (device-bound). Voir verifyAttestation.
    if (!this.verifyAttestation(attestation, challenge)) {
      throw new UnauthorizedException('Attestation invalide.');
    }
    return true;
  }

  /** App ID attesté attendu = `<teamId>.<bundleId>`. Exposé pour le câblage de la vérif crypto. */
  expectedAppId(): string {
    const team = this.config.get<string>('appAttestTeamId') ?? '';
    const bundle = this.config.get<string>('appAttestBundleId') ?? '';
    return `${team}.${bundle}`;
  }

  /**
   * Vérification cryptographique complète de l'attestation App Attest (à compléter avec un device réel).
   * Étapes Apple : décoder le CBOR, valider la chaîne X.509 jusqu'à la racine Apple App Attestation,
   * vérifier que le `nonce` = SHA-256(authData ‖ SHA-256(challenge)), que le `rpIdHash` =
   * SHA-256(expectedAppId()), et que le `keyId` correspond. Nécessite un device (Secure Enclave) pour
   * produire une vraie attestation → non vérifiable au simulateur. Tant que ce n'est pas branché,
   * on refuse (sécurité par défaut : un flag ON sans implémentation ne doit pas ouvrir l'API).
   */
  private verifyAttestation(_attestation: string, _challenge: string): boolean {
    // TODO(app-attest): brancher la vérif X.509/CBOR avec un compte payant + device réel.
    return false;
  }
}
