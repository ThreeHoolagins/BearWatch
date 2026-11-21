import { Fragment, useEffect, useRef, useState, type ReactNode } from 'react'
import { bulletinAfter, useBulletins } from '../bulletins'
import type { Post } from '../posts'
import { useSession } from '../session'
import { usePostPages } from '../usePostPages'
import { BulletinCard } from './BulletinCard'
import { PostCard } from './PostCard'
import { PostModal } from './PostModal'

// A scrolling list of post cards that loads more as you near the bottom, with
// a bulletin after every 10 posts.
export function Feed({ url, empty }: { url: string | null; empty: ReactNode }) {
  const { session } = useSession()
  const { posts, hasMore, loading, failed, loadMore, reload } = usePostPages(url)
  const bulletins = useBulletins()
  const [open, setOpen] = useState<Post | null>(null)
  const sentinel = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const target = sentinel.current
    if (!target || !hasMore) return
    const observer = new IntersectionObserver((entries) => entries[0].isIntersecting && loadMore(), { rootMargin: '600px' })
    observer.observe(target)
    return () => observer.disconnect()
  }, [hasMore, loadMore, posts])

  if (posts === null) {
    return failed ? (
      <div className="empty panel">
        Couldn't load bears right now. <button className="link" onClick={() => void reload()}>Try again</button>
      </div>
    ) : (
      <div className="loading">Looking for bears…</div>
    )
  }
  if (posts.length === 0) return <>{empty}</>

  return (
    <>
      {posts.map((post, index) => {
        const bulletin = bulletinAfter(bulletins, index)
        return (
          <Fragment key={post.id}>
            <PostCard post={post} me={session?.user?.nickname} onOpen={setOpen} />
            {bulletin && <BulletinCard bulletin={bulletin} />}
          </Fragment>
        )
      })}
      {hasMore && <div ref={sentinel} className="loading">{loading ? 'Loading more bears…' : ''}</div>}
      {!hasMore && posts.length > 3 && <div className="end">You've reached the end of the trail.</div>}
      {open && <PostModal post={open} onClose={() => setOpen(null)} onChanged={() => void reload()} />}
    </>
  )
}
