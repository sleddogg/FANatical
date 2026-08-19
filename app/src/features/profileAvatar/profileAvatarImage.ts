import { defaultProfileAvatarCrop, type ProfileAvatarRecord } from "./types";

const supportedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

function canvasBlob(canvas: HTMLCanvasElement) {
  return new Promise<Blob>((resolve, reject) => canvas.toBlob(
    (blob) => blob ? resolve(blob) : reject(new Error("The selected profile photo could not be processed.")),
    "image/webp",
    0.88,
  ));
}

async function decodeWithImage(file: File) {
  const url = URL.createObjectURL(file);
  const image = new Image();
  try {
    image.src = url;
    await image.decode();
    return {
      width: image.naturalWidth,
      height: image.naturalHeight,
      draw: (context: CanvasRenderingContext2D, width: number, height: number) => context.drawImage(image, 0, 0, width, height),
      close: () => URL.revokeObjectURL(url),
    };
  } catch (reason) {
    URL.revokeObjectURL(url);
    throw reason;
  }
}

export async function prepareProfileAvatarImage(file: File): Promise<ProfileAvatarRecord> {
  if (!supportedTypes.has(file.type)) throw new Error("Choose a JPEG, PNG, or WebP image.");
  if (!file.size) throw new Error("The selected profile photo is empty or invalid.");

  let width: number;
  let height: number;
  let draw: (context: CanvasRenderingContext2D, width: number, height: number) => void;
  let close: (() => void) | undefined;

  if (typeof createImageBitmap === "function") {
    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
      width = bitmap.width;
      height = bitmap.height;
      draw = (context, targetWidth, targetHeight) => context.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
      close = () => bitmap.close();
    } catch {
      const decoded = await decodeWithImage(file);
      ({ width, height, draw } = decoded);
      close = decoded.close;
    }
  } else {
    const decoded = await decodeWithImage(file);
    ({ width, height, draw } = decoded);
    close = decoded.close;
  }

  try {
    const maximumDimension = 1024;
    const scale = Math.min(1, maximumDimension / Math.max(width, height));
    const displayWidth = Math.max(1, Math.round(width * scale));
    const displayHeight = Math.max(1, Math.round(height * scale));
    const canvas = document.createElement("canvas");
    canvas.width = displayWidth;
    canvas.height = displayHeight;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("The selected profile photo could not be processed.");
    draw(context, displayWidth, displayHeight);

    return {
      sourceFilename: file.name,
      sourceMediaType: file.type,
      sourceBlob: file,
      displayBlob: await canvasBlob(canvas),
      width,
      height,
      crop: defaultProfileAvatarCrop,
      updatedAt: new Date().toISOString(),
    };
  } finally {
    close?.();
  }
}
