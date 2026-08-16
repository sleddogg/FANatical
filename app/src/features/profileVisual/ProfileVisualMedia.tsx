import { useEffect, useState } from "react";
import type { ProfileVisualCrop, ProfileVisualImageRecord } from "./types";

export function useProfileVisualUrl(blob: Blob | undefined, remoteUrl?: string) {
  const [url, setUrl] = useState<string | null>(remoteUrl ?? null);

  useEffect(() => {
    if (!blob) { setUrl(remoteUrl ?? null); return; }
    const nextUrl = URL.createObjectURL(blob);
    setUrl(nextUrl);
    return () => URL.revokeObjectURL(nextUrl);
  }, [blob, remoteUrl]);

  return url;
}

export function cropImageStyle(crop: ProfileVisualCrop) {
  return {
    objectPosition: `${crop.focalX * 100}% ${crop.focalY * 100}%`,
    transform: `scale(${crop.zoom})`,
    transformOrigin: `${crop.focalX * 100}% ${crop.focalY * 100}%`,
  };
}

export function ProfileVisualMedia({ record, className = "" }: { readonly record: ProfileVisualImageRecord; readonly className?: string }) {
  const url = useProfileVisualUrl(record.displayBlob, record.displayUrl);
  return url ? <img className={className} src={url} alt="" aria-hidden="true" style={cropImageStyle(record.crop)} /> : null;
}
