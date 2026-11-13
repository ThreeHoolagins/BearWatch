import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from './api'
import type { Post, PostPage } from './posts'

// Loads a paginated list of posts (newest first). `url` null means "don't
// load yet" (e.g. waiting for location). Changing the url starts over.
export function usePostPages(url: string | null) {
  const [posts, setPosts] = useState<Post[] | null>(null)
  const [nextBefore, setNextBefore] = useState<number | null>(null)
  const [loading, setLoading] = useState(false)
  const [failed, setFailed] = useState(false)
  const generation = useRef(0)

  const fetchPage = useCallback(
    async (before: number | null) => {
      if (!url) return
      const mine = generation.current
      setLoading(true)
      try {
        const separator = url.includes('?') ? '&' : '?'
        const page = await api<PostPage>(before ? `${url}${separator}before=${before}` : url)
        if (mine !== generation.current) return
        setPosts((current) => (before && current ? [...current, ...page.posts] : page.posts))
        setNextBefore(page.next_before)
        setFailed(false)
      } catch {
        if (mine === generation.current) setFailed(true)
      } finally {
        if (mine === generation.current) setLoading(false)
      }
    },
    [url],
  )

  useEffect(() => {
    generation.current += 1
    if (!url) return
    let cancelled = false
    // Deferred a tick so state isn't set synchronously inside the effect.
    void Promise.resolve().then(() => {
      if (!cancelled) void fetchPage(null)
    })
    return () => {
      cancelled = true
    }
  }, [url, fetchPage])

  const loadMore = useCallback(() => {
    if (nextBefore && !loading) void fetchPage(nextBefore)
  }, [nextBefore, loading, fetchPage])

  return { posts, hasMore: nextBefore !== null, loading, failed, loadMore, reload: () => fetchPage(null) }
}
