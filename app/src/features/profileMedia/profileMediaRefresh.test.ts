import { afterEach, describe, expect, it, vi } from "vitest";
import { createCoalescedProfileMediaRefresh } from "./profileMediaRefresh";

describe("profile media refresh coalescing", () => {
  afterEach(() => vi.useRealTimers());

  it("settles a burst of related Realtime events into one refresh", async () => {
    vi.useFakeTimers();
    const refresh = vi.fn(async () => undefined);
    const controller = createCoalescedProfileMediaRefresh(refresh, 100);
    controller.schedule();
    controller.schedule();
    controller.schedule();
    await vi.advanceTimersByTimeAsync(100);
    expect(refresh).toHaveBeenCalledOnce();
    controller.dispose();
  });

  it("allows at most one follow-up when events arrive during an active refresh", async () => {
    vi.useFakeTimers();
    let release!: () => void;
    const refresh = vi.fn(async () => new Promise<void>((resolve) => { release = resolve; }));
    const controller = createCoalescedProfileMediaRefresh(refresh, 100);
    const running = controller.runNow();
    controller.schedule();
    controller.schedule();
    await vi.advanceTimersByTimeAsync(100);
    expect(refresh).toHaveBeenCalledOnce();
    release();
    await running;
    await vi.advanceTimersByTimeAsync(100);
    expect(refresh).toHaveBeenCalledTimes(2);
    controller.dispose();
  });
});
