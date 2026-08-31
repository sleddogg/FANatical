import { createClient } from "@supabase/supabase-js";
import { withTemporaryFixtureAuthority } from "./local-fixture-authority.mjs";
import { requireLoopbackSupabaseApiUrl } from "./local-supabase-safety.mjs";

export const localAcceptanceFan = Object.freeze({
  email: "dummy@fanatical.invalid",
  password: "dummy123",
  displayName: "Dummy Fan",
});

const fixtureMarker = "fanatical-local-acceptance-v1";
const publisher = Object.freeze({
  sourceId: "fanatical-local-demo-publisher",
  displayName: "FANatical Local Demo Publisher",
  baseUrl: "https://local-demo.fanatical.invalid/",
  hostname: "local-demo.fanatical.invalid",
  independenceGroupId: "fanatical-local-demo-independent",
  independenceGroupName: "FANatical Local Demo Independent Publisher",
});

export const localAcceptanceIdentities = Object.freeze([
  Object.freeze({
    key: "demo-desk",
    type: "organization",
    displayName: "FANatical Local Demo Desk",
    profileUrl: `${publisher.baseUrl}contributors/demo-desk`,
  }),
  Object.freeze({
    key: "demo-podcast",
    type: "show",
    displayName: "FANatical Local Demo Podcast",
    profileUrl: `${publisher.baseUrl}shows/demo-podcast`,
  }),
]);

export const localAcceptanceItems = Object.freeze([
  Object.freeze({
    key: "written-opening-night",
    kind: "written",
    manifestationKind: "written_article",
    headline: "Demo Desk: Oilers set their opening-night focus",
    summary: "A controlled local written Item that demonstrates Team-classified chronological News.",
    publicationTime: "2026-08-29T18:00:00.000Z",
    destinationUrl: `${publisher.baseUrl}articles/oilers-opening-night-focus`,
    previewUrl: `${publisher.baseUrl}previews/oilers-opening-night-focus.jpg`,
    identityKey: "demo-desk",
    classification: Object.freeze({ type: "team", publicId: "hockey-000027" }),
  }),
  Object.freeze({
    key: "written-league-notebook",
    kind: "written",
    manifestationKind: "written_article",
    headline: "Demo Desk: NHL notebook tracks the week ahead",
    summary: "A controlled local written Item that demonstrates Competition-classified chronological News.",
    publicationTime: "2026-08-29T17:00:00.000Z",
    destinationUrl: `${publisher.baseUrl}articles/nhl-week-ahead`,
    previewUrl: `${publisher.baseUrl}previews/nhl-week-ahead.jpg`,
    identityKey: "demo-desk",
    classification: Object.freeze({ type: "competition", publicId: "hockey-nhl" }),
  }),
  Object.freeze({
    key: "podcast-morning-skate",
    kind: "podcast_episode",
    manifestationKind: "podcast_episode_page",
    headline: "Local Demo Podcast: Morning skate briefing",
    summary: "A controlled local podcast Item that demonstrates governed Show attribution and preview suppression.",
    publicationTime: "2026-08-29T16:00:00.000Z",
    destinationUrl: `${publisher.baseUrl}podcasts/morning-skate-briefing`,
    previewUrl: `${publisher.baseUrl}previews/morning-skate-briefing.jpg`,
    identityKey: "demo-podcast",
    classification: Object.freeze({ type: "sport", publicId: "hockey" }),
  }),
]);

export const localAcceptanceDataset = Object.freeze({
  marker: fixtureMarker,
  publisher,
  identities: localAcceptanceIdentities,
  items: localAcceptanceItems,
});

function localClient(url, key) {
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

function fail(label, error) {
  throw new Error(`${label}: ${error.message}`);
}

async function rpc(client, name, arguments_, label = `Could not call ${name}`) {
  const result = await client.rpc(name, arguments_);
  if (result.error) fail(label, result.error);
  return result.data;
}

async function rows(query, label) {
  const result = await query;
  if (result.error) fail(label, result.error);
  return result.data ?? [];
}

async function maybeOne(query, label) {
  const result = await query.maybeSingle();
  if (result.error) fail(label, result.error);
  return result.data;
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label} drifted from the deterministic local acceptance fixture.`);
  }
}

async function ensurePublisher(admin, staff) {
  await rpc(staff, "admin_upsert_source_independence_group", {
    group_id_value: publisher.independenceGroupId,
    display_name_value: publisher.independenceGroupName,
    notes_value: "Synthetic loopback-only acceptance publisher ownership group.",
  });

  let source = await maybeOne(
    admin.from("trusted_sources")
      .select("id, source_id, display_name, base_url, review_status, independence_group_id")
      .eq("source_id", publisher.sourceId),
    "Could not inspect the local Demo publisher",
  );
  if (!source) {
    await rpc(staff, "admin_upsert_trusted_source", {
      source_id_value: publisher.sourceId,
      display_name_value: publisher.displayName,
      base_url_value: publisher.baseUrl,
      reference_url_value: null,
      independence_group_value: null,
      review_status_value: "pending_review",
      notes_value: "Synthetic .invalid publisher used only by the deterministic local acceptance dataset.",
      metadata_value: { local_acceptance_fixture: fixtureMarker },
    }, "Could not create the local Demo publisher candidate");
    source = await maybeOne(
      admin.from("trusted_sources")
        .select("id, source_id, display_name, base_url, review_status, independence_group_id")
        .eq("source_id", publisher.sourceId),
      "Could not reload the local Demo publisher",
    );
  }
  if (!source) throw new Error("The local Demo publisher was not created.");
  assertEqual(source.display_name, publisher.displayName, "Local Demo publisher name");
  assertEqual(source.base_url, publisher.baseUrl, "Local Demo publisher base URL");

  const group = await maybeOne(
    admin.from("source_independence_groups").select("id").eq("group_id", publisher.independenceGroupId),
    "Could not inspect the local Demo publisher ownership group",
  );
  if (!group) throw new Error("The local Demo publisher ownership group was not created.");
  if (source.review_status !== "approved" || source.independence_group_id !== group.id) {
    await rpc(staff, "review_trusted_source", {
      source_registry_id: publisher.sourceId,
      independence_group_value: publisher.independenceGroupId,
      review_status_value: "approved",
      ownership_notes_value: "Staff-approved synthetic ownership for loopback-only acceptance.",
    }, "Could not approve the local Demo publisher");
  }

  const scopes = await rows(
    admin.from("trusted_source_url_scope_versions")
      .select("id, review_status")
      .eq("source_id", source.id)
      .eq("hostname", publisher.hostname)
      .eq("include_subdomains", false)
      .eq("path_prefix", "/")
      .eq("path_match", "prefix")
      .eq("scope_kind", "publisher")
      .eq("is_current", true),
    "Could not inspect the local Demo publisher URL scope",
  );
  if (scopes.length > 1) throw new Error("The local Demo publisher has duplicate current URL scopes.");
  if (scopes[0]?.review_status !== "approved") {
    await rpc(staff, "review_trusted_source_url_scope", {
      source_registry_id: publisher.sourceId,
      hostname_value: publisher.hostname,
      include_subdomains_value: false,
      path_prefix_value: "/",
      path_match_value: "prefix",
      scope_kind_value: "publisher",
      review_status_value: "approved",
      notes_value: "Staff-approved synthetic .invalid URL scope for loopback-only acceptance.",
    }, "Could not approve the local Demo publisher URL scope");
  }
  return source.id;
}

async function ensureIdentity(admin, staff, sourceId, definition) {
  const cases = await rows(
    admin.from("news_identity_resolution_cases")
      .select("id, status, context")
      .contains("context", { local_acceptance_fixture_key: `${fixtureMarker}:${definition.key}` }),
    `Could not inspect ${definition.displayName}`,
  );
  if (cases.length > 1) throw new Error(`${definition.displayName} has duplicate governed identity cases.`);
  let identityCase = cases[0];
  if (!identityCase) {
    const caseId = await rpc(staff, "admin_open_news_identity_case", {
      case_kind_value: "identity",
      proposed_identity_type_value: definition.type,
      proposed_name_value: definition.displayName,
      publisher_source_id_value: sourceId,
      subject_person_id_value: null,
      subject_organizational_contributor_id_value: null,
      subject_show_id_value: null,
      subject_contributor_profile_id_value: null,
      raw_byline_value: definition.displayName,
      profile_url_value: definition.profileUrl,
      unresolved_question_value: `Create the governed synthetic local Demo ${definition.type} identity?`,
      context_value: {
        local_acceptance_fixture: fixtureMarker,
        local_acceptance_fixture_key: `${fixtureMarker}:${definition.key}`,
      },
      notes_value: "Opened by the deterministic loopback-only local acceptance provisioner.",
    }, `Could not open the governed identity case for ${definition.displayName}`);
    identityCase = { id: caseId };
  }

  let decision = await maybeOne(
    admin.from("news_identity_resolution_decisions")
      .select("id, result_identity_type, result_organizational_contributor_id, result_show_id")
      .eq("case_id", identityCase.id)
      .eq("action", "confirm_create")
      .order("decided_at", { ascending: false })
      .limit(1),
    `Could not inspect the governed identity decision for ${definition.displayName}`,
  );
  if (!decision) {
    const decisionId = await rpc(staff, "admin_review_news_identity_case", {
      case_id_value: identityCase.id,
      action_value: "confirm_create",
      target_identity_id_value: null,
      action_payload_value: {
        identity_type: definition.type,
        display_name: definition.displayName,
      },
      notes_value: "Staff-approved synthetic identity for the deterministic loopback-only Demo universe.",
    }, `Could not approve ${definition.displayName}`);
    decision = await maybeOne(
      admin.from("news_identity_resolution_decisions")
        .select("id, result_identity_type, result_organizational_contributor_id, result_show_id")
        .eq("id", decisionId),
      `Could not reload the governed identity decision for ${definition.displayName}`,
    );
  }
  if (!decision) throw new Error(`${definition.displayName} has no governed identity decision.`);
  assertEqual(decision.result_identity_type, definition.type, `${definition.displayName} identity type`);

  const internalId = definition.type === "organization"
    ? decision.result_organizational_contributor_id
    : decision.result_show_id;
  if (!internalId) throw new Error(`${definition.displayName} has no resolved governed identity.`);
  const identity = definition.type === "organization"
    ? await maybeOne(
        admin.from("news_organizational_contributors").select("id, contributor_id").eq("id", internalId),
        `Could not inspect ${definition.displayName}`,
      )
    : await maybeOne(
        admin.from("podcast_shows").select("id, show_id").eq("id", internalId),
        `Could not inspect ${definition.displayName}`,
      );
  const version = definition.type === "organization"
    ? await maybeOne(
        admin.from("news_organizational_contributor_versions")
          .select("display_name")
          .eq("organizational_contributor_id", internalId)
          .eq("is_current", true),
        `Could not inspect ${definition.displayName}'s current identity`,
      )
    : await maybeOne(
        admin.from("podcast_show_identity_versions")
          .select("display_name")
          .eq("show_id", internalId)
          .eq("is_current", true),
        `Could not inspect ${definition.displayName}'s current identity`,
      );
  if (!identity || !version) throw new Error(`${definition.displayName} is missing its governed identity record.`);
  assertEqual(version.display_name, definition.displayName, `${definition.displayName} display name`);
  return {
    ...definition,
    internalId,
    publicId: definition.type === "organization" ? identity.contributor_id : identity.show_id,
    decisionId: decision.id,
  };
}

async function ensureEvidence(admin, staff, sourceId, definition, evidenceKind) {
  const evidenceUrl = `${publisher.baseUrl}evidence/${definition.key}/${evidenceKind}`;
  const existing = await rows(
    admin.from("news_content_evidence")
      .select("id")
      .eq("publisher_source_id", sourceId)
      .eq("evidence_kind", evidenceKind)
      .eq("evidence_url", evidenceUrl),
    `Could not inspect ${definition.key} ${evidenceKind} evidence`,
  );
  if (existing.length > 1) throw new Error(`${definition.key} has duplicate ${evidenceKind} evidence.`);
  if (existing[0]) return existing[0].id;
  return rpc(staff, "admin_record_news_content_evidence", {
    evidence_kind_value: evidenceKind,
    evidence_url_value: evidenceUrl,
    publisher_source_id_value: sourceId,
    evidence_summary_value: `Synthetic ${evidenceKind} evidence for ${definition.headline}.`,
    observed_at_value: definition.publicationTime,
    notes_value: "Deterministic loopback-only local acceptance evidence.",
  }, `Could not record ${definition.key} ${evidenceKind} evidence`);
}

async function classificationTargetId(admin, classification) {
  const table = classification.type === "sport"
    ? "catalog_sports"
    : classification.type === "competition"
      ? "catalog_competitions"
      : "catalog_teams";
  const publicColumn = classification.type === "sport"
    ? "sport_id"
    : classification.type === "competition"
      ? "competition_id"
      : "team_id";
  const target = await maybeOne(
    admin.from(table).select("id").eq(publicColumn, classification.publicId),
    `Could not resolve ${classification.type} ${classification.publicId}`,
  );
  if (!target) throw new Error(`The governed catalog target ${classification.publicId} is missing.`);
  return target.id;
}

async function ensureItem(admin, staff, sourceId, identities, definition) {
  const identity = identities.find((candidate) => candidate.key === definition.identityKey);
  if (!identity) throw new Error(`Unknown identity fixture ${definition.identityKey}.`);
  const evidence = {};
  for (const kind of [
    "source_publication_time",
    "manifestation_identity",
    "factual_classification",
    "representative_destination",
    "remote_preview_reference",
  ]) {
    evidence[kind] = await ensureEvidence(admin, staff, sourceId, definition, kind);
  }

  const versions = await rows(
    admin.from("news_item_versions")
      .select("news_item_id, headline, summary, publication_state, publication_time")
      .eq("headline", definition.headline)
      .eq("is_current", true),
    `Could not inspect ${definition.headline}`,
  );
  if (versions.length > 1) throw new Error(`${definition.headline} has duplicate News Items.`);
  let itemId = versions[0]?.news_item_id;
  if (versions[0]) {
    assertEqual(versions[0].summary, definition.summary, `${definition.headline} summary`);
    assertEqual(versions[0].publication_state, "published", `${definition.headline} publication state`);
    assertEqual(new Date(versions[0].publication_time).toISOString(), definition.publicationTime, `${definition.headline} publication time`);
    const item = await maybeOne(
      admin.from("news_items").select("item_kind, created_by_decision_id").eq("id", itemId),
      `Could not inspect ${definition.headline}'s Item record`,
    );
    if (!item) throw new Error(`${definition.headline} is missing its Item record.`);
    assertEqual(item.item_kind, definition.kind, `${definition.headline} Item kind`);
    const decision = await maybeOne(
      admin.from("news_content_decisions").select("source_publisher_id").eq("id", item.created_by_decision_id),
      `Could not inspect ${definition.headline}'s creation provenance`,
    );
    assertEqual(decision?.source_publisher_id, sourceId, `${definition.headline} source publisher`);
  } else {
    itemId = await rpc(staff, "admin_create_news_item", {
      item_kind_value: definition.kind,
      headline_value: definition.headline,
      summary_value: definition.summary,
      publication_state_value: "published",
      publication_time_value: definition.publicationTime,
      publication_time_evidence_id_value: evidence.source_publication_time,
      source_publisher_id_value: sourceId,
      show_id_value: definition.kind === "podcast_episode" ? identity.internalId : null,
      episode_identifier_value: definition.kind === "podcast_episode" ? `${fixtureMarker}:${definition.key}` : null,
      notes_value: "Deterministic loopback-only local acceptance Item.",
    }, `Could not create ${definition.headline}`);
  }

  if (definition.kind === "podcast_episode") {
    const episode = await maybeOne(
      admin.from("news_podcast_episodes").select("show_id, episode_identifier").eq("news_item_id", itemId),
      `Could not inspect ${definition.headline}'s podcast episode`,
    );
    if (!episode) throw new Error(`${definition.headline} is missing its podcast episode record.`);
    assertEqual(episode.show_id, identity.internalId, `${definition.headline} Show attribution`);
    assertEqual(episode.episode_identifier, `${fixtureMarker}:${definition.key}`, `${definition.headline} episode identifier`);
  }

  const sourceReference = `${fixtureMarker}:${definition.key}`;
  const manifestations = await rows(
    admin.from("news_manifestations")
      .select("id, publisher_source_id, manifestation_kind")
      .eq("source_reference", sourceReference),
    `Could not inspect ${definition.headline}'s manifestation`,
  );
  if (manifestations.length > 1) throw new Error(`${definition.headline} has duplicate manifestations.`);
  let manifestationId = manifestations[0]?.id;
  if (!manifestationId) {
    manifestationId = await rpc(staff, "admin_create_news_manifestation", {
      publisher_source_id_value: sourceId,
      manifestation_kind_value: definition.manifestationKind,
      first_observed_at_value: definition.publicationTime,
      source_reference_value: sourceReference,
      primary_evidence_id_value: evidence.manifestation_identity,
      notes_value: "Deterministic loopback-only local acceptance manifestation.",
    }, `Could not create ${definition.headline}'s manifestation`);
  } else {
    assertEqual(manifestations[0].publisher_source_id, sourceId, `${definition.headline} manifestation publisher`);
    assertEqual(manifestations[0].manifestation_kind, definition.manifestationKind, `${definition.headline} manifestation kind`);
  }

  const urls = await rows(
    admin.from("news_manifestation_urls")
      .select("id, manifestation_id, url_kind, is_public_destination")
      .eq("url", definition.destinationUrl),
    `Could not inspect ${definition.headline}'s destination URL`,
  );
  if (urls.length > 1) throw new Error(`${definition.headline} has duplicate destination URLs.`);
  let urlId = urls[0]?.id;
  if (!urlId) {
    urlId = await rpc(staff, "admin_add_news_manifestation_url", {
      manifestation_id_value: manifestationId,
      url_kind_value: "canonical",
      url_value: definition.destinationUrl,
      is_public_destination_value: true,
      primary_evidence_id_value: evidence.manifestation_identity,
      notes_value: "Deterministic canonical local acceptance destination.",
    }, `Could not create ${definition.headline}'s destination URL`);
  } else {
    assertEqual(urls[0].manifestation_id, manifestationId, `${definition.headline} destination manifestation`);
    assertEqual(urls[0].url_kind, "canonical", `${definition.headline} destination URL kind`);
    assertEqual(urls[0].is_public_destination, true, `${definition.headline} public destination state`);
  }

  const assignment = await maybeOne(
    admin.from("news_manifestation_assignment_versions")
      .select("news_item_id")
      .eq("manifestation_id", manifestationId)
      .eq("is_current", true),
    `Could not inspect ${definition.headline}'s manifestation assignment`,
  );
  if (!assignment) {
    await rpc(staff, "admin_assign_news_manifestation", {
      manifestation_id_value: manifestationId,
      news_item_id_value: itemId,
      primary_evidence_id_value: evidence.manifestation_identity,
      notes_value: "Deterministic local acceptance manifestation assignment.",
    }, `Could not assign ${definition.headline}'s manifestation`);
  } else {
    assertEqual(assignment.news_item_id, itemId, `${definition.headline} manifestation assignment`);
  }

  const destination = await maybeOne(
    admin.from("news_representative_destination_versions")
      .select("manifestation_id, manifestation_url_id")
      .eq("news_item_id", itemId)
      .eq("is_current", true),
    `Could not inspect ${definition.headline}'s representative destination`,
  );
  if (!destination) {
    await rpc(staff, "admin_set_news_representative_destination", {
      news_item_id_value: itemId,
      manifestation_url_id_value: urlId,
      primary_evidence_id_value: evidence.representative_destination,
      notes_value: "Staff-selected deterministic local acceptance representative destination.",
    }, `Could not set ${definition.headline}'s representative destination`);
  } else {
    assertEqual(destination.manifestation_id, manifestationId, `${definition.headline} representative manifestation`);
    assertEqual(destination.manifestation_url_id, urlId, `${definition.headline} representative URL`);
  }

  let byline = await maybeOne(
    admin.from("news_byline_mentions")
      .select("id, raw_attribution, visible_profile_url")
      .eq("manifestation_id", manifestationId)
      .eq("ordinal", 1),
    `Could not inspect ${definition.headline}'s byline`,
  );
  if (!byline) {
    const bylineId = await rpc(staff, "admin_record_news_byline", {
      manifestation_id_value: manifestationId,
      ordinal_value: 1,
      raw_attribution_value: identity.displayName,
      visible_profile_url_value: identity.profileUrl,
      primary_evidence_id_value: evidence.manifestation_identity,
      notes_value: "Visible synthetic attribution for deterministic local acceptance.",
    }, `Could not record ${definition.headline}'s byline`);
    byline = { id: bylineId, raw_attribution: identity.displayName, visible_profile_url: identity.profileUrl };
  }
  assertEqual(byline.raw_attribution, identity.displayName, `${definition.headline} visible attribution`);
  assertEqual(byline.visible_profile_url, identity.profileUrl, `${definition.headline} visible profile URL`);

  const resolution = await maybeOne(
    admin.from("news_byline_resolution_versions")
      .select("target_identity_type, organizational_contributor_id, show_id, identity_resolution_decision_id")
      .eq("byline_mention_id", byline.id)
      .eq("is_current", true),
    `Could not inspect ${definition.headline}'s byline resolution`,
  );
  if (!resolution) {
    await rpc(staff, "admin_resolve_news_byline", {
      byline_mention_id_value: byline.id,
      target_identity_type_value: identity.type,
      target_identity_id_value: identity.internalId,
      resolution_basis_value: "identity_review",
      identity_resolution_decision_id_value: identity.decisionId,
      notes_value: "Resolved through the staff-approved local acceptance identity case.",
    }, `Could not resolve ${definition.headline}'s byline`);
  } else {
    assertEqual(resolution.target_identity_type, identity.type, `${definition.headline} byline identity type`);
    assertEqual(
      identity.type === "organization" ? resolution.organizational_contributor_id : resolution.show_id,
      identity.internalId,
      `${definition.headline} byline identity`,
    );
    assertEqual(resolution.identity_resolution_decision_id, identity.decisionId, `${definition.headline} identity-review provenance`);
  }

  const classifications = await rows(
    admin.from("news_item_classifications").select("id").eq("news_item_id", itemId),
    `Could not inspect ${definition.headline}'s classifications`,
  );
  let currentClassifications = [];
  if (classifications.length) {
    currentClassifications = await rows(
      admin.from("news_item_classification_versions")
        .select("target_type, sport_id, competition_id, team_id")
        .in("classification_id", classifications.map((candidate) => candidate.id))
        .eq("is_current", true),
      `Could not inspect ${definition.headline}'s current classifications`,
    );
  }
  if (currentClassifications.length > 1) throw new Error(`${definition.headline} has unexpected extra classifications.`);
  const targetId = await classificationTargetId(admin, definition.classification);
  if (!currentClassifications[0]) {
    await rpc(staff, "admin_record_news_classification", {
      news_item_id_value: itemId,
      classification_id_value: null,
      target_type_value: definition.classification.type,
      target_id_value: targetId,
      primary_evidence_id_value: evidence.factual_classification,
      notes_value: "Governed synthetic classification for deterministic local acceptance.",
    }, `Could not classify ${definition.headline}`);
  } else {
    assertEqual(currentClassifications[0].target_type, definition.classification.type, `${definition.headline} classification type`);
    assertEqual(currentClassifications[0][`${definition.classification.type}_id`], targetId, `${definition.headline} classification target`);
  }

  let preview = await maybeOne(
    admin.from("news_remote_preview_references")
      .select("id, preview_kind, alt_text")
      .eq("manifestation_id", manifestationId)
      .eq("remote_url", definition.previewUrl),
    `Could not inspect ${definition.headline}'s remote preview`,
  );
  if (!preview) {
    const previewId = await rpc(staff, "admin_record_news_remote_preview", {
      manifestation_id_value: manifestationId,
      preview_kind_value: definition.kind === "podcast_episode" ? "audio_artwork" : "image",
      remote_url_value: definition.previewUrl,
      publisher_policy_state_value: "pending_review",
      alt_text_value: `Synthetic preview for ${definition.headline}`,
      primary_evidence_id_value: evidence.remote_preview_reference,
      notes_value: "Pending review deliberately proves unapproved previews stay out of the fan read model.",
    }, `Could not record ${definition.headline}'s remote preview`);
    preview = { id: previewId };
  }
  const previewPolicy = await maybeOne(
    admin.from("news_remote_preview_policy_versions")
      .select("publisher_policy_state")
      .eq("preview_reference_id", preview.id)
      .eq("is_current", true),
    `Could not inspect ${definition.headline}'s remote preview policy`,
  );
  if (!previewPolicy) throw new Error(`${definition.headline} is missing its preview policy.`);
  assertEqual(previewPolicy.publisher_policy_state, "pending_review", `${definition.headline} preview policy`);

  return { ...definition, itemId, manifestationId };
}

async function ensureFollowability(staff, identity) {
  const result = await staff.rpc("admin_set_news_identity_followability", {
    target_type_value: identity.type,
    target_public_id_value: identity.publicId,
    followable_value: true,
    rationale_value: "Staff-approved governed identity in the deterministic local Demo universe.",
  });
  if (!result.error || result.error.message.includes("already has the requested followability state")) return;
  fail(`Could not make ${identity.displayName} followable`, result.error);
}

async function ensureDemoUniverse(anonymous, staff, identities) {
  const current = await rpc(anonymous, "get_news_demo_universe", {}, "Could not inspect the anonymous local Demo universe");
  const matches = current.length === identities.length && current.every((member, index) => {
    const identity = identities[index];
    return member.ordinal === index + 1
      && member.target_type === identity.type
      && member.target_id === identity.publicId
      && member.display_name === identity.displayName;
  });
  if (matches) return;
  await rpc(staff, "admin_set_news_demo_universe", {
    targets_value: identities.map((identity) => ({
      target_type: identity.type,
      target_id: identity.publicId,
    })),
    notes_value: "Every governed local Demo identity begins selected on signed-out entry.",
  }, "Could not configure the deterministic local Demo universe");
}

export async function ensureLocalAcceptanceDataset({
  apiUrl: rawApiUrl,
  publicKey,
  serviceKey,
  userId,
  removeTemporaryAuthority,
  grantTemporaryAuthority,
}) {
  const apiUrl = requireLoopbackSupabaseApiUrl(rawApiUrl);
  if (!publicKey || !serviceKey || !userId || !removeTemporaryAuthority || !grantTemporaryAuthority) {
    throw new Error("Local acceptance provisioning credentials are incomplete.");
  }

  const staff = localClient(apiUrl, publicKey);
  const anonymous = localClient(apiUrl, publicKey);
  return withTemporaryFixtureAuthority({
    removeAuthority: () => removeTemporaryAuthority(userId),
    grantAuthority: () => grantTemporaryAuthority(userId),
    provision: async () => {
      const signedIn = await staff.auth.signInWithPassword({
        email: localAcceptanceFan.email,
        password: localAcceptanceFan.password,
      });
      if (signedIn.error || signedIn.data.user?.id !== userId) {
        throw new Error(`Could not authenticate the local fixture operator${signedIn.error ? `: ${signedIn.error.message}` : "."}`);
      }
      await rpc(staff, "admin_upsert_catalog_actor", {
        actor_key_value: "local-acceptance-fixture-operator",
        actor_type_value: "human",
        auth_user_id_value: userId,
        display_name_value: "Local Acceptance Fixture Operator",
        active_value: true,
      }, "Could not prepare the local fixture provenance actor");

      const sourceId = await ensurePublisher(staff, staff);
      const identities = [];
      for (const definition of localAcceptanceIdentities) {
        identities.push(await ensureIdentity(staff, staff, sourceId, definition));
      }
      for (const definition of localAcceptanceItems) {
        await ensureItem(staff, staff, sourceId, identities, definition);
      }
      for (const identity of identities) await ensureFollowability(staff, identity);
      await ensureDemoUniverse(anonymous, staff, identities);
    },
    cleanupOperations: [async () => {
      const signedOut = await staff.auth.signOut();
      if (signedOut.error) {
        throw new Error(`Could not close the local fixture operator session: ${signedOut.error.message}`);
      }
    }],
  });
}
