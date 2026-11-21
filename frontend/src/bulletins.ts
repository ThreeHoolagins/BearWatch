import { useEffect, useState } from 'react'
import { api } from './api'
import type { Bulletin } from './posts'

// One bulletin after every this many posts, cycling through them in order.
export const BULLETIN_EVERY = 10

// Bulletins rarely change, so they're fetched once per page load.
let cached: Promise<Bulletin[]> | null = null

export function forgetBulletins() {
  cached = null
}

export function useBulletins() {
  const [bulletins, setBulletins] = useState<Bulletin[]>([])
  useEffect(() => {
    let cancelled = false
    cached ??= api<{ bulletins: Bulletin[] }>('/api/bulletins')
      .then((data) => data.bulletins)
      .catch(() => {
        cached = null
        return []
      })
    void cached.then((value) => !cancelled && setBulletins(value))
    return () => {
      cancelled = true
    }
  }, [])
  return bulletins
}

// The bulletin that follows the post at `index`, if one goes there.
export function bulletinAfter(bulletins: Bulletin[], index: number): Bulletin | null {
  const slot = (index + 1) / BULLETIN_EVERY
  if (!bulletins.length || !Number.isInteger(slot)) return null
  return bulletins[(slot - 1) % bulletins.length]
}
