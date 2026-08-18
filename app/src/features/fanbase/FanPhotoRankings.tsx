import { useEffect, useMemo, useRef, useState } from "react";
import { findFollowedTeam } from "../../data/followedTeams";
import type { TeamId } from "../../domain/team";
import { demoUser } from "./mockFanbaseData";
import { formatRating } from "./fanbaseFormatting";
import type { FanPhoto } from "./types";
import { AppIcon } from "../../components/AppIcon";

type RankingScope = "personal" | "team" | "league" | "sport" | "global";

const rankingScopes = ["personal", "team", "league", "sport", "global"] as const satisfies readonly RankingScope[];

const scopeLabels: Readonly<Record<RankingScope, string>> = {
  personal: "Personal",
  team: "Team",
  league: "League",
  sport: "Sport",
  global: "Global",
};

const broaderRankOffsets: Readonly<Record<Exclude<RankingScope, "personal">, number>> = {
  team: 73,
  league: 172,
  sport: 539,
  global: 793,
};

function ratingAverage(photo: FanPhoto) {
  return photo.ratingCount ? photo.ratingTotal / photo.ratingCount : 0;
}

function rankedByRating(photos: readonly FanPhoto[]) {
  return [...photos].sort((first, second) => ratingAverage(second) - ratingAverage(first) || second.ratingCount - first.ratingCount);
}

function makeRankMap(photos: readonly FanPhoto[], scope: RankingScope) {
  return new Map(photos.map((photo, index) => {
    if (scope === "personal") return [photo.id, index + 1] as const;
    return [photo.id, index === 0 ? 1 : broaderRankOffsets[scope] + index] as const;
  }));
}

type FanPhotoRankingsProps = {
  readonly photos: readonly FanPhoto[];
  readonly teamId: TeamId;
  readonly eligibilityThreshold: number;
  readonly onOpenItem: (itemId: string) => void;
};

export function FanPhotoRankings({ photos, teamId, eligibilityThreshold, onOpenItem }: FanPhotoRankingsProps) {
  const selectedTeam = findFollowedTeam(teamId);
  const rankingViewportRef = useRef<HTMLDivElement>(null);
  const centerFocusedRowRef = useRef(false);
  const eligiblePhotos = useMemo(() => rankedByRating(photos.filter((photo) => photo.ratingCount >= eligibilityThreshold)), [eligibilityThreshold, photos]);
  const personalPhotos = useMemo(() => eligiblePhotos.filter((photo) => photo.owner.id === demoUser.id), [eligiblePhotos]);
  const rankMaps = useMemo(() => ({
    personal: makeRankMap(personalPhotos, "personal"),
    team: makeRankMap(eligiblePhotos, "team"),
    league: makeRankMap(eligiblePhotos, "league"),
    sport: makeRankMap(eligiblePhotos, "sport"),
    global: makeRankMap(eligiblePhotos, "global"),
  }), [eligiblePhotos, personalPhotos]);
  const populations: Readonly<Record<RankingScope, readonly FanPhoto[]>> = useMemo(() => ({
    personal: personalPhotos,
    team: eligiblePhotos,
    league: eligiblePhotos,
    sport: eligiblePhotos,
    global: eligiblePhotos,
  }), [eligiblePhotos, personalPhotos]);
  const [activeScope, setActiveScope] = useState<RankingScope>("personal");
  const [focusedPhotoId, setFocusedPhotoId] = useState<string | null>(() => personalPhotos[0]?.id ?? null);
  const activePhotos = populations[activeScope];
  const focusedRank = focusedPhotoId ? rankMaps[activeScope].get(focusedPhotoId) : undefined;
  const showJumpToTop = focusedRank !== undefined && focusedRank > 10;

  const contextLabels: Readonly<Record<RankingScope, string>> = {
    personal: "You",
    team: selectedTeam?.shortName ?? "Team",
    league: selectedTeam?.league ?? "League",
    sport: selectedTeam?.sport ?? "Sport",
    global: "All fans",
  };

  useEffect(() => {
    if (focusedPhotoId && activePhotos.some((photo) => photo.id === focusedPhotoId)) return;
    setFocusedPhotoId(activePhotos[0]?.id ?? null);
  }, [activePhotos, focusedPhotoId]);

  useEffect(() => {
    if (!focusedPhotoId || !centerFocusedRowRef.current) return;
    const row = rankingViewportRef.current?.querySelector<HTMLElement>(`[data-fan-photo-id="${focusedPhotoId}"]`);
    row?.scrollIntoView?.({ block: "center", inline: "nearest" });
    centerFocusedRowRef.current = false;
  }, [activeScope, focusedPhotoId]);

  const selectScope = (scope: RankingScope, photoId: string | null = focusedPhotoId) => {
    const nextPopulation = populations[scope];
    const canKeepPhoto = photoId !== null && nextPopulation.some((photo) => photo.id === photoId);
    centerFocusedRowRef.current = true;
    setActiveScope(scope);
    setFocusedPhotoId(canKeepPhoto ? photoId : (nextPopulation[0]?.id ?? null));
  };

  const jumpToTop = () => {
    const topPhoto = activePhotos[0];
    if (!topPhoto) return;
    centerFocusedRowRef.current = false;
    setFocusedPhotoId(topPhoto.id);
    rankingViewportRef.current?.scrollTo?.({ top: 0, behavior: "smooth" });
  };

  return (
    <section className="fan-photo-rankings" aria-labelledby="fan-photo-rankings-title">
      <header className="fan-photo-rankings__intro">
        <div><h3 id="fan-photo-rankings-title">Rankings</h3><p>Select a ranking column to move through the same FANfoto’s wider context.</p></div>
        <span>{eligiblePhotos.length}</span>
      </header>
      {activePhotos.length ? (
        <div ref={rankingViewportRef} className="fan-photo-ranking-viewport" data-active-scope={activeScope}>
          <table className="fan-photo-ranking-table">
            <thead>
              <tr>
                <th className="fan-photo-ranking-table__rated" scope="col">Rated</th>
                <th className="fan-photo-ranking-table__identity" scope="col">
                  {showJumpToTop ? <button className="fan-photo-ranking-table__jump" type="button" aria-label={`Jump to ${scopeLabels[activeScope]} rank 1`} onClick={jumpToTop}><AppIcon name="arrow-up" /><small>Rank #1</small></button> : <span>FANfoto</span>}
                </th>
                {rankingScopes.map((scope) => (
                  <th key={scope} scope="col" data-active={activeScope === scope ? "true" : undefined}>
                    <button type="button" aria-label={`Show ${scopeLabels[scope]} rankings for ${contextLabels[scope]}`} aria-pressed={activeScope === scope} onClick={() => selectScope(scope)}><span>{scopeLabels[scope]}</span><small>{contextLabels[scope]}</small></button>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {activePhotos.map((photo) => (
                <tr key={photo.id} data-fan-photo-id={photo.id} data-focused={focusedPhotoId === photo.id ? "true" : undefined} onFocus={() => setFocusedPhotoId(photo.id)}>
                  <td className="fan-photo-ranking-table__rated"><span aria-label={photo.viewerRating !== null ? `Rated ${photo.viewerRating} out of 5` : "Not yet rated"}>{photo.viewerRating !== null ? <AppIcon name="check" /> : null}</span></td>
                  <td className="fan-photo-ranking-table__identity">
                    <button type="button" aria-label={`Open ${photo.title}`} onClick={() => onOpenItem(photo.id)}>
                      <img src={photo.images[0]?.url} alt="" />
                      <span><strong>{photo.title}</strong><small>@{photo.owner.username}</small><small><AppIcon name="star-solid" /> {formatRating(photo.ratingTotal, photo.ratingCount)} · {photo.ratingCount} ratings</small></span>
                    </button>
                  </td>
                  {rankingScopes.map((scope) => {
                    const rank = rankMaps[scope].get(photo.id);
                    return (
                      <td key={scope} data-active={activeScope === scope ? "true" : undefined}>
                        {rank === undefined ? null : <button type="button" aria-label={`View ${photo.title} at ${scopeLabels[scope]} rank ${rank}`} aria-current={activeScope === scope && focusedPhotoId === photo.id ? "true" : undefined} onClick={() => selectScope(scope, photo.id)}>#{rank}</button>}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : <p className="fan-photo-shelf__empty">No personal FANfotos in this category have reached {eligibilityThreshold} ratings yet.</p>}
    </section>
  );
}
