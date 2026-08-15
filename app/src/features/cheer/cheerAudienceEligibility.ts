import { configuredTeamEvents, loadCheckInVenues } from "./cheerCheckIn";
import type { CheerRecord, CrowdAssignment, MappedVenueCheckIn } from "./types";

// Audience requirements are derived from choreography rather than duplicated on
// the Cheer record. Add future venue-dependent Who zones to this model as the
// Venue Mapper's Team Seating Profiles gain corresponding capabilities.
export type AudienceZoneRequirement = Extract<CrowdAssignment, "Upper" | "Lower">;

const levelRequirements = new Set<AudienceZoneRequirement>(["Upper", "Lower"]);

export function deriveAudienceZoneRequirements(cheer: CheerRecord): ReadonlySet<AudienceZoneRequirement> {
  const requirements = new Set<AudienceZoneRequirement>();
  for (const measure of cheer.measures) {
    for (const segment of [...measure.actionSegments, ...measure.lyricSegments]) {
      if (levelRequirements.has(segment.audience as AudienceZoneRequirement)) {
        requirements.add(segment.audience as AudienceZoneRequirement);
      }
    }
  }
  return requirements;
}

function matchingTeamProfile(checkIn: MappedVenueCheckIn) {
  const venue = loadCheckInVenues().find(({ venue: candidate }) => candidate.id === checkIn.raw.venueId)?.venue;
  if (!venue) return null;

  const eventName = checkIn.raw.teamEvent.trim().toLocaleLowerCase();
  const profiles = configuredTeamEvents(venue, checkIn.raw.sport);
  return profiles.find((profile) => profile.teamName.toLocaleLowerCase() === eventName)
    ?? profiles.find((profile) => eventName.includes(profile.teamName.toLocaleLowerCase()))
    ?? null;
}

export function checkInSupportsAudienceZones(cheer: CheerRecord, checkIn: MappedVenueCheckIn) {
  const requirements = deriveAudienceZoneRequirements(cheer);
  if (!requirements.size) return true;

  const profile = matchingTeamProfile(checkIn);
  if (!profile) return false;

  const supported = new Set<AudienceZoneRequirement>();
  if (profile.levels === "Upper + Lower" || profile.levels === "Upper only") supported.add("Upper");
  if (profile.levels === "Upper + Lower" || profile.levels === "Lower only") supported.add("Lower");
  return [...requirements].every((requirement) => supported.has(requirement));
}
