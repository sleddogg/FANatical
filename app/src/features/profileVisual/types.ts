export type ProfileVisualVariant = "mobile" | "wide";

export type ProfileVisualCrop = Readonly<{
  focalX: number;
  focalY: number;
  zoom: number;
}>;

export type ProfileVisualImageRecord = Readonly<{
  id?: string;
  variant: ProfileVisualVariant;
  sourceFilename: string;
  sourceMediaType?: string;
  sourceBlob?: Blob;
  displayBlob?: Blob;
  displayUrl?: string;
  sourcePath?: string;
  displayPath?: string;
  width: number;
  height: number;
  crop: ProfileVisualCrop;
  updatedAt: string;
}>;

export type ProfileVisualLibrary = Readonly<{
  mobile: readonly ProfileVisualImageRecord[];
  wide: readonly ProfileVisualImageRecord[];
}>;

export const defaultProfileVisualCrop: ProfileVisualCrop = { focalX: 0.5, focalY: 0.5, zoom: 1 };

export function clampProfileVisualCrop(crop: ProfileVisualCrop): ProfileVisualCrop {
  return {
    focalX: Math.min(1, Math.max(0, crop.focalX)),
    focalY: Math.min(1, Math.max(0, crop.focalY)),
    zoom: Math.min(3, Math.max(1, crop.zoom)),
  };
}
