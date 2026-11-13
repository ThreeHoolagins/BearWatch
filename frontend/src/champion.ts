import { useEffect, useState } from 'react'
import { api } from './api'
import type { Champion } from './posts'

// The champion card rarely changes, so it's fetched once per page load and
// shared by the sidebar and the mobile banner.
let cached: Promise<Champion | null> | null = null

export function forgetChampion() {
  cached = null
}

export function useChampion() {
  const [champion, setChampion] = useState<Champion | null>(null)
  useEffect(() => {
    let cancelled = false
    cached ??= api<{ champion: Champion | null }>('/api/champion')
      .then((data) => data.champion)
      .catch(() => {
        cached = null
        return null
      })
    void cached.then((value) => !cancelled && setChampion(value))
    return () => {
      cancelled = true
    }
  }, [])
  return champion
}
