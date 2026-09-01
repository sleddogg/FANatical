import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  localAcceptanceDataset,
  localAcceptanceFan,
  localPhase5AcceptanceAccounts,
  localPhase5AcceptanceFixtureMetadataKey,
  localPhase5AcceptanceFixtureVersion,
} from "./local-acceptance-fixtures.mjs";
import { requireLoopbackSupabaseApiUrl } from "./local-supabase-safety.mjs";

const appDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryDirectory = resolve(appDirectory, "..");
const localSupabaseScript = resolve(appDirectory, "scripts/local-supabase.mjs");
const supabaseCliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");

function run(command, arguments_, label) {
  const result = spawnSync(command, arguments_, {
    cwd: appDirectory,
    encoding: "utf8",
    maxBuffer: 30 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.error) throw new Error(`${label}: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${label}:\n${[result.stdout, result.stderr].filter(Boolean).join("\n").trim()}`);
  return result.stdout.trim();
}

function runBackend(action) {
  return run(process.execPath, [localSupabaseScript, action], `backend:${action} failed`);
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
  return parseEnvironment(run(
    process.execPath,
    [supabaseCliPath, "status", "-o", "env", "--workdir", repositoryDirectory],
    "Could not inspect local Supabase",
  ));
}

function localClient(url, key) {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

async function rpc(client, name, arguments_) {
  const result = await client.rpc(name, arguments_);
  if (result.error) throw new Error(`${name} failed: ${result.error.message}`);
  return result.data ?? [];
}

function wait(milliseconds) {
  return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));
}

async function retryLocalRead(action, label) {
  let lastError;
  for (let attempt = 1; attempt <= 12; attempt += 1) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      const message = error instanceof Error ? error.message : String(error);
      if (!/fetch failed|ECONNREFUSED|socket hang up/i.test(message)) throw error;
      if (attempt < 12) await wait(500);
    }
  }
  throw new Error(`${label}: ${lastError instanceof Error ? lastError.message : String(lastError)}`);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertJson(actual, expected, message) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}\nExpected: ${JSON.stringify(expected)}\nActual: ${JSON.stringify(actual)}`);
  }
}

function runLocalSql(sql) {
  return run(
    "docker",
    ["exec", "-i", "supabase_db_fanatical-local", "psql", "-U", "postgres", "-d", "postgres", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
    "Could not inspect the local fixture database",
  );
}

function fixtureSnapshot() {
  const headlines = localAcceptanceDataset.items.map((item) => `'${item.headline.replaceAll("'", "''")}'`).join(",");
  const marker = localAcceptanceDataset.marker.replaceAll("'", "''");
  const sourceId = localAcceptanceDataset.publisher.sourceId.replaceAll("'", "''");
  const output = runLocalSql(`
    with fixture_source as (
      select id from public.trusted_sources where source_id = '${sourceId}'
    ), fixture_cases as (
      select id from public.news_identity_resolution_cases
      where context ->> 'local_acceptance_fixture_key' like '${marker}:%'
    ), fixture_decisions as (
      select * from public.news_identity_resolution_decisions
      where case_id in (select id from fixture_cases) and action = 'confirm_create'
    ), fixture_items as (
      select distinct news_item_id from public.news_item_versions
      where is_current and headline in (${headlines})
    ), fixture_manifestations as (
      select id from public.news_manifestations
      where source_reference like '${marker}:%'
    ), fixture_urls as (
      select id from public.news_manifestation_urls
      where manifestation_id in (select id from fixture_manifestations)
    ), fixture_classifications as (
      select id from public.news_item_classifications
      where news_item_id in (select news_item_id from fixture_items)
    ), fixture_previews as (
      select id from public.news_remote_preview_references
      where manifestation_id in (select id from fixture_manifestations)
    )
    select json_build_object(
      'publisher', (select count(*) from fixture_source),
      'approved_publishers', (select count(*) from public.trusted_sources where id in (select id from fixture_source) and review_status = 'approved' and independence_group_id is not null),
      'approved_publisher_scopes', (select count(*) from public.trusted_source_url_scope_versions where source_id in (select id from fixture_source) and is_current and review_status = 'approved'),
      'identity_cases', (select count(*) from fixture_cases),
      'identity_decisions', (select count(*) from fixture_decisions),
      'staff_identity_decisions', (select count(*) from fixture_decisions where decision_origin = 'staff' and decided_by_user_id is not null),
      'organizations', (select count(*) from fixture_decisions where result_organizational_contributor_id is not null),
      'shows', (select count(*) from fixture_decisions where result_show_id is not null),
      'evidence', (select count(*) from public.news_content_evidence where publisher_source_id in (select id from fixture_source)),
      'items', (select count(*) from fixture_items),
      'item_versions', (select count(*) from public.news_item_versions where news_item_id in (select news_item_id from fixture_items)),
      'podcast_episodes', (select count(*) from public.news_podcast_episodes where news_item_id in (select news_item_id from fixture_items)),
      'manifestations', (select count(*) from fixture_manifestations),
      'urls', (select count(*) from fixture_urls),
      'assignments', (select count(*) from public.news_manifestation_assignment_versions where manifestation_id in (select id from fixture_manifestations)),
      'destinations', (select count(*) from public.news_representative_destination_versions where news_item_id in (select news_item_id from fixture_items)),
      'bylines', (select count(*) from public.news_byline_mentions where manifestation_id in (select id from fixture_manifestations)),
      'byline_resolutions', (select count(*) from public.news_byline_resolution_versions where byline_mention_id in (select id from public.news_byline_mentions where manifestation_id in (select id from fixture_manifestations))),
      'classifications', (select count(*) from fixture_classifications),
      'classification_versions', (select count(*) from public.news_item_classification_versions where classification_id in (select id from fixture_classifications)),
      'previews', (select count(*) from fixture_previews),
      'preview_policies', (select count(*) from public.news_remote_preview_policy_versions where preview_reference_id in (select id from fixture_previews)),
      'pending_preview_policies', (select count(*) from public.news_remote_preview_policy_versions where preview_reference_id in (select id from fixture_previews) and is_current and publisher_policy_state = 'pending_review'),
      'followability_versions', (select count(*) from public.news_followable_identity_versions where organizational_contributor_id in (select result_organizational_contributor_id from fixture_decisions) or show_id in (select result_show_id from fixture_decisions)),
      'current_followability', (select count(*) from public.news_followable_identity_versions where is_current and followable and (organizational_contributor_id in (select result_organizational_contributor_id from fixture_decisions) or show_id in (select result_show_id from fixture_decisions))),
      'demo_versions', (select count(*) from public.news_demo_configuration_versions),
      'current_demo_versions', (select count(*) from public.news_demo_configuration_versions where is_current),
      'demo_members', (select count(*) from public.news_demo_configuration_identities),
      'current_demo_members', (select count(*) from public.news_demo_configuration_identities where configuration_version_id in (select id from public.news_demo_configuration_versions where is_current)),
      'fixture_actors', (select count(*) from public.catalog_actors where actor_key = 'local-acceptance-fixture-operator'),
      'fixture_operator_staff_roles', (select count(*) from public.staff_roles role join public.catalog_actors actor on actor.auth_user_id = role.user_id where actor.actor_key = 'local-acceptance-fixture-operator')
    );
  `);
  return JSON.parse(output);
}

function expectedSnapshot() {
  return {
    publisher: 1,
    approved_publishers: 1,
    approved_publisher_scopes: 1,
    identity_cases: 3,
    identity_decisions: 3,
    staff_identity_decisions: 3,
    organizations: 2,
    shows: 1,
    evidence: 15,
    items: 3,
    item_versions: 3,
    podcast_episodes: 1,
    manifestations: 3,
    urls: 3,
    assignments: 3,
    destinations: 3,
    bylines: 3,
    byline_resolutions: 3,
    classifications: 3,
    classification_versions: 3,
    previews: 3,
    preview_policies: 3,
    pending_preview_policies: 3,
    followability_versions: 3,
    current_followability: 3,
    demo_versions: 1,
    current_demo_versions: 1,
    demo_members: 2,
    current_demo_members: 2,
    fixture_actors: 1,
    fixture_operator_staff_roles: 0,
  };
}

function phase5AccountSnapshot() {
  const accountEmails = localPhase5AcceptanceAccounts
    .map((account) => `'${account.email.replaceAll("'", "''")}'`)
    .join(",");
  const output = runLocalSql(`
    with acceptance_users as (
      select id, lower(email) as email
      from auth.users
      where lower(email) in (${accountEmails})
    ), brad as (
      select id from acceptance_users where email = 'brad@fanatical.invalid'
    ), test_fan as (
      select id from acceptance_users where email = 'testfan@fanatical.invalid'
    ), moderator as (
      select id from acceptance_users where email = 'moderator@fanatical.invalid'
    )
    select json_build_object(
      'accounts', (select count(*) from acceptance_users),
      'initialized_fans', (
        select count(*)
        from auth.users auth_user
        where auth_user.id in ((select id from brad), (select id from test_fan))
          and auth_user.raw_app_meta_data ->> '${localPhase5AcceptanceFixtureMetadataKey.replaceAll("'", "''")}'
            = '${localPhase5AcceptanceFixtureVersion.replaceAll("'", "''")}'
      ),
      'brad_handle', (select profile.handle from public.profiles profile where profile.user_id = (select id from brad)),
      'brad_visibility', (select profile.visibility from public.profiles profile where profile.user_id = (select id from brad)),
      'brad_personal_fields', (select profile.personal_field_visibility from public.profiles profile where profile.user_id = (select id from brad)),
      'test_handle', (select profile.handle from public.profiles profile where profile.user_id = (select id from test_fan)),
      'test_visibility', (select profile.visibility from public.profiles profile where profile.user_id = (select id from test_fan)),
      'test_personal_fields', (select profile.personal_field_visibility from public.profiles profile where profile.user_id = (select id from test_fan)),
      'fan_team_follows', (select count(*) from public.user_followed_teams followed where followed.user_id in ((select id from brad), (select id from test_fan)) and followed.team_id = 'hockey-000027'),
      'fan_news_follows', (select count(*) from public.user_news_identity_follows followed where followed.user_id in ((select id from brad), (select id from test_fan)) and followed.is_current),
      'moderator_handle', (select profile.handle from public.profiles profile where profile.user_id = (select id from moderator)),
      'moderator_visibility', (select profile.visibility from public.profiles profile where profile.user_id = (select id from moderator)),
      'moderator_role', (select role.role from public.staff_roles role where role.user_id = (select id from moderator) and role.is_active),
      'moderator_permissions', (select role.permissions from public.staff_roles role where role.user_id = (select id from moderator) and role.is_active),
      'moderator_service_actor', (select count(*) from public.catalog_actors actor where actor.auth_user_id = (select id from moderator) and actor.actor_key = 'local_phase5a_moderator' and actor.actor_type = 'service' and actor.active),
      'moderator_fan_population', (select count(*) from private.fan_profile_population population where population.user_id = (select id from moderator)),
      'acceptance_comments', (select count(*) from public.community_comments comment where comment.author_user_id in (select id from acceptance_users)),
      'acceptance_hides', (select count(*) from public.community_hide_intents intent where intent.hider_id in (select id from acceptance_users) or intent.hidden_id in (select id from acceptance_users)),
      'acceptance_requests', (select count(*) from public.user_news_follow_requests request where request.user_id in (select id from acceptance_users))
    );
  `);
  return JSON.parse(output);
}

function expectedPhase5AccountSnapshot() {
  return {
    accounts: 3,
    initialized_fans: 2,
    brad_handle: "Brad",
    brad_visibility: "members_visible",
    brad_personal_fields: {},
    test_handle: "TestFan",
    test_visibility: "private",
    test_personal_fields: {},
    fan_team_follows: 2,
    fan_news_follows: 4,
    moderator_handle: "",
    moderator_visibility: "private",
    moderator_role: "admin",
    moderator_permissions: ["community_moderate"],
    moderator_service_actor: 1,
    moderator_fan_population: 0,
    acceptance_comments: 0,
    acceptance_hides: 0,
    acceptance_requests: 0,
  };
}

async function verifyPhase5AccountAccess(status) {
  const apiUrl = requireLoopbackSupabaseApiUrl(status.get("API_URL"));
  const publicKey = status.get("PUBLISHABLE_KEY") ?? status.get("ANON_KEY");
  if (!publicKey) throw new Error("Local Supabase did not report its browser-safe key.");

  for (const account of localPhase5AcceptanceAccounts) {
    const client = localClient(apiUrl, publicKey);
    const signedIn = await client.auth.signInWithPassword({
      email: account.email,
      password: account.password,
    });
    if (signedIn.error || signedIn.data.user?.email !== account.email) {
      throw new Error(`${account.displayName} sign-in failed${signedIn.error ? `: ${signedIn.error.message}` : "."}`);
    }

    if (account.operationalActorKey) {
      await rpc(client, "get_community_moderation_queue", {});
      await rpc(client, "get_news_follow_request_queue", {});
    } else {
      const following = await rpc(client, "get_my_news_following", {});
      assert(following.length === 2, `${account.displayName} does not have the two governed acceptance News follows.`);
      const profile = await rpc(client, "get_member_profile_by_fanatical_name", {
        fanatical_name_value: account.fanaticalName,
      });
      assert(profile?.fanatical_name === account.fanaticalName, `${account.displayName}'s fan-safe profile is unavailable.`);
    }

    const signedOut = await client.auth.signOut();
    if (signedOut.error) throw new Error(`Could not sign out ${account.displayName}: ${signedOut.error.message}`);
  }
}

async function anonymousBaseline(status) {
  const apiUrl = requireLoopbackSupabaseApiUrl(status.get("API_URL"));
  const publicKey = status.get("PUBLISHABLE_KEY") ?? status.get("ANON_KEY");
  if (!publicKey) throw new Error("Local Supabase did not report its browser-safe key.");
  const anonymous = localClient(apiUrl, publicKey);
  const universe = await retryLocalRead(
    () => rpc(anonymous, "get_news_demo_universe", {}),
    "The anonymous Demo universe did not become ready after local restart",
  );
  assertJson(
    universe.map(({ target_type, display_name, ordinal }) => ({ target_type, display_name, ordinal })),
    localAcceptanceDataset.demoIdentities.map((identity, index) => ({
      target_type: identity.type,
      display_name: identity.displayName,
      ordinal: index + 1,
    })),
    "The anonymous Demo universe does not exactly match the governed fixture identities.",
  );
  assert(universe.every((identity) => typeof identity.target_id === "string" && identity.target_id.length > 0), "A Demo identity is missing its governed public ID.");

  const feed = await retryLocalRead(
    () => rpc(anonymous, "get_news_demo_feed", {
      selected_targets_value: universe.map((identity) => ({
        target_type: identity.target_type,
        target_id: identity.target_id,
      })),
      filter_kind_value: "all",
      page_size_value: 20,
    }),
    "The anonymous Demo feed did not become ready after local restart",
  );
  assertJson(feed.map((item) => item.headline), localAcceptanceDataset.items.map((item) => item.headline), "The anonymous Demo feed does not contain exactly the three expected Items.");
  for (const [index, item] of feed.entries()) {
    const definition = localAcceptanceDataset.items[index];
    const identityDefinition = localAcceptanceDataset.identities.find((identity) => identity.key === definition.identityKey);
    const identity = universe.find((candidate) => candidate.display_name === identityDefinition.displayName);
    assert(item.item_kind === definition.kind, `${definition.headline} has the wrong Item kind.`);
    assert(item.destination_url === definition.destinationUrl, `${definition.headline} has the wrong representative destination.`);
    assert(item.publisher_id === localAcceptanceDataset.publisher.sourceId, `${definition.headline} has the wrong publisher.`);
    assert(item.preview_url === null && item.preview_kind === null && item.preview_alt_text === null, `${definition.headline} exposed a pending-review preview.`);
    assert(Array.isArray(item.bylines) && item.bylines.length === 1, `${definition.headline} is missing its governed attribution.`);
    assert(item.bylines[0].target_type === identity.target_type && item.bylines[0].target_id === identity.target_id, `${definition.headline} has the wrong byline target.`);
    assert(Array.isArray(item.classifications) && item.classifications.some((classification) => (
      classification.target_type === definition.classification.type
      && classification.target_public_id === definition.classification.publicId
    )), `${definition.headline} is missing its governed classification.`);
  }
  return { universe, feed };
}

async function signIn(status) {
  const apiUrl = requireLoopbackSupabaseApiUrl(status.get("API_URL"));
  const publicKey = status.get("PUBLISHABLE_KEY") ?? status.get("ANON_KEY");
  if (!publicKey) throw new Error("Local Supabase did not report its browser-safe key.");
  const client = localClient(apiUrl, publicKey);
  const result = await retryLocalRead(async () => {
    const attempt = await client.auth.signInWithPassword({
      email: localAcceptanceFan.email,
      password: localAcceptanceFan.password,
    });
    if (attempt.error && /fetch failed|ECONNREFUSED|socket hang up/i.test(attempt.error.message)) {
      throw attempt.error;
    }
    return attempt;
  }, "Dummy Fan authentication did not become ready after local restart");
  if (result.error || !result.data.user) throw new Error(`Dummy Fan sign-in failed${result.error ? `: ${result.error.message}` : "."}`);
  return { client, user: result.data.user };
}

async function main() {
  console.log("Rebuilding the deterministic loopback-only acceptance baseline...");
  runBackend("reset");
  let status = localStatus();
  const baseline = await anonymousBaseline(status);
  assertJson(fixtureSnapshot(), expectedSnapshot(), "The reset fixture row counts are not exact.");
  assertJson(
    phase5AccountSnapshot(),
    expectedPhase5AccountSnapshot(),
    "The Phase 5A Brad/Test/Moderator baseline is not exact.",
  );
  await verifyPhase5AccountAccess(status);

  const before = await signIn(status);
  const followed = await rpc(before.client, "follow_news_identity", {
    target_type_value: baseline.universe[0].target_type,
    target_public_id_value: baseline.universe[0].target_id,
    sport_scope_ids_value: [],
    team_scope_ids_value: [],
  });
  assert(typeof followed === "string", "The preservation proof could not create a real fan follow.");
  await rpc(before.client, "dismiss_news_item", { news_item_public_id_value: baseline.feed[0].news_item_id });
  const userId = before.user.id;
  await before.client.auth.signOut();
  const sharedBeforeRestart = fixtureSnapshot();

  const bradAccount = localPhase5AcceptanceAccounts.find((account) => account.key === "brad");
  if (!bradAccount) throw new Error("The Brad acceptance account definition is missing.");
  const bradClient = localClient(
    requireLoopbackSupabaseApiUrl(status.get("API_URL")),
    status.get("PUBLISHABLE_KEY") ?? status.get("ANON_KEY"),
  );
  const bradSignIn = await bradClient.auth.signInWithPassword({
    email: bradAccount.email,
    password: bradAccount.password,
  });
  if (bradSignIn.error) throw new Error(`Brad preservation setup failed: ${bradSignIn.error.message}`);
  await rpc(bradClient, "set_my_profile_privacy", {
    visibility_value: "private",
    personal_field_visibility_value: {},
  });
  await bradClient.auth.signOut();
  const phase5BeforeRestart = phase5AccountSnapshot();
  assert(phase5BeforeRestart.brad_visibility === "private", "The Brad preservation proof did not change account-owned privacy.");

  const escapedFixtureMetadataKey = localPhase5AcceptanceFixtureMetadataKey.replaceAll("'", "''");
  runLocalSql(`
    update auth.users
    set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) - '${escapedFixtureMetadataKey}'
    where lower(email) = 'testfan@fanatical.invalid';
    update public.profiles
    set handle = '', visibility = 'members_visible'
    where user_id = (select id from auth.users where lower(email) = 'testfan@fanatical.invalid');
    delete from public.user_followed_teams
    where user_id = (select id from auth.users where lower(email) = 'testfan@fanatical.invalid')
      and team_id = 'hockey-000027';
  `);
  const interruptedPhase5 = phase5AccountSnapshot();
  assert(
    interruptedPhase5.initialized_fans === 1
      && interruptedPhase5.test_handle === ""
      && interruptedPhase5.test_visibility === "members_visible"
      && interruptedPhase5.fan_team_follows === 1,
    "The interrupted Phase 5A provisioning proof did not create an incomplete unmarked account.",
  );

  assert(/^[0-9a-f-]{36}$/i.test(userId), "Dummy Fan has an invalid local Auth user ID.");
  runLocalSql(`insert into public.staff_roles(user_id, role, permissions, is_active) values ('${userId}'::uuid, 'admin', array[]::text[], true) on conflict (user_id) do update set role = 'admin', permissions = array[]::text[], is_active = true;`);
  assert(
    fixtureSnapshot().fixture_operator_staff_roles === 1,
    "The stale-authority recovery proof could not create its interrupted-run residue.",
  );

  console.log("Restarting provisioning to prove stale-authority removal, activity preservation, and shared-fixture idempotence...");
  runBackend("stop");
  runBackend("start");
  status = localStatus();
  await anonymousBaseline(status);
  assertJson(fixtureSnapshot(), sharedBeforeRestart, "Repeated backend:start duplicated or revised shared acceptance fixtures.");
  assertJson(
    phase5AccountSnapshot(),
    phase5BeforeRestart,
    "backend:start did not preserve completed Phase 5A state while repairing the interrupted account.",
  );
  await verifyPhase5AccountAccess(status);
  const after = await signIn(status);
  assert(after.user.id === userId, "backend:start replaced the standing Dummy Fan account.");
  const following = await rpc(after.client, "get_my_news_following", {});
  assert(following.length === 1 && following[0].target_id === baseline.universe[0].target_id, "backend:start did not preserve the Dummy Fan follow.");
  const personalFeed = await rpc(after.client, "get_my_news_feed", { filter_kind_value: "all" });
  assert(!personalFeed.some((item) => item.news_item_id === baseline.feed[0].news_item_id), "backend:start did not preserve the Dummy Fan dismissal.");
  await after.client.auth.signOut();

  console.log("Restoring the clean deterministic baseline after the preservation proof...");
  runBackend("reset");
  status = localStatus();
  await anonymousBaseline(status);
  assertJson(fixtureSnapshot(), expectedSnapshot(), "The final clean acceptance baseline is not exact.");
  assertJson(
    phase5AccountSnapshot(),
    expectedPhase5AccountSnapshot(),
    "The final clean Phase 5A account baseline is not exact.",
  );
  await verifyPhase5AccountAccess(status);
  console.log("Local acceptance reset/restart proof passed.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
