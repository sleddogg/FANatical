#!/usr/bin/env python3
"""Generate the reproducible FANatical catalog seed migration.

The workbook is an import source, not verified production evidence. Generated
facts are therefore labelled imported_unverified and workbook source rows are
labelled pending_review. This script uses only Python's standard library so it
does not add an application or migration dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree import ElementTree as ET
from zipfile import ZipFile

XML_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def sql(value: object) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def sql_text_array(values: list[str]) -> str:
    return "array[" + ",".join(sql(value) for value in values) + "]::text[]"


def values_rows(rows: list[list[object]]) -> str:
    return ",\n    ".join("(" + ", ".join(sql(value) for value in row) + ")" for row in rows)


def slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = "".join(character for character in normalized if not unicodedata.combining(character))
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.casefold()).strip("-")


def normalized_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", slug(value))


def workbook_rows(path: Path) -> dict[str, list[dict[str, str]]]:
    with ZipFile(path) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        targets = {relationship.attrib["Id"]: relationship.attrib["Target"].lstrip("/") for relationship in relationships}
        result: dict[str, list[dict[str, str]]] = {}
        for sheet in workbook.find(XML_NS + "sheets") or []:
            sheet_name = sheet.attrib["name"]
            target = targets[sheet.attrib[REL_NS + "id"]]
            target = target if target.startswith("xl/") else "xl/" + target
            root = ET.fromstring(archive.read(target))
            rows: list[dict[str, str]] = []
            for row in root.findall(".//" + XML_NS + "row"):
                values: dict[str, str] = {}
                for cell in row.findall(XML_NS + "c"):
                    column = "".join(character for character in cell.attrib["r"] if character.isalpha())
                    raw = cell.find(XML_NS + "v")
                    if cell.attrib.get("t") == "inlineStr":
                        value = "".join(text.text or "" for text in cell.iter(XML_NS + "t"))
                    else:
                        value = "" if raw is None else raw.text or ""
                    values[column] = value.strip()
                rows.append(values)
            result[sheet_name] = rows
        return result


def parse_frontend_catalog(path: Path) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    source = path.read_text(encoding="utf-8")
    team_pattern = re.compile(
        r'\{ id: "([^"]+)", displayName: "([^"]+)", parentLeagueId: "([^"]+)", colors: '
        r'\{ primary: (null|"#[0-9A-F]{6}"), secondary: (null|"#[0-9A-F]{6}"), '
        r'tertiary: (null|"#[0-9A-F]{6}"), quaternary: (null|"#[0-9A-F]{6}"), quinary: (null|"#[0-9A-F]{6}") \} \}'
    )
    league_pattern = re.compile(r'\{ id: "([^"]+)", displayName: "([^"]+)", parentSportId: "([^"]+)" \}')

    def color(value: str) -> str | None:
        return None if value == "null" else value.strip('"')

    teams = [{
        "legacy_id": match.group(1),
        "display_name": match.group(2),
        "legacy_league_id": match.group(3),
        "colors": [color(match.group(index)) for index in range(4, 9)],
    } for match in team_pattern.finditer(source)]
    leagues = [{"legacy_id": match.group(1), "display_name": match.group(2), "sport_id": match.group(3)} for match in league_pattern.finditer(source)]
    return teams, leagues


def excel_date(value: str) -> str | None:
    if not value:
        return None
    try:
        return (datetime(1899, 12, 30) + timedelta(days=float(value))).date().isoformat()
    except ValueError:
        return value


def canonical_source_url(value: str) -> str:
    """Return a deterministic key for safe workbook-source deduplication."""
    parsed = urlsplit(value.strip())
    path = parsed.path.rstrip("/") or "/"
    return parsed._replace(
        scheme=parsed.scheme.casefold(),
        netloc=parsed.netloc.casefold(),
        path=path,
        fragment="",
    ).geturl()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workbook", required=True, type=Path)
    parser.add_argument("--frontend-catalog", required=True, type=Path)
    parser.add_argument("--celtics-reference", required=True, type=Path)
    parser.add_argument("--venue-source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--import-key", required=True)
    arguments = parser.parse_args()

    sheets = workbook_rows(arguments.workbook)
    frontend_teams, frontend_leagues = parse_frontend_catalog(arguments.frontend_catalog)
    workbook_sha = hashlib.sha256(arguments.workbook.read_bytes()).hexdigest()
    frontend_sha = hashlib.sha256(arguments.frontend_catalog.read_bytes()).hexdigest()
    celtics_reference_sha = hashlib.sha256(arguments.celtics_reference.read_bytes()).hexdigest()
    venue_sha = hashlib.sha256(arguments.venue_source.read_bytes()).hexdigest()

    sports = [
        ("football", "Football"),
        ("baseball", "Baseball"),
        ("basketball", "Basketball"),
        ("hockey", "Hockey"),
        ("soccer", "Soccer"),
    ]

    workbook_leagues: list[dict[str, object]] = []
    for row in sheets["Leagues"][1:]:
        if not row.get("A") or not row.get("B") or not row.get("C"):
            continue
        workbook_leagues.append({
            "sport_id": row["A"].casefold(),
            "display_name": row["B"],
            "league_id": row["C"],
            "country_region": row.get("F") or None,
            "languages": [part.strip() for part in (row.get("G") or "").split("/") if part.strip()],
            "active": row.get("E") != "0",
        })
    workbook_leagues.append({
        "sport_id": "basketball",
        "display_name": "National Basketball Association",
        "league_id": "basketball-nba",
        "country_region": "USA / Canada",
        "languages": ["English", "French"],
        "active": True,
    })

    frontend_league_by_id = {league["legacy_id"]: league for league in frontend_leagues}
    canonical_league_by_id = {str(league["league_id"]): league for league in workbook_leagues}

    workbook_teams: list[dict[str, str]] = []
    for sheet_name in sorted(set(sheets) - {"Leagues", "Sources"}):
        sport_id = sheet_name.casefold()
        if sport_id not in {sport[0] for sport in sports}:
            continue
        for row in sheets[sheet_name]:
            if not row.get("D", "").startswith(sport_id + "-") or not row.get("B") or not row.get("C"):
                continue
            workbook_teams.append({
                "sport_id": sport_id,
                "league_id": row["B"],
                "display_name": row["C"],
                "team_id": row["D"],
            })
    workbook_teams.append({
        "sport_id": "basketball",
        "league_id": "basketball-nba",
        "display_name": "Boston Celtics",
        "team_id": "basketball-000001",
        "short_name": "Celtics",
        "abbreviation": "BOS",
        "founded_year": "1946",
    })

    by_normalized_name: dict[str, list[dict[str, str]]] = defaultdict(list)
    for team in workbook_teams:
        by_normalized_name[normalized_name(team["display_name"])].append(team)

    manual_team_matches = {
        "hockey-shl-lulea-hockey": "hockey-000062",
        "hockey-shl-orebro-hockey": "hockey-000068",
        "hockey-del-pinguins-bremerhaven": "hockey-000090",
        "hockey-national-league-fribourg-gotteron": "hockey-000105",
        "hockey-ice-hockey-league-hc-falkensteiner-pustertal": "hockey-000144",
        "hockey-tipsport-extraliga-banes-motor-ceske-budejovice": "hockey-000120",
        "hockey-khl-sochi": "hockey-000035",
    }
    workbook_team_by_id = {team["team_id"]: team for team in workbook_teams}
    legacy_team_mappings: list[tuple[str, str]] = []
    alternate_aliases: list[tuple[str, str]] = []
    legacy_league_mappings: dict[str, str] = {}
    color_rows: list[tuple[str, list[str | None]]] = []

    for frontend_team in frontend_teams:
        legacy_id = str(frontend_team["legacy_id"])
        match = workbook_team_by_id.get(manual_team_matches.get(legacy_id, ""))
        if match is None:
            legacy_league_id = str(frontend_team["legacy_league_id"])
            legacy_sport_id = frontend_league_by_id[legacy_league_id]["sport_id"]
            candidates = [
                team for team in by_normalized_name[normalized_name(str(frontend_team["display_name"]))]
                if team["sport_id"] == legacy_sport_id
            ]
            if len(candidates) != 1:
                raise RuntimeError(f"Cannot map legacy team {legacy_id}: {frontend_team['display_name']}")
            match = candidates[0]
        legacy_team_mappings.append((legacy_id, match["team_id"]))
        if str(frontend_team["display_name"]) != match["display_name"]:
            alternate_aliases.append((match["team_id"], str(frontend_team["display_name"])))
        legacy_league_id = str(frontend_team["legacy_league_id"])
        prior = legacy_league_mappings.setdefault(legacy_league_id, match["league_id"])
        if prior != match["league_id"]:
            raise RuntimeError(f"Legacy league {legacy_league_id} maps to multiple canonical leagues")
        colors = list(frontend_team["colors"])
        if colors[0] is not None and colors[1] is not None:
            color_rows.append((match["team_id"], colors))

    short_league_names: dict[str, str] = {}
    for legacy_id, canonical_id in legacy_league_mappings.items():
        display = frontend_league_by_id[legacy_id]["display_name"]
        short_league_names.setdefault(canonical_id, display)
    short_league_names["basketball-nba"] = "NBA"

    source_rows_by_url: dict[str, dict[str, object]] = {}
    source_order: list[str] = []
    for row in sheets["Sources"][1:]:
        if not row.get("E") or not row.get("F"):
            continue
        url_key = canonical_source_url(row["F"])
        reference = {
            "sport": row.get("A") or None,
            "league_name": row.get("B") or None,
            "league_id": row.get("C") or None,
            "scope": row.get("D") or None,
            "checked_date": excel_date(row.get("G") or ""),
            "notes": row.get("H") or None,
        }
        if url_key not in source_rows_by_url:
            parsed_url = urlsplit(row["F"])
            source_rows_by_url[url_key] = {
                "display_name": row["E"],
                "base_url": f"{parsed_url.scheme}://{parsed_url.netloc}" if parsed_url.scheme and parsed_url.netloc else None,
                "reference_url": row["F"],
                "references": [reference],
            }
            source_order.append(url_key)
        else:
            references = source_rows_by_url[url_key]["references"]
            assert isinstance(references, list)
            references.append(reference)

    source_rows = []
    used_source_ids: set[str] = set()
    for url_key in source_order:
        candidate = source_rows_by_url[url_key]
        references = candidate["references"]
        assert isinstance(references, list) and references
        source_id = slug(str(candidate["display_name"]))
        if source_id in used_source_ids:
            suffix = slug(str(references[0].get("league_id") or "source"))
            source_id = f"{source_id}-{suffix}"
        suffix_number = 2
        base_source_id = source_id
        while source_id in used_source_ids:
            source_id = f"{base_source_id}-{suffix_number}"
            suffix_number += 1
        used_source_ids.add(source_id)
        source_rows.append({
            "source_id": source_id,
            "display_name": candidate["display_name"],
            "base_url": candidate["base_url"],
            "reference_url": candidate["reference_url"],
            "notes": references[0].get("notes"),
            "metadata": {"workbook_references": references},
        })

    lines = [
        "-- Generated by supabase/scripts/generate_team_registry_seed.py.",
        "-- Workbook rows and cited sources are imported reference data, not verified facts.",
        "begin;",
        "",
        "insert into public.catalog_import_batches(import_key, source_filename, source_sha256, source_kind, record_counts, verified_source_data, notes) values",
        f"  ({sql(arguments.import_key)}, {sql(arguments.workbook.name)}, '{workbook_sha}', 'master_workbook', {sql(json.dumps({'sports': len({str(league['sport_id']) for league in workbook_leagues if league['sport_id'] != 'basketball'}), 'leagues': len(workbook_leagues) - 1, 'teams': len(workbook_teams) - 1, 'sources': len(source_rows)}, separators=(',', ':')))}::jsonb, false, 'Approved identity seed/reference; contents are not verified production data'),",
        f"  ('legacy-frontend-2026-08-19', {sql(arguments.frontend_catalog.name)}, '{frontend_sha}', 'legacy_frontend', {sql(json.dumps({'legacy_team_identifiers': len(legacy_team_mappings), 'color_records': len(color_rows)}, separators=(',', ':')))}::jsonb, false, 'Compatibility identifiers and four existing frontend color palettes'),",
        f"  ('celtics-reference-2026-08-19', {sql(arguments.celtics_reference.name)}, '{celtics_reference_sha}', 'reference_example', '{{\"teams\":1}}'::jsonb, false, 'Human read-model example; not a verified source'),",
        f"  ('rexall-prototype-2026-08-19', {sql(arguments.venue_source.name)}, '{venue_sha}', 'venue_prototype', '{{\"venues\":1,\"mappings\":1}}'::jsonb, false, 'Existing local Venue Mapper compatibility seed')",
        "on conflict (import_key) do nothing;",
        "",
        "insert into public.catalog_sports(sport_id, display_name) values",
        "  " + ",\n  ".join(f"({sql(sport_id)}, {sql(display_name)})" for sport_id, display_name in sports),
        "on conflict (sport_id) do nothing;",
        "",
    ]

    league_seed_rows = []
    for league in workbook_leagues:
        batch_key = "celtics-reference-2026-08-19" if league["sport_id"] == "basketball" else arguments.import_key
        league_seed_rows.append([
            league["league_id"], league["sport_id"], league["display_name"],
            short_league_names.get(str(league["league_id"])), league["country_region"],
            json.dumps(league["languages"], ensure_ascii=False), league["active"], batch_key,
        ])
    lines.extend([
        "create temporary table fanatical_league_seed(league_id text, sport_id text, display_name text, short_name text, country_region text, languages jsonb, active boolean, batch_key text) on commit drop;",
        "insert into fanatical_league_seed values",
        "    " + values_rows(league_seed_rows) + ";",
        "do $$ declare conflict_record record; begin",
        "  select seed.league_id, league.display_name as existing_name, seed.display_name as supplied_name, sport.sport_id as existing_sport, seed.sport_id as supplied_sport into conflict_record",
        "  from fanatical_league_seed seed join public.catalog_leagues league on league.league_id = seed.league_id join public.catalog_sports sport on sport.id = league.sport_id",
        "  where league.display_name <> seed.display_name or sport.sport_id <> seed.sport_id limit 1;",
        "  if found then raise exception 'Permanent League ID conflict for %: existing % / %, supplied % / %', conflict_record.league_id, conflict_record.existing_name, conflict_record.existing_sport, conflict_record.supplied_name, conflict_record.supplied_sport; end if;",
        "end $$;",
        "insert into public.catalog_leagues(league_id, sport_id, display_name, short_name, country_region, primary_languages, active, seed_status, import_batch_id)",
        "select seed.league_id, sport.id, seed.display_name, seed.short_name, seed.country_region, array(select jsonb_array_elements_text(seed.languages::jsonb)), seed.active::boolean, 'imported_unverified', batch.id",
        "from fanatical_league_seed seed join public.catalog_sports sport on sport.sport_id = seed.sport_id join public.catalog_import_batches batch on batch.import_key = seed.batch_key",
        "on conflict (league_id) do nothing;",
        "",
    ])

    league_identifier_rows = [[canonical_id, "legacy_frontend_id", legacy_id] for legacy_id, canonical_id in sorted(legacy_league_mappings.items()) if legacy_id != canonical_id]
    if league_identifier_rows:
        lines.extend([
            "with seed(league_id, namespace, identifier) as (values",
            "    " + values_rows(league_identifier_rows),
            ") insert into public.catalog_league_identifiers(league_id, namespace, identifier)",
            "select league.id, seed.namespace, seed.identifier from seed join public.catalog_leagues league on league.league_id = seed.league_id",
            "on conflict (namespace, identifier) do nothing;",
            "",
        ])

    team_seed_rows = []
    for team in workbook_teams:
        batch_key = "celtics-reference-2026-08-19" if team["sport_id"] == "basketball" else arguments.import_key
        team_seed_rows.append([
            team["team_id"], team["sport_id"], team["league_id"], team["display_name"],
            team.get("short_name") or team["display_name"], team.get("abbreviation"),
            int(team["founded_year"]) if team.get("founded_year") else None, batch_key,
        ])
    team_values = "    " + values_rows(team_seed_rows)
    lines.extend([
        "create temporary table fanatical_team_seed(team_id text, sport_id text, league_id text, display_name text, short_name text, abbreviation text, founded_year integer, batch_key text) on commit drop;",
        "insert into fanatical_team_seed values",
        team_values + ";",
        "do $$ declare conflict_record record; begin",
        "  select seed.team_id, identity_record.display_name as existing_name, seed.display_name as supplied_name, sport.sport_id as existing_sport, seed.sport_id as supplied_sport, league.league_id as existing_league, seed.league_id as supplied_league into conflict_record",
        "  from fanatical_team_seed seed join public.catalog_teams team on team.team_id = seed.team_id join public.catalog_sports sport on sport.id = team.sport_id",
        "  left join public.team_identity_versions identity_record on identity_record.team_id = team.id and identity_record.is_current",
        "  left join public.team_primary_league_versions membership on membership.team_id = team.id and membership.is_current",
        "  left join public.catalog_leagues league on league.id = membership.league_id",
        "  where sport.sport_id <> seed.sport_id or (identity_record.id is not null and identity_record.display_name <> seed.display_name) or (league.id is not null and league.league_id <> seed.league_id) limit 1;",
        "  if found then raise exception 'Permanent Team ID conflict for %: existing % / % / %, supplied % / % / %', conflict_record.team_id, conflict_record.existing_name, conflict_record.existing_sport, conflict_record.existing_league, conflict_record.supplied_name, conflict_record.supplied_sport, conflict_record.supplied_league; end if;",
        "end $$;",
        "insert into public.catalog_teams(team_id, sport_id, import_batch_id)",
        "select seed.team_id, sport.id, batch.id from fanatical_team_seed seed join public.catalog_sports sport on sport.sport_id = seed.sport_id join public.catalog_import_batches batch on batch.import_key = seed.batch_key",
        "on conflict (team_id) do nothing;",
        "insert into public.team_identity_versions(team_id, display_name, short_name, abbreviation, founded_year, active, record_status, import_batch_id)",
        "select team.id, seed.display_name, seed.short_name, seed.abbreviation, seed.founded_year, true, 'imported_unverified', batch.id",
        "from fanatical_team_seed seed join public.catalog_teams team on team.team_id = seed.team_id join public.catalog_import_batches batch on batch.import_key = seed.batch_key",
        "where not exists (select 1 from public.team_identity_versions existing where existing.team_id = team.id and existing.is_current);",
        "insert into public.team_alias_versions(team_id, alias, alias_type, record_status, import_batch_id)",
        "select team.id, seed.display_name, 'common_name', 'imported_unverified', batch.id",
        "from fanatical_team_seed seed join public.catalog_teams team on team.team_id = seed.team_id join public.catalog_import_batches batch on batch.import_key = seed.batch_key",
        "where not exists (select 1 from public.team_alias_versions existing where existing.team_id = team.id and existing.normalized_alias = lower(regexp_replace(trim(seed.display_name), '\\s+', ' ', 'g')) and existing.alias_type = 'common_name' and existing.is_current);",
        "insert into public.team_primary_league_versions(team_id, league_id, record_status, import_batch_id)",
        "select team.id, league.id, 'imported_unverified', batch.id",
        "from fanatical_team_seed seed join public.catalog_teams team on team.team_id = seed.team_id join public.catalog_leagues league on league.league_id = seed.league_id join public.catalog_import_batches batch on batch.import_key = seed.batch_key",
        "where not exists (select 1 from public.team_primary_league_versions existing where existing.team_id = team.id and existing.is_current);",
        "",
    ])

    identifier_seed_rows = [[canonical_id, "legacy_frontend_id", legacy_id] for legacy_id, canonical_id in sorted(legacy_team_mappings)]
    identifier_seed_rows.extend([
        ["football-000003", "legacy_team_context_id", "new-england-patriots"],
        ["baseball-000002", "legacy_team_context_id", "boston-red-sox"],
        ["basketball-000001", "legacy_team_context_id", "boston-celtics"],
    ])
    lines.extend([
        "with seed(team_id, namespace, identifier) as (values",
        "    " + values_rows(identifier_seed_rows),
        ") insert into public.catalog_team_identifiers(team_id, namespace, identifier, record_status, import_batch_id)",
        "select team.id, seed.namespace, seed.identifier, 'imported_unverified', batch.id from seed join public.catalog_teams team on team.team_id = seed.team_id cross join public.catalog_import_batches batch",
        "where batch.import_key = 'legacy-frontend-2026-08-19' on conflict (namespace, identifier) do nothing;",
        "",
    ])

    if alternate_aliases:
        lines.extend([
            "with seed(team_id, alias) as (values",
            "    " + values_rows([[team_id, alias] for team_id, alias in sorted(set(alternate_aliases))]),
            ") insert into public.team_alias_versions(team_id, alias, alias_type, record_status, import_batch_id)",
            "select team.id, seed.alias, 'other', 'imported_unverified', batch.id from seed join public.catalog_teams team on team.team_id = seed.team_id cross join public.catalog_import_batches batch",
            "where batch.import_key = 'legacy-frontend-2026-08-19' and not exists (select 1 from public.team_alias_versions existing where existing.team_id = team.id and existing.normalized_alias = lower(regexp_replace(trim(seed.alias), '\\s+', ' ', 'g')) and existing.alias_type = 'other' and existing.is_current);",
            "",
        ])

    lines.extend([
        "with seed(team_id, primary_color, secondary_color, tertiary_color, quaternary_color, quinary_color) as (values",
        "    " + values_rows([[team_id, *colors] for team_id, colors in color_rows]),
        ") insert into public.team_color_versions(team_id, primary_color, secondary_color, tertiary_color, quaternary_color, quinary_color, record_status, import_batch_id)",
        "select team.id, seed.primary_color, seed.secondary_color, seed.tertiary_color, seed.quaternary_color, seed.quinary_color, 'imported_unverified', batch.id",
        "from seed join public.catalog_teams team on team.team_id = seed.team_id cross join public.catalog_import_batches batch",
        "where batch.import_key = 'legacy-frontend-2026-08-19' and not exists (select 1 from public.team_color_versions existing where existing.team_id = team.id and existing.is_current);",
        "",
    ])

    source_seed_rows = [[
        source["source_id"], source["display_name"], source["base_url"], source["reference_url"],
        source["notes"], json.dumps(source["metadata"], ensure_ascii=False, separators=(",", ":")),
    ] for source in source_rows]
    lines.extend([
        "with seed(source_id, display_name, base_url, reference_url, notes, metadata) as (values",
        "    " + values_rows(source_seed_rows),
        ") insert into public.trusted_sources(source_id, display_name, base_url, reference_url, review_status, notes, metadata, import_batch_id)",
        "select seed.source_id, seed.display_name, seed.base_url, seed.reference_url, 'pending_review', seed.notes, seed.metadata::jsonb, batch.id",
        f"from seed cross join public.catalog_import_batches batch where batch.import_key = {sql(arguments.import_key)}",
        "on conflict (source_id) do update set",
        "  display_name = excluded.display_name, base_url = excluded.base_url, reference_url = excluded.reference_url,",
        "  notes = excluded.notes, metadata = excluded.metadata, import_batch_id = excluded.import_batch_id",
        "where public.trusted_sources.review_status = 'pending_review'",
        "  and public.trusted_sources.independence_group_id is null",
        "  and not exists (select 1 from public.source_trust_assignments trust where trust.source_id = public.trusted_sources.id);",
        "",
    ])

    maximum_by_sport: dict[str, int] = defaultdict(int)
    for team in workbook_teams:
        maximum_by_sport[team["sport_id"]] = max(maximum_by_sport[team["sport_id"]], int(team["team_id"].rsplit("-", 1)[1]))
    lines.extend([
        "with seed(sport_id, next_value) as (values",
        "    " + values_rows([[sport_id, maximum_by_sport[sport_id] + 1] for sport_id, _ in sports]),
        ") insert into public.catalog_team_id_sequences(sport_id, next_value)",
        "select sport.id, seed.next_value::integer from seed join public.catalog_sports sport on sport.sport_id = seed.sport_id",
        "on conflict (sport_id) do update set next_value = greatest(public.catalog_team_id_sequences.next_value, excluded.next_value);",
        "",
    ])

    lower = [101,102,104,106,108,110,112,114,116,118,119,120,122,124,126,128,130,132,134,136]
    upper = [201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,301,302,303,304,305,333,334,335,336,337]
    side_a = {110,112,114,116,118,119,120,122,124,126,128,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227}
    end_a = {102,104,106,108,110,112,114,116,118,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,301,302,303,304,305}
    lines.extend([
        "insert into public.catalog_venues(venue_id) values ('venue-rexall-place') on conflict (venue_id) do nothing;",
        "insert into public.venue_detail_versions(venue_id, display_name, city, region, country, country_code, record_status, import_batch_id)",
        "select venue.id, 'Rexall Place', 'Edmonton', 'Alberta', 'Canada', 'CA', 'imported_unverified', batch.id",
        "from public.catalog_venues venue cross join public.catalog_import_batches batch",
        "where venue.venue_id = 'venue-rexall-place' and batch.import_key = 'rexall-prototype-2026-08-19'",
        "  and not exists (select 1 from public.venue_detail_versions existing where existing.venue_id = venue.id and existing.is_current);",
        "insert into public.venue_mapping_versions(venue_id, version, routing_convention_version, section_format, seating_chart_image_url, seating_chart_source_label, seating_chart_source_url, record_status, import_batch_id)",
        "select venue.id, 1, 2, 'Numeric', 'https://seatingchartview.com/wp-content/uploads/2016/01/Rexall-Place-Hockey-Seating-Chart-768x724.jpg', 'Northlands Coliseum hockey seating chart — SeatingChartView', 'https://seatingchartview.com/northlands-coliseum/', 'imported_unverified', batch.id",
        "from public.catalog_venues venue cross join public.catalog_import_batches batch",
        "where venue.venue_id = 'venue-rexall-place' and batch.import_key = 'rexall-prototype-2026-08-19'",
        "  and not exists (select 1 from public.venue_mapping_versions existing where existing.venue_id = venue.id and existing.is_current);",
    ])
    for section in sorted(lower + upper):
        level = "Lower" if section in lower else "Upper"
        side = "Side A" if section in side_a else "Side B"
        venue_end = "End A" if section in end_a else "End B"
        lines.extend([
            "insert into public.venue_mapping_sections(mapping_version_id, section_code, level, side, venue_end)",
            f"select mapping.id, {sql(str(section))}, {sql(level)}, {sql(side)}, {sql(venue_end)}",
            "from public.venue_mapping_versions mapping join public.catalog_venues venue on venue.id = mapping.venue_id",
            "where venue.venue_id = 'venue-rexall-place' and mapping.is_current",
            "on conflict (mapping_version_id, section_code) do nothing;",
        ])
    for section, axis in [(101, "end"), (119, "end"), (110, "side"), (128, "side")]:
        pairs = [(1, 10, "End A" if axis == "end" else "Side A"), (11, 24, "End B" if axis == "end" else "Side B")]
        for seat_start, seat_end, value in pairs:
            lines.extend([
                "insert into public.venue_mapping_section_exceptions(section_id, exception_key, seat_start, seat_end, side_override, end_override)",
                f"select section.id, {sql(f'{section}-{axis}-{seat_start}-{seat_end}')}, {sql(str(seat_start))}, {sql(str(seat_end))}, {sql(value if axis == 'side' else None)}, {sql(value if axis == 'end' else None)}",
                "from public.venue_mapping_sections section join public.venue_mapping_versions mapping on mapping.id = section.mapping_version_id join public.catalog_venues venue on venue.id = mapping.venue_id",
                f"where venue.venue_id = 'venue-rexall-place' and mapping.is_current and section.section_code = {sql(str(section))}",
                "on conflict (section_id, exception_key) do nothing;",
            ])
    for rule_key, level, row_end in [("rexall-lower-bowl", "Lower", 30), ("rexall-upper-bowl", "Upper", 20)]:
        rows_json = json.dumps({"values": [], "ranges": [{"start": "1", "end": str(row_end)}]}, separators=(",", ":"))
        seats_json = json.dumps({"values": [], "ranges": [{"start": "1", "end": "24"}]}, separators=(",", ":"))
        lines.extend([
            "insert into public.venue_mapping_inventory_rules(mapping_version_id, rule_key, levels, row_values, seat_values)",
            f"select mapping.id, {sql(rule_key)}, array[{sql(level)}]::text[], {sql(rows_json)}::jsonb, {sql(seats_json)}::jsonb",
            "from public.venue_mapping_versions mapping join public.catalog_venues venue on venue.id = mapping.venue_id",
            "where venue.venue_id = 'venue-rexall-place' and mapping.is_current",
            "on conflict (mapping_version_id, rule_key) do nothing;",
        ])
    for team_id, levels in [("hockey-000027", ["Upper", "Lower"]), ("hockey-000274", ["Lower"])]:
        lines.extend([
            "insert into public.venue_mapping_team_profiles(mapping_version_id, team_id, levels, sides, ends)",
            f"select mapping.id, team.id, {sql_text_array(levels)}, array['Side A','Side B']::text[], array['End A','End B']::text[]",
            "from public.venue_mapping_versions mapping join public.catalog_venues venue on venue.id = mapping.venue_id join public.catalog_teams team on true",
            f"where venue.venue_id = 'venue-rexall-place' and mapping.is_current and team.team_id = {sql(team_id)}",
            "on conflict (mapping_version_id, team_id) do nothing;",
        ])
    lines.extend([
        "insert into public.venue_mapping_sports(mapping_version_id, sport_id)",
        "select mapping.id, sport.id from public.venue_mapping_versions mapping join public.catalog_venues venue on venue.id = mapping.venue_id join public.catalog_sports sport on sport.sport_id = 'hockey'",
        "where venue.venue_id = 'venue-rexall-place' and mapping.is_current",
        "on conflict (mapping_version_id, sport_id) do nothing;",
        "",
        "commit;",
        "",
    ])

    arguments.output.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({
        "sports": len(sports),
        "leagues": len(workbook_leagues),
        "teams": len(workbook_teams),
        "legacy_team_identifiers": len(legacy_team_mappings),
        "sources_pending_review": len(source_rows),
        "color_records": len(color_rows),
        "output": str(arguments.output),
    }, indent=2))


if __name__ == "__main__":
    main()
