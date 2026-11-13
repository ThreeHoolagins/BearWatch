import type { AvatarCrop } from './session'

export type Crop = Pick<AvatarCrop, 'url' | 'width' | 'height' | 'zoom' | 'x' | 'y'>

// Where to draw the photo inside a square so (x, y) of the photo sits at the
// centre, scaled by zoom on top of "cover" fit, never leaving gaps.
// Returned as percentages of the square.
export function cropLayout({ width, height, zoom, x, y }: Omit<Crop, 'url'>) {
  const aspect = width / height
  const w = (aspect >= 1 ? aspect : 1) * zoom
  const h = (aspect >= 1 ? 1 : 1 / aspect) * zoom
  const left = Math.min(0, Math.max(1 - w, 0.5 - x * w))
  const top = Math.min(0, Math.max(1 - h, 0.5 - y * h))
  return { width: w * 100, height: h * 100, left: left * 100, top: top * 100 }
}

// Keeps the centre point where the circle can still be filled.
export function clampCentre(crop: Omit<Crop, 'url'>) {
  const { width, height } = cropLayout({ ...crop, x: 0.5, y: 0.5 })
  const halfX = 50 / width
  const halfY = 50 / height
  return {
    x: Math.min(1 - halfX, Math.max(halfX, crop.x)),
    y: Math.min(1 - halfY, Math.max(halfY, crop.y)),
  }
}
