export type CoalescedRefresh = Readonly<{
  runNow: () => Promise<void>;
  schedule: () => void;
  dispose: () => void;
}>;

export function createCoalescedProfileMediaRefresh(refresh: () => Promise<void>, delayMs = 100): CoalescedRefresh {
  let disposed = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let inFlight: Promise<void> | undefined;
  let queued = false;

  const runNow = async (): Promise<void> => {
    if (disposed) return;
    if (timer) {
      clearTimeout(timer);
      timer = undefined;
    }
    if (inFlight) {
      queued = true;
      return inFlight;
    }
    inFlight = refresh().finally(() => {
      inFlight = undefined;
      if (queued && !disposed) {
        queued = false;
        schedule();
      }
    });
    return inFlight;
  };

  const schedule = () => {
    if (disposed) return;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = undefined;
      void runNow();
    }, delayMs);
  };

  return {
    runNow,
    schedule,
    dispose: () => {
      disposed = true;
      queued = false;
      if (timer) clearTimeout(timer);
      timer = undefined;
    },
  };
}
