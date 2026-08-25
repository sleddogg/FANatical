#!/usr/bin/env python3
"""Generate the governed Team Color source-reference seed migration.

The workbook is authoritative for publisher identities, ownership groups,
governance tiers, URL references, and league applicability. It never seeds
Team Color facts, empirical observations, ratings, or information lineages.
Only Python's standard library is used, matching the catalog seed generator.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree import ElementTree as ET
from zipfile import ZipFile


XML_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
IMPORT_KEY = "team-color-source-reference-2026-08-24"
EXPECTED_LEGACY_REDIRECTS = 123


def sql(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def values_rows(rows: list[list[object]]) -> str:
    return ",\n    ".join(
        "(" + ", ".join(sql(value) for value in row) + ")" for row in rows
    )


def workbook_rows(path: Path) -> dict[str, list[dict[str, str]]]:
    with ZipFile(path) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relationships = ET.fromstring(
            archive.read("xl/_rels/workbook.xml.rels")
        )
        targets = {
            relationship.attrib["Id"]: relationship.attrib["Target"].lstrip("/")
            for relationship in relationships
        }
        result: dict[str, list[dict[str, str]]] = {}
        for sheet in workbook.find(XML_NS + "sheets") or []:
            target = targets[sheet.attrib[REL_NS + "id"]]
            target = target if target.startswith("xl/") else "xl/" + target
            root = ET.fromstring(archive.read(target))
            rows: list[dict[str, str]] = []
            for row in root.findall(".//" + XML_NS + "row"):
                values: dict[str, str] = {}
                for cell in row.findall(XML_NS + "c"):
                    column = "".join(
                        character
                        for character in cell.attrib["r"]
                        if character.isalpha()
                    )
                    raw = cell.find(XML_NS + "v")
                    values[column] = ("" if raw is None else raw.text or "").strip()
                rows.append(values)
            result[sheet.attrib["name"]] = rows
        return result


def normalized_url(value: str) -> tuple[str, str]:
    parsed = urlsplit(value.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError(f"Invalid source URL: {value}")
    return parsed.hostname.casefold(), parsed.path.rstrip("/") or "/"


def split_league_ids(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def validate_workbook(
    league_rows: list[dict[str, str]], source_rows: list[dict[str, str]]
) -> None:
    if len(league_rows) != 125:
        raise ValueError(f"Expected 125 league mappings, found {len(league_rows)}")
    if len(source_rows) != 116:
        raise ValueError(f"Expected 116 canonical sources, found {len(source_rows)}")
    if len({row["C"] for row in league_rows}) != 125:
        raise ValueError("League IDs must be unique")
    if len({row["A"] for row in source_rows}) != 116:
        raise ValueError("Canonical source IDs must be unique")

    official = [row for row in source_rows if row["B"] == "Official Tier 1"]
    broad = [row for row in source_rows if row["B"] == "Broad Tier 2"]
    if len(official) != 113 or len(broad) != 3:
        raise ValueError("Expected 113 Official Tier 1 and 3 Broad Tier 2 sources")
    if {row["A"] for row in broad} != {
        "sport-color-codes",
        "trucolor",
        "team-color-codes",
    }:
        raise ValueError("Broad Tier 2 source identities differ from the approved set")
    if len({row["E"] for row in source_rows}) != 116:
        raise ValueError("Each canonical source requires its supplied ownership group")

    source_by_id = {row["A"]: row for row in source_rows}
    mappings_by_source: dict[str, list[dict[str, str]]] = {}
    for row in league_rows:
        mappings_by_source.setdefault(row["D"], []).append(row)
        if row["D"] not in source_by_id:
            raise ValueError(f"League {row['C']} references an unknown source")
        if row["H"] != "1" or row["I"] != "league":
            raise ValueError(f"League {row['C']} does not use approved Tier 1 scope")
        if row["J"].casefold() != "probationary / unrated" or row["K"] != "No":
            raise ValueError(f"League {row['C']} attempts to seed qualification or lineage")
        normalized_url(row["F"])
        normalized_url(row["G"])

    for row in source_rows:
        if row["G"] != "team_colors":
            raise ValueError(f"Source {row['A']} has an unexpected data type")
        if row["I"].casefold() != "probationary / unrated":
            raise ValueError(f"Source {row['A']} attempts to seed qualification")
        if row["B"] == "Official Tier 1":
            mapped = mappings_by_source.get(row["A"], [])
            supplied_ids = split_league_ids(row["K"])
            if row["F"] != "1" or int(row["J"]) != len(mapped):
                raise ValueError(f"Official source {row['A']} has inconsistent counts")
            if supplied_ids != [mapping["C"] for mapping in mapped]:
                raise ValueError(f"Official source {row['A']} changes league mappings")
        elif row["F"] != "2" or row["J"] or row["K"]:
            raise ValueError(f"Broad source {row['A']} has inconsistent scope")
        normalized_url(row["D"])
        normalized_url(row["L"])

    khl = next(row for row in league_rows if row["C"] == "hockey-khl")
    if "permission required" not in khl["L"].casefold() or "do not automate" not in khl["N"].casefold():
        raise ValueError("KHL automated-access warning is missing")


def render_migration(workbook: Path) -> str:
    sheets = workbook_rows(workbook)
    league_rows = sheets["League Source Map"][1:]
    source_rows = sheets["Canonical Sources"][1:]
    validate_workbook(league_rows, source_rows)
    workbook_sha = hashlib.sha256(workbook.read_bytes()).hexdigest()

    source_values: list[list[object]] = []
    for row in source_rows:
        mapped_leagues = split_league_ids(row["K"])
        metadata = json.dumps(
            {
                "team_color_source_seed": {
                    "automated_access": row["M"],
                    "empirical_qualification_at_seed": row["I"],
                    "import_key": IMPORT_KEY,
                    "information_lineage_seeded": False,
                    "mapped_league_ids": mapped_leagues,
                    "owner_independence_group": row["E"],
                    "source_class": row["B"],
                    "workbook_sha256": workbook_sha,
                }
            },
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        source_values.append(
            [
                row["A"], row["B"], row["C"], row["D"], row["L"], row["E"],
                int(row["F"]), row["M"], row["N"], metadata,
            ]
        )

    league_values = [
        [
            row["A"].casefold(), row["B"], row["C"], row["D"], row["G"],
            row["L"], row["M"], row["N"],
        ]
        for row in league_rows
    ]

    unique_scope_keys: set[tuple[str, str, str, str]] = set()
    source_by_id = {row["A"]: row for row in source_rows}
    for row in source_rows:
        host, path = normalized_url(row["D"])
        unique_scope_keys.add((row["A"], host, path, "prefix"))
        reference_host, reference_path = normalized_url(row["L"])
        if (reference_host, reference_path) != (host, path):
            unique_scope_keys.add((row["A"], reference_host, reference_path, "exact"))
    for row in league_rows:
        source = source_by_id[row["D"]]
        base_parts = normalized_url(source["D"])
        reference_parts = normalized_url(row["G"])
        if reference_parts != base_parts:
            unique_scope_keys.add((row["D"], *reference_parts, "exact"))

    record_counts = json.dumps(
        {
            "broad_tier_2_sources": 3,
            "canonical_sources": 116,
            "league_mappings": 125,
            "legacy_source_redirects": EXPECTED_LEGACY_REDIRECTS,
            "official_tier_1_sources": 113,
            "url_scopes": len(unique_scope_keys),
        },
        sort_keys=True,
        separators=(",", ":"),
    )

    template = r"""-- Generated by supabase/scripts/generate_team_color_source_seed.py.
-- Governance tiers and applicability are approved reference data. Every
-- source remains empirically probationary/unrated until clean shadow testing.
begin;

alter table public.catalog_import_batches
  drop constraint if exists catalog_import_batches_source_kind_check;
alter table public.catalog_import_batches
  add constraint catalog_import_batches_source_kind_check check (
    source_kind in (
      'master_workbook','legacy_frontend','reference_example',
      'venue_prototype','source_reference'
    )
  );

create temporary table fanatical_team_color_source_seed(
  source_id text primary key,
  source_class text not null,
  display_name text not null,
  base_url text not null,
  reference_url text not null,
  ownership_display_name text not null,
  trust_tier smallint not null,
  automated_access text not null,
  notes text not null,
  metadata jsonb not null
) on commit drop;
insert into fanatical_team_color_source_seed values
    __SOURCE_VALUES__;

create temporary table fanatical_team_color_league_source_seed(
  sport_id text not null,
  league_name text not null,
  league_id text primary key,
  source_id text not null references fanatical_team_color_source_seed(source_id),
  reference_url text not null,
  automated_access text not null,
  checked_date text not null,
  notes text
) on commit drop;
insert into fanatical_team_color_league_source_seed values
    __LEAGUE_VALUES__;

do $$
declare conflict_record record;
begin
  if (select count(*) from fanatical_team_color_source_seed) <> 116
     or (select count(*) from fanatical_team_color_source_seed where source_class = 'Official Tier 1') <> 113
     or (select count(*) from fanatical_team_color_source_seed where source_class = 'Broad Tier 2') <> 3
     or (select count(*) from fanatical_team_color_league_source_seed) <> 125 then
    raise exception 'Team Color source workbook counts are inconsistent';
  end if;
  select seed.league_id, seed.sport_id supplied_sport,
         sport.sport_id existing_sport, seed.league_name supplied_name,
         league.display_name existing_name, league.active
  into conflict_record
  from fanatical_team_color_league_source_seed seed
  left join public.catalog_leagues league on league.league_id = seed.league_id
  left join public.catalog_sports sport on sport.id = league.sport_id
  where league.id is null or not league.active
     or sport.sport_id <> seed.sport_id
     or league.display_name <> seed.league_name
  limit 1;
  if found then
    raise exception 'Team Color source league conflict: %', row_to_json(conflict_record);
  end if;
  if exists (
    select 1 from public.catalog_leagues league
    where league.active and not exists (
      select 1 from fanatical_team_color_league_source_seed seed
      where seed.league_id = league.league_id
    )
  ) then
    raise exception 'The active league catalog contains a league absent from the authoritative Team Color source workbook';
  end if;
  select batch.import_key, batch.source_filename, batch.source_sha256,
         batch.source_kind, batch.record_counts, batch.verified_source_data
  into conflict_record
  from public.catalog_import_batches batch
  where batch.import_key = '__IMPORT_KEY__'
    and (
      batch.source_filename <> '__WORKBOOK_FILENAME__'
      or batch.source_sha256 <> '__WORKBOOK_SHA__'
      or batch.source_kind <> 'source_reference'
      or batch.record_counts <> '__RECORD_COUNTS__'::jsonb
      or batch.verified_source_data
    );
  if found then
    raise exception 'Team Color source import provenance conflict: %', row_to_json(conflict_record);
  end if;
  select grouping.group_id, grouping.display_name existing_name,
         seed.ownership_display_name supplied_name
  into conflict_record
  from fanatical_team_color_source_seed seed
  join public.source_independence_groups grouping
    on grouping.group_id = seed.source_id
  where grouping.display_name <> seed.ownership_display_name
  limit 1;
  if found then
    raise exception 'Team Color ownership-group conflict: %', row_to_json(conflict_record);
  end if;
  select source.source_id, source.display_name existing_name,
         seed.display_name supplied_name, source.base_url existing_base_url,
         seed.base_url supplied_base_url, source.reference_url existing_reference_url,
         seed.reference_url supplied_reference_url, source.review_status,
         source.superseded_by_source_id
  into conflict_record
  from fanatical_team_color_source_seed seed
  join public.trusted_sources source on source.source_id = seed.source_id
  left join public.source_independence_groups grouping
    on grouping.id = source.independence_group_id
  where source.display_name <> seed.display_name
     or public.normalize_source_url(source.base_url) <> public.normalize_source_url(seed.base_url)
     or public.normalize_source_url(source.reference_url) <> public.normalize_source_url(seed.reference_url)
     or source.review_status <> 'approved'
     or source.superseded_by_source_id is not null
     or grouping.group_id is distinct from seed.source_id
  limit 1;
  if found then
    raise exception 'Team Color canonical-source conflict: %', row_to_json(conflict_record);
  end if;
end;
$$;

insert into public.catalog_import_batches(
  import_key, source_filename, source_sha256, source_kind, record_counts,
  verified_source_data, notes
) values (
  '__IMPORT_KEY__','__WORKBOOK_FILENAME__','__WORKBOOK_SHA__','source_reference',
  '__RECORD_COUNTS__'::jsonb,false,
  'Approved Team Color source-governance reference; contains no Team Color facts, empirical qualification evidence, or information lineages.'
) on conflict (import_key) do nothing;

insert into public.source_independence_groups(group_id, display_name, notes)
select seed.source_id, seed.ownership_display_name,
       'Workbook-supplied publisher ownership / independence group for the Team Color source seed.'
from fanatical_team_color_source_seed seed
on conflict (group_id) do nothing;

insert into public.trusted_sources(
  source_id, display_name, base_url, reference_url, independence_group_id,
  review_status, notes, metadata, import_batch_id
)
select seed.source_id, seed.display_name, seed.base_url, seed.reference_url,
       grouping.id, 'approved', seed.notes,
       seed.metadata || jsonb_build_object(
         'automated_access', seed.automated_access,
         'governance_tier_is_not_empirical_qualification', true
       ), batch.id
from fanatical_team_color_source_seed seed
join public.source_independence_groups grouping
  on grouping.group_id = seed.source_id
join public.catalog_import_batches batch
  on batch.import_key = '__IMPORT_KEY__'
on conflict (source_id) do nothing;

insert into public.source_independence_group_assignment_versions(
  source_id, independence_group_id, review_status, notes
)
select source.id, grouping.id, 'approved',
       'Approved from the authoritative Team Color source workbook.'
from fanatical_team_color_source_seed seed
join public.trusted_sources source on source.source_id = seed.source_id
join public.source_independence_groups grouping
  on grouping.group_id = seed.source_id
where not exists (
  select 1 from public.source_independence_group_assignment_versions assignment
  where assignment.source_id = source.id and assignment.is_current
);

do $$
declare conflict_record record;
begin
  select source.source_id, assignment.review_status,
         grouping.group_id existing_group, seed.source_id supplied_group
  into conflict_record
  from fanatical_team_color_source_seed seed
  join public.trusted_sources source on source.source_id = seed.source_id
  join public.source_independence_group_assignment_versions assignment
    on assignment.source_id = source.id and assignment.is_current
  left join public.source_independence_groups grouping
    on grouping.id = assignment.independence_group_id
  where assignment.review_status <> 'approved'
     or grouping.group_id is distinct from seed.source_id
  limit 1;
  if found then
    raise exception 'Team Color current ownership assignment conflict: %', row_to_json(conflict_record);
  end if;
end;
$$;

create temporary table fanatical_team_color_url_scope_seed on commit drop as
with supplied_urls as (
  select seed.source_id, seed.base_url source_url, 'prefix'::text path_match,
         case
           when public.normalize_source_path(
             public.normalized_source_url_parts(seed.base_url) ->> 'path'
           ) = '/' then 'publisher' else 'path_owner'
         end scope_kind,
         'Team Color source seed canonical base URL.'::text review_notes
  from fanatical_team_color_source_seed seed
  union all
  select seed.source_id, seed.reference_url, 'exact', 'document_host',
         'Team Color source seed representative URL.'
  from fanatical_team_color_source_seed seed
  where public.normalize_source_url(seed.reference_url)
        <> public.normalize_source_url(seed.base_url)
  union all
  select mapping.source_id, mapping.reference_url, 'exact', 'document_host',
         'Team Color source seed mapped-league reference URL.'
  from fanatical_team_color_league_source_seed mapping
  join fanatical_team_color_source_seed seed using (source_id)
  where public.normalize_source_url(mapping.reference_url)
        <> public.normalize_source_url(seed.base_url)
), normalized as (
  select source_id,
         public.normalized_source_url_parts(source_url) ->> 'hostname' hostname,
         public.normalize_source_path(
           public.normalized_source_url_parts(source_url) ->> 'path'
         ) path_prefix,
         path_match, scope_kind, min(review_notes) review_notes
  from supplied_urls
  group by source_id,
           public.normalized_source_url_parts(source_url) ->> 'hostname',
           public.normalize_source_path(
             public.normalized_source_url_parts(source_url) ->> 'path'
           ),
           path_match, scope_kind
)
select * from normalized;

do $$
declare conflict_record record;
begin
  select source.source_id, scope.hostname, scope.path_prefix,
         scope.path_match, scope.scope_kind, scope.review_status
  into conflict_record
  from fanatical_team_color_url_scope_seed seed
  join public.trusted_sources source on source.source_id = seed.source_id
  join public.trusted_source_url_scope_versions scope
    on scope.source_id = source.id and scope.is_current
   and scope.hostname = seed.hostname and scope.include_subdomains = false
   and scope.path_prefix = seed.path_prefix
   and scope.path_match = seed.path_match and scope.scope_kind = seed.scope_kind
  where scope.review_status <> 'approved'
  limit 1;
  if found then
    raise exception 'Team Color current URL-scope conflict: %', row_to_json(conflict_record);
  end if;
end;
$$;

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status, review_notes
)
select source.id, seed.hostname, false, seed.path_prefix, seed.path_match,
       seed.scope_kind, 'approved', seed.review_notes
from fanatical_team_color_url_scope_seed seed
join public.trusted_sources source on source.source_id = seed.source_id
on conflict (
  source_id, hostname, include_subdomains, path_prefix, path_match, scope_kind
) where is_current do nothing;

do $$
declare conflict_record record;
begin
  select source.source_id, trust.trust_tier existing_tier,
         seed.trust_tier supplied_tier
  into conflict_record
  from fanatical_team_color_source_seed seed
  join public.trusted_sources source on source.source_id = seed.source_id
  join public.source_trust_assignments trust
    on trust.source_id = source.id and trust.data_type = 'team_colors'
   and trust.is_current
  where trust.trust_tier <> seed.trust_tier
  limit 1;
  if found then
    raise exception 'Team Color current trust-tier conflict: %', row_to_json(conflict_record);
  end if;
end;
$$;

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, effective_from, notes
)
select source.id, 'team_colors', seed.trust_tier, current_date,
       'Governance tier from the authoritative Team Color source workbook; not empirical qualification.'
from fanatical_team_color_source_seed seed
join public.trusted_sources source on source.source_id = seed.source_id
where not exists (
  select 1 from public.source_trust_assignments trust
  where trust.source_id = source.id and trust.data_type = 'team_colors'
    and trust.is_current
);

create temporary table fanatical_team_color_applicability_seed on commit drop as
select mapping.source_id, 'league'::text applicability_kind,
       null::text sport_id, mapping.league_id, null::text team_id,
       concat_ws(' ',
         'Authoritative workbook Team Color league mapping.',
         'Reference:', mapping.reference_url,
         'Automated access:', mapping.automated_access,
         case when nullif(mapping.notes, '') is not null
              then 'Note: ' || mapping.notes else null end
       ) notes
from fanatical_team_color_league_source_seed mapping
union all
select seed.source_id, 'global', null, null, null,
       concat_ws(' ',
         'Authoritative workbook broad Team Color candidate applicability; actual coverage varies.',
         'Automated access:', seed.automated_access
       )
from fanatical_team_color_source_seed seed
where seed.source_class = 'Broad Tier 2';

do $$
declare conflict_record record;
begin
  select source.source_id, applicability.applicability_kind,
         sport.sport_id, league.league_id, team.team_id,
         applicability.review_status
  into conflict_record
  from fanatical_team_color_source_seed seed
  join public.trusted_sources source on source.source_id = seed.source_id
  join public.source_applicability_versions applicability
    on applicability.source_id = source.id
   and applicability.data_type = 'team_colors' and applicability.is_current
  left join public.catalog_sports sport on sport.id = applicability.sport_id
  left join public.catalog_leagues league on league.id = applicability.league_id
  left join public.catalog_teams team on team.id = applicability.team_id
  where applicability.review_status <> 'approved'
     or not exists (
       select 1 from fanatical_team_color_applicability_seed expected
       where expected.source_id = seed.source_id
         and expected.applicability_kind = applicability.applicability_kind
         and expected.sport_id is not distinct from sport.sport_id
         and expected.league_id is not distinct from league.league_id
         and expected.team_id is not distinct from team.team_id
     )
  limit 1;
  if found then
    raise exception 'Team Color current applicability conflict: %', row_to_json(conflict_record);
  end if;
end;
$$;

insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, sport_id, league_id, team_id,
  review_status, notes
)
select source.id, 'team_colors', seed.applicability_kind,
       sport.id, league.id, team.id, 'approved', seed.notes
from fanatical_team_color_applicability_seed seed
join public.trusted_sources source on source.source_id = seed.source_id
left join public.catalog_sports sport on sport.sport_id = seed.sport_id
left join public.catalog_leagues league on league.league_id = seed.league_id
left join public.catalog_teams team on team.team_id = seed.team_id
where not exists (
  select 1 from public.source_applicability_versions applicability
  where applicability.source_id = source.id
    and applicability.data_type = 'team_colors' and applicability.is_current
    and applicability.applicability_kind = seed.applicability_kind
    and applicability.sport_id is not distinct from sport.id
    and applicability.league_id is not distinct from league.id
    and applicability.team_id is not distinct from team.id
);

-- The completed master-team seed predates canonical publisher review and
-- contains page-level pending candidates. Reconcile only candidates from that
-- immutable import batch when their workbook league and publisher hostname, or
-- their most-specific publisher path, identify exactly one canonical family.
create temporary table fanatical_team_color_legacy_redirect_seed on commit drop as
with legacy as (
  select source.*
  from public.trusted_sources source
  join public.catalog_import_batches batch on batch.id = source.import_batch_id
  where batch.import_key = 'master-teams-complete-2026-08-19'
), league_candidates as (
  select legacy.id legacy_source_id, target.id canonical_source_id,
         count(*) reference_count,
         jsonb_array_length(legacy.metadata -> 'workbook_references') supplied_count
  from legacy
  cross join lateral jsonb_array_elements(
    coalesce(legacy.metadata -> 'workbook_references', '[]'::jsonb)
  ) reference
  join fanatical_team_color_league_source_seed mapping
    on mapping.league_id = reference ->> 'league_id'
  join public.trusted_sources target on target.source_id = mapping.source_id
  join fanatical_team_color_source_seed target_seed
    on target_seed.source_id = mapping.source_id
  where public.normalized_source_url_parts(legacy.base_url) ->> 'hostname'
        = public.normalized_source_url_parts(target_seed.base_url) ->> 'hostname'
  group by legacy.id, target.id, legacy.metadata
), league_choice as (
  select legacy_source_id, min(canonical_source_id::text)::uuid canonical_source_id
  from league_candidates
  group by legacy_source_id
  having count(distinct canonical_source_id) = 1
     and max(reference_count) = max(supplied_count)
), path_candidates as (
  select legacy.id legacy_source_id, target.id canonical_source_id,
         length(public.normalize_source_path(
           public.normalized_source_url_parts(seed.base_url) ->> 'path'
         )) specificity
  from legacy
  join fanatical_team_color_source_seed seed
    on public.normalized_source_url_parts(legacy.reference_url) ->> 'hostname'
       = public.normalized_source_url_parts(seed.base_url) ->> 'hostname'
  join public.trusted_sources target on target.source_id = seed.source_id
  where not exists (
    select 1 from league_choice choice where choice.legacy_source_id = legacy.id
  )
    and (
      public.normalize_source_path(
        public.normalized_source_url_parts(seed.base_url) ->> 'path'
      ) = '/'
      or public.normalize_source_path(
        public.normalized_source_url_parts(legacy.reference_url) ->> 'path'
      ) = public.normalize_source_path(
        public.normalized_source_url_parts(seed.base_url) ->> 'path'
      )
      or left(
        public.normalize_source_path(
          public.normalized_source_url_parts(legacy.reference_url) ->> 'path'
        ),
        length(public.normalize_source_path(
          public.normalized_source_url_parts(seed.base_url) ->> 'path'
        )) + 1
      ) = public.normalize_source_path(
            public.normalized_source_url_parts(seed.base_url) ->> 'path'
          ) || '/'
    )
), path_ranked as (
  select candidate.*,
         dense_rank() over (
           partition by legacy_source_id order by specificity desc
         ) specificity_rank
  from path_candidates candidate
), path_choice as (
  select legacy_source_id, min(canonical_source_id::text)::uuid canonical_source_id
  from path_ranked where specificity_rank = 1
  group by legacy_source_id
  having count(distinct canonical_source_id) = 1
)
select legacy_source_id, canonical_source_id from league_choice
union all
select legacy_source_id, canonical_source_id from path_choice;

do $$
declare conflict_record record;
begin
  if (select count(*) from fanatical_team_color_legacy_redirect_seed) <> __LEGACY_REDIRECT_COUNT__ then
    raise exception 'Expected __LEGACY_REDIRECT_COUNT__ deterministic legacy source redirects, found %',
      (select count(*) from fanatical_team_color_legacy_redirect_seed);
  end if;
  select legacy.source_id legacy_source, existing_target.source_id existing_target,
         supplied_target.source_id supplied_target
  into conflict_record
  from fanatical_team_color_legacy_redirect_seed seed
  join public.trusted_sources legacy on legacy.id = seed.legacy_source_id
  join public.trusted_source_redirects redirect on redirect.source_id = legacy.id
  join public.trusted_sources existing_target on existing_target.id = redirect.canonical_source_id
  join public.trusted_sources supplied_target on supplied_target.id = seed.canonical_source_id
  where redirect.canonical_source_id <> seed.canonical_source_id
  limit 1;
  if found then
    raise exception 'Legacy source has a conflicting canonical redirect: %', row_to_json(conflict_record);
  end if;
  select legacy.source_id, legacy.review_status,
         legacy.superseded_by_source_id,
         (select count(*) from public.source_trust_assignments trust
          where trust.source_id = legacy.id and trust.is_current) current_trust_count,
         (select count(*) from public.source_applicability_versions applicability
          where applicability.source_id = legacy.id and applicability.is_current) current_applicability_count
  into conflict_record
  from fanatical_team_color_legacy_redirect_seed seed
  join public.trusted_sources legacy on legacy.id = seed.legacy_source_id
  where not exists (
    select 1 from public.trusted_source_redirects redirect
    where redirect.source_id = legacy.id
  )
    and (
      legacy.review_status <> 'pending_review'
      or legacy.superseded_by_source_id is not null
      or exists (
        select 1 from public.source_trust_assignments trust
        where trust.source_id = legacy.id and trust.is_current
      )
      or exists (
        select 1 from public.source_applicability_versions applicability
        where applicability.source_id = legacy.id and applicability.is_current
      )
    )
  limit 1;
  if found then
    raise exception 'Legacy source requires human conflict resolution before redirect: %', row_to_json(conflict_record);
  end if;
end;
$$;

create temporary table fanatical_team_color_new_redirect_seed on commit drop as
select seed.*
from fanatical_team_color_legacy_redirect_seed seed
where not exists (
  select 1 from public.trusted_source_redirects redirect
  where redirect.source_id = seed.legacy_source_id
);

insert into public.trusted_source_redirects(
  source_id, canonical_source_id, reason
)
select seed.legacy_source_id, seed.canonical_source_id,
       'Canonicalized by the authoritative Team Color source workbook without rewriting historical evidence.'
from fanatical_team_color_new_redirect_seed seed;

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status, review_notes
)
select seed.canonical_source_id, scope.hostname, scope.include_subdomains,
       scope.path_prefix, scope.path_match, scope.scope_kind,
       scope.review_status,
       'Transferred by Team Color source seed canonical redirect.'
from fanatical_team_color_new_redirect_seed seed
join public.trusted_source_url_scope_versions scope
  on scope.source_id = seed.legacy_source_id and scope.is_current
on conflict (
  source_id, hostname, include_subdomains, path_prefix, path_match, scope_kind
) where is_current do nothing;

insert into public.trusted_source_alias_versions(
  source_id, alias, alias_type, notes
)
select seed.canonical_source_id, alias.alias, alias.alias_type,
       'Transferred by Team Color source seed canonical redirect.'
from fanatical_team_color_new_redirect_seed seed
join public.trusted_source_alias_versions alias
  on alias.source_id = seed.legacy_source_id and alias.is_current
on conflict (source_id, normalized_alias, alias_type) where is_current do nothing;

update public.trusted_sources legacy
set review_status = 'retired', superseded_by_source_id = seed.canonical_source_id,
    superseded_at = now(), updated_at = now()
from fanatical_team_color_new_redirect_seed seed
where legacy.id = seed.legacy_source_id;

update public.trusted_source_url_scope_versions scope
set is_current = false, effective_to = now(), review_status = 'retired'
from fanatical_team_color_new_redirect_seed seed
where scope.source_id = seed.legacy_source_id and scope.is_current;

update public.trusted_source_alias_versions alias
set is_current = false, effective_to = now()
from fanatical_team_color_new_redirect_seed seed
where alias.source_id = seed.legacy_source_id and alias.is_current;

update public.source_independence_group_assignment_versions assignment
set is_current = false, effective_to = now(), review_status = 'retired'
from fanatical_team_color_new_redirect_seed seed
where assignment.source_id = seed.legacy_source_id and assignment.is_current;

insert into public.trusted_source_alias_versions(
  source_id, alias, alias_type, notes
)
select seed.canonical_source_id, legacy.source_id, 'legacy_source_id',
       'Historical source ID redirected without rewriting evidence.'
from fanatical_team_color_new_redirect_seed seed
join public.trusted_sources legacy on legacy.id = seed.legacy_source_id
on conflict (source_id, normalized_alias, alias_type) where is_current do nothing;

insert into public.catalog_audit_events(
  action, entity_type, entity_id, details
)
select 'source.redirected', 'trusted_source', legacy.source_id,
       jsonb_build_object(
         'canonical_source_id', canonical.source_id,
         'reason', 'Canonicalized by the authoritative Team Color source workbook.',
         'historical_evidence_rewritten', false,
         'seed_import_key', '__IMPORT_KEY__'
       )
from fanatical_team_color_new_redirect_seed seed
join public.trusted_sources legacy on legacy.id = seed.legacy_source_id
join public.trusted_sources canonical on canonical.id = seed.canonical_source_id;

do $$
begin
  if (select count(*) from fanatical_team_color_url_scope_seed) <> ('__RECORD_COUNTS__'::jsonb ->> 'url_scopes')::integer then
    raise exception 'Generated Team Color URL-scope count is inconsistent';
  end if;
  if (select count(*) from public.trusted_source_redirects redirect
      join fanatical_team_color_legacy_redirect_seed seed
        on seed.legacy_source_id = redirect.source_id
      where redirect.canonical_source_id = seed.canonical_source_id) <> __LEGACY_REDIRECT_COUNT__ then
    raise exception 'Team Color legacy canonical redirects are incomplete';
  end if;
  if (select count(*) from public.source_trust_assignments trust
      join public.trusted_sources source on source.id = trust.source_id
      join fanatical_team_color_source_seed seed on seed.source_id = source.source_id
      where trust.data_type = 'team_colors' and trust.is_current
        and trust.trust_tier = seed.trust_tier) <> 116 then
    raise exception 'Team Color source governance trust seed is incomplete';
  end if;
  if (select count(*) from public.source_applicability_versions applicability
      join public.trusted_sources source on source.id = applicability.source_id
      join fanatical_team_color_source_seed seed on seed.source_id = source.source_id
      where applicability.data_type = 'team_colors'
        and applicability.is_current and applicability.review_status = 'approved') <> 128 then
    raise exception 'Team Color source applicability seed is incomplete';
  end if;
  if (select count(*) from public.source_qualification_enrollments enrollment
      join public.trusted_sources source on source.id = enrollment.source_id
      join fanatical_team_color_source_seed seed on seed.source_id = source.source_id
      where enrollment.data_type = 'team_colors') <> 116 then
    raise exception 'Team Color seeded sources were not enrolled for empirical qualification';
  end if;
end;
$$;

commit;
"""
    return (
        template.replace("__SOURCE_VALUES__", values_rows(source_values))
        .replace("__LEAGUE_VALUES__", values_rows(league_values))
        .replace("__IMPORT_KEY__", IMPORT_KEY)
        .replace("__WORKBOOK_FILENAME__", workbook.name.replace("'", "''"))
        .replace("__WORKBOOK_SHA__", workbook_sha)
        .replace("__RECORD_COUNTS__", record_counts.replace("'", "''"))
        .replace("__LEGACY_REDIRECT_COUNT__", str(EXPECTED_LEGACY_REDIRECTS))
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workbook", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    migration = render_migration(arguments.workbook)
    arguments.output.write_text(migration, encoding="utf-8")


if __name__ == "__main__":
    main()
