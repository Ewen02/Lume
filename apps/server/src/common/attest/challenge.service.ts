import { Injectable } from '@nestjs/common';
import { randomBytes } from 'node:crypto';

/**
 * Émet et consomme des défis (challenges) à usage unique pour App Attest. Le client demande un
 * challenge, le signe avec sa clé Secure Enclave dans l'attestation/assertion, et le serveur vérifie
 * que le challenge présenté a bien été émis et n'a pas déjà servi (anti-rejeu).
 *
 * Stockage en mémoire (process-local, sans DB) avec expiration — suffisant pour une instance Railway.
 * Indépendant de l'attestation crypto elle-même : c'est la moitié testable d'App Attest.
 */
@Injectable()
export class ChallengeService {
  /** challenge (hex) → instant d'expiration (ms epoch). */
  private readonly issued = new Map<string, number>();

  constructor(
    private readonly ttlMs = 5 * 60 * 1000, // 5 min pour signer et renvoyer
    private readonly now: () => number = () => Date.now(),
  ) {}

  /** Émet un challenge aléatoire à usage unique. */
  issue(): string {
    this.purgeExpired();
    const challenge = randomBytes(32).toString('hex');
    this.issued.set(challenge, this.now() + this.ttlMs);
    return challenge;
  }

  /**
   * Consomme un challenge : vrai s'il avait été émis et n'a pas expiré. Le supprime (usage unique →
   * un rejeu de la même requête échoue).
   */
  consume(challenge: string): boolean {
    const expiresAt = this.issued.get(challenge);
    if (expiresAt === undefined) return false;
    this.issued.delete(challenge); // usage unique
    return expiresAt > this.now();
  }

  private purgeExpired(): void {
    const t = this.now();
    for (const [c, exp] of this.issued) {
      if (exp <= t) this.issued.delete(c);
    }
  }
}
