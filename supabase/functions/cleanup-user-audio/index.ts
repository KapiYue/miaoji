import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "user-audio";
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const PAGE_SIZE = 100;
const MAX_OBJECTS_PER_RUN = 5_000;

type StorageEntry = {
  id?: string | null;
  name: string;
  created_at?: string | null;
};

function projectSecretKeys(): string[] {
  const keys: string[] = [];
  const configuredKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (configuredKeys) {
    const parsed = JSON.parse(configuredKeys) as Record<string, unknown>;
    for (const value of Object.values(parsed)) {
      if (typeof value === "string" && value.trim()) keys.push(value.trim());
    }
  }

  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (legacyKey) keys.push(legacyKey);
  if (!keys.length) throw new Error("Supabase secret key is unavailable");
  return [...new Set(keys)];
}

async function listFolder(
  storage: ReturnType<typeof createClient>["storage"],
  path: string,
): Promise<StorageEntry[]> {
  const entries: StorageEntry[] = [];
  for (let offset = 0;; offset += PAGE_SIZE) {
    const { data, error } = await storage.from(BUCKET).list(path, {
      limit: PAGE_SIZE,
      offset,
      sortBy: { column: "created_at", order: "asc" },
    });
    if (error) throw error;
    entries.push(...(data as StorageEntry[]));
    if (data.length < PAGE_SIZE) return entries;
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ error: "method not allowed" }, { status: 405 });
  }

  try {
    const secretKeys = projectSecretKeys();
    if (!secretKeys.includes(request.headers.get("apikey") ?? "")) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }
    const secretKey = secretKeys[0];

    const projectURL = Deno.env.get("SUPABASE_URL")?.trim();
    if (!projectURL) throw new Error("SUPABASE_URL is unavailable");
    const supabase = createClient(projectURL, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const cutoff = Date.now() - MAX_AGE_MS;
    const folders = [""];
    const expiredPaths: string[] = [];
    let scannedObjects = 0;

    while (folders.length && expiredPaths.length < MAX_OBJECTS_PER_RUN) {
      const folder = folders.pop()!;
      for (const entry of await listFolder(supabase.storage, folder)) {
        const path = folder ? `${folder}/${entry.name}` : entry.name;
        if (!entry.id) {
          folders.push(path);
          continue;
        }

        scannedObjects += 1;
        const createdAt = entry.created_at ? Date.parse(entry.created_at) : Number.NaN;
        if (Number.isFinite(createdAt) && createdAt <= cutoff) expiredPaths.push(path);
        if (expiredPaths.length >= MAX_OBJECTS_PER_RUN) break;
      }
    }

    let deletedObjects = 0;
    for (let offset = 0; offset < expiredPaths.length; offset += 1_000) {
      const batch = expiredPaths.slice(offset, offset + 1_000);
      const { error } = await supabase.storage.from(BUCKET).remove(batch);
      if (error) throw error;
      deletedObjects += batch.length;
    }

    return Response.json({
      bucket: BUCKET,
      cutoff: new Date(cutoff).toISOString(),
      scanned_objects: scannedObjects,
      deleted_objects: deletedObjects,
      capped: expiredPaths.length >= MAX_OBJECTS_PER_RUN,
    });
  } catch (error) {
    console.error("user-audio cleanup failed", error);
    return Response.json({ error: "cleanup failed" }, { status: 500 });
  }
});
