import { useState } from "react";
import { loadRexallVenue, saveRexallVenue } from "./rexallVenueData";
import type { VenueMapping } from "./types";

export function useRexallVenue() {
  const [venue, setVenueState] = useState<VenueMapping>(loadRexallVenue);
  const setVenue = (next: VenueMapping | ((current: VenueMapping) => VenueMapping)) => {
    setVenueState((current) => saveRexallVenue(typeof next === "function" ? next(current) : next));
  };
  return [venue, setVenue] as const;
}
