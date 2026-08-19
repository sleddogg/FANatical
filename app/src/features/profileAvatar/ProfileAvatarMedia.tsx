import { useEffect, useState } from "react";
import { AppIcon } from "../../components/AppIcon";
import type { ProfileAvatarCrop, ProfileAvatarRecord } from "./types";

export function profileAvatarImageStyle(crop: ProfileAvatarCrop) {
  return {
    objectPosition: `${crop.focalX * 100}% ${crop.focalY * 100}%`,
    transform: `scale(${crop.zoom})`,
    transformOrigin: `${crop.focalX * 100}% ${crop.focalY * 100}%`,
  };
}

export function useProfileAvatarUrl(record: ProfileAvatarRecord | null | undefined) {
  const [url, setUrl] = useState<string | null>(record?.displayUrl ?? null);

  useEffect(() => {
    if (!record?.displayBlob) {
      setUrl(record?.displayUrl ?? null);
      return;
    }
    const objectUrl = URL.createObjectURL(record.displayBlob);
    setUrl(objectUrl);
    return () => URL.revokeObjectURL(objectUrl);
  }, [record?.displayBlob, record?.displayUrl]);

  return url;
}

export function ProfileAvatarMedia({ avatar, className = "" }: { readonly avatar: ProfileAvatarRecord | null; readonly className?: string }) {
  const url = useProfileAvatarUrl(avatar);
  return (
    <span className={`profile-avatar-media${className ? ` ${className}` : ""}`} aria-hidden="true">
      {avatar && url
        ? <img src={url} alt="" draggable={false} style={profileAvatarImageStyle(avatar.crop)} />
        : <AppIcon name="user" />}
    </span>
  );
}
