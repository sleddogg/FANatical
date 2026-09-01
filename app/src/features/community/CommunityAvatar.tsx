import { useEffect, useState } from "react";
import { AppIcon } from "../../components/AppIcon";
import { profileMediaBucket, resolveProfileMediaSignedUrl } from "../profileMedia/profileMediaSignedUrlCache";
import type { CommunityAvatar as CommunityAvatarRecord } from "./types";

export function CommunityAvatar({
  avatar,
  fanaticalName,
}: {
  readonly avatar: CommunityAvatarRecord | null;
  readonly fanaticalName: string | null;
}) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    let current = true;
    setUrl(null);
    if (!avatar?.displayPath || !fanaticalName) return () => { current = false; };
    void resolveProfileMediaSignedUrl(fanaticalName, profileMediaBucket, avatar.displayPath)
      .then((next) => { if (current) setUrl(next); })
      .catch(() => { if (current) setUrl(null); });
    return () => { current = false; };
  }, [avatar?.displayPath, fanaticalName]);

  return (
    <span className="community-avatar" aria-hidden="true">
      {avatar && url ? (
        <img
          src={url}
          alt=""
          style={{
            objectPosition: `${avatar.focalX * 100}% ${avatar.focalY * 100}%`,
            transform: `scale(${avatar.zoom})`,
          }}
        />
      ) : <AppIcon name="user" />}
    </span>
  );
}
