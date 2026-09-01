import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";

const appDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryDirectory = resolve(appDirectory, "..");
const supabaseCliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
const productionHostname = "lsuceoieqgbagxxwobxu.supabase.co";
const bucket = "profile-media";
const password = "Local-only-verification-2026!";
const runId = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const ownerName = `Verify${Math.random().toString(36).slice(2, 10)}`;
const requestedUrls = [];

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const url = typeof input === "string" || input instanceof URL ? String(input) : input.url;
  requestedUrls.push(url);
  if (new URL(url).hostname === productionHostname) {
    throw new Error(`Blocked unexpected hosted Supabase request: ${url}`);
  }
  return originalFetch(input, init);
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function parseEnvironment(output) {
  const values = new Map();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

function localStatus() {
  const result = spawnSync(
    process.execPath,
    [supabaseCliPath, "status", "-o", "env", "--workdir", repositoryDirectory],
    {
      cwd: appDirectory,
      encoding: "utf8",
      env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
      maxBuffer: 20 * 1024 * 1024,
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error("The local Supabase stack is not ready.");
  return parseEnvironment(result.stdout);
}

function makeClient(url, key) {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

function requireResult(result, message) {
  if (result.error) throw new Error(`${message}: ${result.error.message}`);
  return result.data;
}

function requireDenied(result, message) {
  if (!result.error) throw new Error(message);
}

function delay(milliseconds) {
  return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));
}

async function createVerificationUser(client, label) {
  const email = `local-verification-${label}-${runId}@fanatical.invalid`;
  const result = await client.auth.signUp({
    email,
    password,
    options: { data: { display_name: `Local ${label}` } },
  });
  const data = requireResult(result, `${label} signup failed`);
  assert(data.user && data.session, `${label} signup did not return a confirmed local session.`);
  const verified = requireResult(await client.auth.getUser(), `${label} getUser failed`);
  assert(verified.user.id === data.user.id, `${label} Auth identity did not round-trip.`);
  return data.user.id;
}

async function waitForRealtimeSubscription(channel) {
  await new Promise((resolvePromise, rejectPromise) => {
    const timeout = setTimeout(() => rejectPromise(new Error("Realtime subscription timed out.")), 15_000);
    channel.subscribe((status, error) => {
      if (status === "SUBSCRIBED") {
        clearTimeout(timeout);
        resolvePromise();
      } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
        clearTimeout(timeout);
        rejectPromise(error ?? new Error(`Realtime subscription failed with ${status}.`));
      }
    });
  });
}

const status = localStatus();
const apiUrl = status.get("API_URL");
const publicKey = status.get("PUBLISHABLE_KEY") ?? status.get("ANON_KEY");
const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");

assert(apiUrl && new URL(apiUrl).hostname === "127.0.0.1", "Verification requires the local Supabase API.");
assert(publicKey, "The local public key is unavailable.");
assert(serviceKey, "The local service key is unavailable.");

const owner = makeClient(apiUrl, publicKey);
const viewer = makeClient(apiUrl, publicKey);
const anonymous = makeClient(apiUrl, publicKey);
const admin = makeClient(apiUrl, serviceKey);
let ownerId;
let viewerId;
let sourcePath;
let displayPath;
let crossUserSourcePath;
let crossUserDisplayPath;
let channel;

try {
  ownerId = await createVerificationUser(owner, "owner");
  await delay(1_100);
  viewerId = await createVerificationUser(viewer, "viewer");

  const ownerProfile = requireResult(
    await owner.from("profiles").select("user_id, visibility, media_namespace").eq("user_id", ownerId).single(),
    "Auth profile trigger verification failed",
  );
  assert(ownerProfile.user_id === ownerId, "Auth signup did not create the owner profile.");
  assert(ownerProfile.visibility === "private", "A newly created profile did not default to Private.");
  assert(/^fan-media-[0-9a-f]{32}$/.test(ownerProfile.media_namespace), "The owner profile is missing its opaque media namespace.");

  requireResult(
    await owner.rpc("set_my_fanatical_name", { fanatical_name_value: ownerName }),
    "Fanatical Name setup failed",
  );

  sourcePath = `${ownerId}/avatar/local-verification-source.png`;
  displayPath = `${ownerProfile.media_namespace}/avatar/local-verification-display.webp`;
  crossUserSourcePath = `${ownerId}/avatar/cross-user-insert.png`;
  crossUserDisplayPath = `${ownerProfile.media_namespace}/avatar/cross-user-insert.webp`;
  const sourceBytes = new Blob([Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10])], { type: "image/png" });
  const displayBytes = new Blob([Uint8Array.from([82, 73, 70, 70, 0, 0, 0, 0])], { type: "image/webp" });
  const updatedSourceBytes = new Blob([Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10, 1])], { type: "image/png" });
  const updatedDisplayBytes = new Blob([Uint8Array.from([82, 73, 70, 70, 1, 0, 0, 0])], { type: "image/webp" });

  requireResult(
    await owner.storage.from(bucket).upload(sourcePath, sourceBytes, { contentType: "image/png", upsert: false }),
    "Owner source upload failed",
  );
  requireResult(
    await owner.storage.from(bucket).upload(displayPath, displayBytes, { contentType: "image/webp", upsert: false }),
    "Owner display upload failed",
  );
  requireDenied(
    await viewer.storage.from(bucket).upload(crossUserSourcePath, sourceBytes, { contentType: "image/png", upsert: false }),
    "A non-owner inserted media into another fan's UUID source namespace.",
  );
  requireDenied(
    await viewer.storage.from(bucket).upload(crossUserDisplayPath, displayBytes, { contentType: "image/webp", upsert: false }),
    "A non-owner inserted media into another fan's opaque display namespace.",
  );
  requireResult(
    await owner.storage.from(bucket).update(sourcePath, updatedSourceBytes, { contentType: "image/png", upsert: false }),
    "Owner source update failed",
  );
  requireResult(
    await owner.storage.from(bucket).update(displayPath, updatedDisplayBytes, { contentType: "image/webp", upsert: false }),
    "Owner display update failed",
  );

  requireDenied(await viewer.storage.from(bucket).download(sourcePath), "Unrecorded source media was readable by a non-owner.");
  requireDenied(await viewer.storage.from(bucket).download(displayPath), "Unrecorded display media was readable by a non-owner.");

  const photo = requireResult(
    await owner.from("profile_photos").insert({
      user_id: ownerId,
      source_path: sourcePath,
      display_path: displayPath,
      source_filename: "local-verification.png",
      source_media_type: "image/png",
      source_width: 1,
      source_height: 1,
    }).select("id").single(),
    "Profile photo record creation failed",
  );
  requireResult(
    await owner.rpc("activate_my_profile_photo", {
      photo_id_value: photo.id,
      focal_x_value: 0.5,
      focal_y_value: 0.5,
      zoom_value: 1,
    }),
    "Profile photo activation failed",
  );
  requireResult(await owner.rpc("set_my_profile_privacy", {
    visibility_value: "members_visible",
    personal_field_visibility_value: {},
  }), "Members-visible profile update failed");

  requireResult(await owner.storage.from(bucket).download(sourcePath), "Owner could not read the original media");
  requireResult(await owner.storage.from(bucket).download(displayPath), "Owner could not read display media");
  requireDenied(await viewer.storage.from(bucket).download(sourcePath), "A non-owner could read original media.");
  requireResult(await viewer.storage.from(bucket).download(displayPath), "A signed-in fan could not read the active opaque avatar derivative");
  requireDenied(await anonymous.storage.from(bucket).download(displayPath), "An anonymous viewer could read profile media.");
  requireDenied(
    await viewer.storage.from(bucket).update(sourcePath, sourceBytes, { contentType: "image/png", upsert: false }),
    "A non-owner updated another fan's UUID source object.",
  );
  requireDenied(
    await viewer.storage.from(bucket).update(displayPath, displayBytes, { contentType: "image/webp", upsert: false }),
    "A non-owner updated another fan's readable opaque display object.",
  );

  requireResult(await owner.storage.from(bucket).createSignedUrl(sourcePath, 60), "Owner could not sign original media");
  requireDenied(await viewer.storage.from(bucket).createSignedUrl(sourcePath, 60), "A non-owner could sign original media.");
  const publicSigned = requireResult(
    await viewer.storage.from(bucket).createSignedUrl(displayPath, 60),
    "A signed-in fan could not sign the active avatar derivative",
  );
  assert(new URL(publicSigned.signedUrl).hostname === "127.0.0.1", "A signed media URL escaped the local stack.");

  const publicProfile = requireResult(
    await viewer.rpc("get_member_profile_by_fanatical_name", { fanatical_name_value: ownerName }),
    "Members-visible profile RPC failed",
  );
  assert(publicProfile?.avatar?.display_path === displayPath, "Members-visible profile RPC omitted the avatar derivative.");
  assert(!JSON.stringify(publicProfile).includes(sourcePath), "Fan-safe profile RPC exposed an original media path.");
  assert(!JSON.stringify(publicProfile).includes(ownerId), "Fan-safe profile RPC exposed an Auth UUID.");
  requireDenied(
    await anonymous.rpc("get_member_profile_by_fanatical_name", { fanatical_name_value: ownerName }),
    "An anonymous viewer could execute the member profile reader.",
  );

  requireResult(await owner.rpc("set_my_profile_privacy", {
    visibility_value: "private",
    personal_field_visibility_value: {},
  }), "Private profile update failed");
  requireResult(await viewer.storage.from(bucket).download(displayPath), "Private attribution lost its active avatar derivative.");
  requireDenied(await anonymous.storage.from(bucket).download(displayPath), "An anonymous viewer could read private display media.");
  requireResult(await viewer.storage.from(bucket).createSignedUrl(displayPath, 60), "A signed-in fan could not sign a Private attribution avatar.");
  const privateProfile = requireResult(
    await viewer.rpc("get_member_profile_by_fanatical_name", { fanatical_name_value: ownerName }),
    "Private viewer profile RPC failed",
  );
  assert(
    privateProfile?.fanatical_name === ownerName
      && privateProfile.visibility === "private"
      && privateProfile.is_private === true
      && privateProfile.avatar?.display_path === displayPath,
    "Private profile attribution was not returned through the fan-safe boundary.",
  );
  assert(
    privateProfile
      && !("display_name" in privateProfile)
      && !("tagline" in privateProfile)
      && !("personal_fields" in privateProfile)
      && !JSON.stringify(privateProfile).includes(ownerId),
    "Private profile payload exposed member-only or protected data.",
  );
  requireResult(await owner.storage.from(bucket).download(sourcePath), "Private owner lost original media access");
  requireResult(await owner.storage.from(bucket).download(displayPath), "Private owner lost display media access");

  let resolveRealtime;
  const realtimeEvent = new Promise((resolvePromise) => {
    resolveRealtime = resolvePromise;
  });
  const realtimeTaglinePrefix = `Local Realtime ${runId}`;
  channel = owner
    .channel(`local-verification-${runId}`)
    .on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "profiles", filter: `user_id=eq.${ownerId}` },
      (payload) => {
        if (payload.new?.tagline?.startsWith(realtimeTaglinePrefix)) resolveRealtime(payload);
      },
    );
  await waitForRealtimeSubscription(channel);
  let realtimeDelivered = false;
  for (let attempt = 1; attempt <= 4 && !realtimeDelivered; attempt += 1) {
    await delay(attempt === 1 ? 3_000 : 1_000);
    requireResult(
      await owner.from("profiles").update({ tagline: `${realtimeTaglinePrefix}-${attempt}` }).eq("user_id", ownerId),
      "Realtime source update failed",
    );
    realtimeDelivered = await Promise.race([
      realtimeEvent.then(() => true),
      delay(4_000).then(() => false),
    ]);
  }
  assert(realtimeDelivered, "Realtime change event timed out.");

  await viewer.storage.from(bucket).remove([sourcePath]);
  requireResult(
    await owner.storage.from(bucket).download(sourcePath),
    "A non-owner delete attempt removed another fan's UUID source object.",
  );
  await viewer.storage.from(bucket).remove([displayPath]);
  requireResult(
    await owner.storage.from(bucket).download(displayPath),
    "A non-owner delete attempt removed another fan's opaque display object.",
  );
  requireResult(await owner.storage.from(bucket).remove([sourcePath]), "Owner source delete failed");
  requireResult(await owner.storage.from(bucket).remove([displayPath]), "Owner display delete failed");
  requireDenied(await owner.storage.from(bucket).download(sourcePath), "Owner source delete left the object readable.");
  requireDenied(await owner.storage.from(bucket).download(displayPath), "Owner display delete left the object readable.");

  assert(requestedUrls.length > 0, "No local integration requests were observed.");
  assert(
    requestedUrls.every((url) => new URL(url).hostname !== productionHostname),
    "A hosted Supabase request was observed.",
  );

  console.log("Passed local Auth signup/session/profile trigger verification.");
  console.log("Passed opaque profile-media, owner/cross-user Storage writes, signed-in attribution, Private payload, and signed-URL verification.");
  console.log("Passed local Realtime subscription and database-change delivery verification.");
  console.log(`Observed ${requestedUrls.length} Supabase HTTP requests; hosted production requests: 0.`);
} finally {
  if (channel) await owner.removeChannel(channel);
  if (sourcePath || displayPath || crossUserSourcePath || crossUserDisplayPath) {
    await admin.storage.from(bucket).remove(
      [sourcePath, displayPath, crossUserSourcePath, crossUserDisplayPath].filter(Boolean),
    );
  }
  for (const userId of [ownerId, viewerId].filter(Boolean)) {
    await admin.auth.admin.deleteUser(userId);
  }
  await Promise.all([owner.auth.signOut(), viewer.auth.signOut(), anonymous.auth.signOut(), admin.auth.signOut()]);
  globalThis.fetch = originalFetch;
}
