export type ProfileAvatarCrop = Readonly<{
  focalX: number;
  focalY: number;
  zoom: number;
}>;

export type ProfileAvatarRecord = Readonly<{
  id?: string;
  sourceFilename: string;
  sourceMediaType: string;
  sourceBlob?: Blob;
  displayBlob?: Blob;
  displayUrl?: string;
  sourcePath?: string;
  displayPath?: string;
  width: number;
  height: number;
  crop: ProfileAvatarCrop;
  updatedAt: string;
}>;

export const defaultProfileAvatarCrop: ProfileAvatarCrop = {
  focalX: 0.5,
  focalY: 0.5,
  zoom: 1,
};

export function clampProfileAvatarCrop(crop: ProfileAvatarCrop): ProfileAvatarCrop {
  return {
    focalX: Math.min(1, Math.max(0, crop.focalX)),
    focalY: Math.min(1, Math.max(0, crop.focalY)),
    zoom: Math.min(4, Math.max(1, crop.zoom)),
  };
}

export function panProfileAvatarCrop(crop: ProfileAvatarCrop, deltaX: number, deltaY: number, width: number, height: number): ProfileAvatarCrop {
  if (!width || !height) return clampProfileAvatarCrop(crop);
  return clampProfileAvatarCrop({
    ...crop,
    focalX: crop.focalX - deltaX / width / crop.zoom,
    focalY: crop.focalY - deltaY / height / crop.zoom,
  });
}

export function pinchProfileAvatarCrop(crop: ProfileAvatarCrop, scale: number, deltaX: number, deltaY: number, width: number, height: number): ProfileAvatarCrop {
  const panned = panProfileAvatarCrop(crop, deltaX, deltaY, width, height);
  return clampProfileAvatarCrop({ ...panned, zoom: crop.zoom * scale });
}
