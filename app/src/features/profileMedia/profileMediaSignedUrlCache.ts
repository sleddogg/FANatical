import { requireSupabase } from "../../lib/supabase/client";

export const profileMediaBucket = "profile-media";

const signedUrlLifetimeSeconds = 60 * 60;
const signedUrlSafetyWindowMs = 5 * 60 * 1000;
const tripwireWindowMs = 60 * 1000;
const tripwireHighCount = 12;

type CacheEntry = Readonly<{
  userId: string;
  bucket: string;
  path: string;
  signedUrl: string;
  expiresAt: number;
}>;

type InFlightEntry = Readonly<{
  userId: string;
  promise: Promise<string>;
}>;

type ProfileMediaSignedUrlStore = {
  cache: Map<string, CacheEntry>;
  inFlight: Map<string, InFlightEntry>;
  userEpochs: Map<string, number>;
  globalEpoch: number;
  developmentGenerations: Map<string, number[]>;
  developmentAllGenerations: number[];
};

type ProfileMediaGlobal = typeof globalThis & {
  __fanaticalProfileMediaSignedUrlStore?: ProfileMediaSignedUrlStore;
};

const profileMediaGlobal = globalThis as ProfileMediaGlobal;
const store = profileMediaGlobal.__fanaticalProfileMediaSignedUrlStore ??= {
  cache: new Map(),
  inFlight: new Map(),
  userEpochs: new Map(),
  globalEpoch: 0,
  developmentGenerations: new Map(),
  developmentAllGenerations: [],
};

function cacheKey(userId: string, bucket: string, path: string) {
  return JSON.stringify([userId, bucket, path]);
}

function usable(entry: CacheEntry | undefined, now = Date.now()) {
  return Boolean(entry && entry.expiresAt - signedUrlSafetyWindowMs > now);
}

function noteDevelopmentGeneration(key: string) {
  if (!import.meta.env.DEV) return;
  const now = Date.now();
  const recentForPath = (store.developmentGenerations.get(key) ?? []).filter((timestamp) => now - timestamp < tripwireWindowMs);
  const recentAll = store.developmentAllGenerations.filter((timestamp) => now - timestamp < tripwireWindowMs);
  recentForPath.push(now);
  recentAll.push(now);
  store.developmentGenerations.set(key, recentForPath);
  store.developmentAllGenerations = recentAll;
  if (recentForPath.length > 1 || recentAll.length > tripwireHighCount) {
    console.warn("FANatical storage warning: repeated signed URL generation detected", {
      repeatedPath: recentForPath.length > 1,
      generatedWithinWindow: recentAll.length,
    });
  }
}

function deferred() {
  let resolve!: (value: string) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<string>((resolveValue, rejectValue) => {
    resolve = resolveValue;
    reject = rejectValue;
  });
  return { promise, resolve, reject };
}

export function cachedProfileMediaSignedUrl(userId: string, bucket: string, path: string) {
  const entry = store.cache.get(cacheKey(userId, bucket, path));
  return usable(entry) ? entry?.signedUrl : undefined;
}

export async function resolveProfileMediaSignedUrls(
  userId: string,
  bucket: string,
  paths: readonly string[],
): Promise<ReadonlyMap<string, string>> {
  const uniquePaths = [...new Set(paths.filter(Boolean))];
  if (!uniquePaths.length) return new Map();

  const requested = new Map<string, Promise<string>>();
  const pending = new Map<string, ReturnType<typeof deferred>>();
  const requestGlobalEpoch = store.globalEpoch;
  const requestUserEpoch = store.userEpochs.get(userId) ?? 0;

  for (const path of uniquePaths) {
    const key = cacheKey(userId, bucket, path);
    const cached = store.cache.get(key);
    if (usable(cached)) {
      requested.set(path, Promise.resolve(cached!.signedUrl));
      continue;
    }
    const existing = store.inFlight.get(key);
    if (existing) {
      requested.set(path, existing.promise);
      continue;
    }
    const next = deferred();
    pending.set(path, next);
    requested.set(path, next.promise);
    store.inFlight.set(key, { userId, promise: next.promise });
    noteDevelopmentGeneration(key);
  }

  if (pending.size) {
    const missingPaths = [...pending.keys()];
    void (async () => {
      try {
        const signed = new Map<string, string>();
        const storage = requireSupabase().storage.from(bucket);
        if (missingPaths.length === 1) {
          const path = missingPaths[0]!;
          const result = await storage.createSignedUrl(path, signedUrlLifetimeSeconds);
          if (result.error) throw new Error(result.error.message);
          signed.set(path, result.data.signedUrl);
        } else {
          const result = await storage.createSignedUrls(missingPaths, signedUrlLifetimeSeconds);
          if (result.error) throw new Error(result.error.message);
          for (const row of result.data) {
            if (row.error || !row.path || !row.signedUrl) throw new Error(row.error || "Profile media could not be signed.");
            signed.set(row.path, row.signedUrl);
          }
        }

        const expiresAt = Date.now() + signedUrlLifetimeSeconds * 1000;
        for (const path of missingPaths) {
          const url = signed.get(path);
          if (!url) throw new Error(`Profile media signing did not return ${path}.`);
          if (store.globalEpoch === requestGlobalEpoch && (store.userEpochs.get(userId) ?? 0) === requestUserEpoch) {
            store.cache.set(cacheKey(userId, bucket, path), { userId, bucket, path, signedUrl: url, expiresAt });
          }
          pending.get(path)!.resolve(url);
        }
      } catch (reason) {
        for (const request of pending.values()) request.reject(reason);
      } finally {
        for (const [path, request] of pending) {
          const key = cacheKey(userId, bucket, path);
          if (store.inFlight.get(key)?.promise === request.promise) store.inFlight.delete(key);
        }
      }
    })();
  }

  const resolved = await Promise.all([...requested].map(async ([path, promise]) => [path, await promise] as const));
  return new Map(resolved);
}

export async function resolveProfileMediaSignedUrl(userId: string, bucket: string, path: string) {
  const urls = await resolveProfileMediaSignedUrls(userId, bucket, [path]);
  const url = urls.get(path);
  if (!url) throw new Error("Profile media could not be signed.");
  return url;
}

export function evictProfileMediaSignedUrls(userId: string, bucket: string, paths: readonly string[]) {
  for (const path of paths) store.cache.delete(cacheKey(userId, bucket, path));
}

export function clearProfileMediaSignedUrls(userId?: string) {
  if (!userId) {
    store.globalEpoch += 1;
    store.cache.clear();
    store.inFlight.clear();
    return;
  }
  store.userEpochs.set(userId, (store.userEpochs.get(userId) ?? 0) + 1);
  for (const [key, entry] of store.cache) if (entry.userId === userId) store.cache.delete(key);
  for (const [key, entry] of store.inFlight) if (entry.userId === userId) store.inFlight.delete(key);
}

export function resetProfileMediaSignedUrlCacheForTests() {
  store.cache.clear();
  store.inFlight.clear();
  store.userEpochs.clear();
  store.globalEpoch = 0;
  store.developmentGenerations.clear();
  store.developmentAllGenerations = [];
}
