import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useAuth } from "../account/AuthContext";
import { loadAccountInbox, type AccountInbox } from "./notificationRepository";

const emptyInbox: AccountInbox = {
  unreadCount: 0,
  notifications: [],
  moderationUnreadCount: 0,
  moderationNotices: [],
};

type NotificationContextValue = Readonly<{
  inbox: AccountInbox;
  loading: boolean;
  refresh: () => Promise<AccountInbox>;
}>;

const NotificationContext = createContext<NotificationContextValue | null>(null);

export function NotificationProvider({ children }: { readonly children: ReactNode }) {
  const { configured, loading: authLoading, user } = useAuth();
  const userId = user?.id ?? null;
  const [inboxState, setInboxState] = useState<{ ownerId: string | null; value: AccountInbox }>({ ownerId: null, value: emptyInbox });
  const [loading, setLoading] = useState(false);
  const requestEpoch = useRef(0);
  const inbox = inboxState.ownerId === userId ? inboxState.value : emptyInbox;

  const refresh = useCallback(async () => {
    const epoch = ++requestEpoch.current;
    if (!configured || authLoading || !userId) {
      setInboxState({ ownerId: null, value: emptyInbox });
      return emptyInbox;
    }
    setLoading(true);
    try {
      const next = await loadAccountInbox();
      if (epoch === requestEpoch.current) setInboxState({ ownerId: userId, value: next });
      return next;
    } finally {
      if (epoch === requestEpoch.current) setLoading(false);
    }
  }, [authLoading, configured, userId]);

  useEffect(() => {
    requestEpoch.current += 1;
    setInboxState({ ownerId: null, value: emptyInbox });
    setLoading(false);
    if (!configured || authLoading || !userId) {
      return undefined;
    }
    let current = true;
    const load = async () => {
      const epoch = ++requestEpoch.current;
      try {
        const next = await loadAccountInbox();
        if (current && epoch === requestEpoch.current) setInboxState({ ownerId: userId, value: next });
      } catch {
        // The inbox is non-blocking; the explicit dialog refresh reports errors.
      }
    };
    void load();
    const timer = window.setInterval(() => { void load(); }, 4_000);
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    return () => {
      current = false;
      requestEpoch.current += 1;
      window.clearInterval(timer);
      window.removeEventListener("focus", focus);
    };
  }, [authLoading, configured, userId]);

  const value = useMemo(() => ({ inbox, loading, refresh }), [inbox, loading, refresh]);
  return <NotificationContext.Provider value={value}>{children}</NotificationContext.Provider>;
}

export function useNotifications() {
  const value = useContext(NotificationContext);
  if (!value) throw new Error("useNotifications must be used within NotificationProvider.");
  return value;
}
