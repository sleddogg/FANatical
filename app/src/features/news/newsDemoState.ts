import type { NewsDemoSelection, NewsFollowTarget } from "./types";

// Deliberately memory-only: Demo choices are isolated to this browser runtime,
// survive no reload, and are never candidates for account bootstrap.
let activeSelections: readonly NewsDemoSelection[] | null = null;

function key(selection: NewsDemoSelection) {
  return `${selection.targetType}:${selection.targetId}`;
}

export function loadNewsDemoSelections(
  universe: readonly NewsFollowTarget[],
): readonly NewsDemoSelection[] {
  const allowed = new Set(universe.map(key));
  const initial = activeSelections ?? universe;
  activeSelections = initial
    .filter((selection) => allowed.has(key(selection)))
    .map(({ targetType, targetId }) => ({ targetType, targetId }));
  return activeSelections;
}

export function saveNewsDemoSelections(selections: readonly NewsDemoSelection[]) {
  activeSelections = selections.map(({ targetType, targetId }) => ({ targetType, targetId }));
}

export function clearNewsDemoState() {
  activeSelections = null;
}
