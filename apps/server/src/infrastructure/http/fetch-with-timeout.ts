/**
 * `fetch` avec délai maximum (AbortController). Empêche un service externe lent/down
 * de bloquer la requête indéfiniment. Lève en cas de timeout ou d'erreur réseau —
 * à l'appelant de catcher et de basculer sur son repli.
 */
export async function fetchWithTimeout(
  url: string | URL,
  init: RequestInit & { timeoutMs: number },
): Promise<Response> {
  const { timeoutMs, ...rest } = init;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...rest, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}
