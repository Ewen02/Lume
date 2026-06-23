import { fetchWithTimeout } from './fetch-with-timeout';

describe('fetchWithTimeout', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('retourne la réponse quand le fetch répond avant le délai', async () => {
    const fakeRes = { ok: true, status: 200 } as Response;
    const spy = jest.spyOn(global, 'fetch').mockResolvedValue(fakeRes);

    const res = await fetchWithTimeout('https://x.test', { timeoutMs: 1000 });

    expect(res).toBe(fakeRes);
    // Le signal d'abort est transmis à fetch.
    expect(spy).toHaveBeenCalledWith('https://x.test', expect.objectContaining({ signal: expect.any(AbortSignal) }));
  });

  it('abandonne (AbortError) quand le délai est dépassé', async () => {
    // fetch qui ne se résout jamais seul ; il rejette quand le signal est abort.
    jest.spyOn(global, 'fetch').mockImplementation((_url, init?: RequestInit) => {
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => {
          const err = new Error('aborted');
          err.name = 'AbortError';
          reject(err);
        });
      });
    });

    await expect(fetchWithTimeout('https://slow.test', { timeoutMs: 10 })).rejects.toMatchObject({
      name: 'AbortError',
    });
  });

  it('propage une erreur réseau (pas de repli ici, c\'est à l\'appelant de catcher)', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('network down'));
    await expect(fetchWithTimeout('https://x.test', { timeoutMs: 1000 })).rejects.toThrow('network down');
  });
});
