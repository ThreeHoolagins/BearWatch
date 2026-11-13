import { useEffect, useRef, useState, type PointerEvent } from 'react'
import { api, errorMessage } from '../api'
import type { Post, PostPage } from '../posts'
import type { AvatarCrop } from '../session'
import { clampCentre, cropLayout } from '../avatarCrop'
import { Avatar } from './Avatar'
import { BlankBear } from './icons'
import { Modal } from './Modal'

type Draft = { post: Post; zoom: number; x: number; y: number } | null

// Start a crop centred on the bear the detector found, zoomed to fit it.
function initialDraft(post: Post): Draft {
  const width = post.width ?? 1
  const height = post.height ?? 1
  if (!post.bear_box) return { post, zoom: 1, x: 0.5, y: 0.5 }
  const [bx, by, bw, bh] = post.bear_box
  const fit = Math.min(width, height) / Math.max(bw * width, bh * height, 1)
  const zoom = Math.min(4, Math.max(1, fit * 0.95))
  return { post, zoom, ...clampCentre({ width, height, zoom, x: bx, y: by }) }
}

function toCrop(draft: NonNullable<Draft>): AvatarCrop {
  return { url: draft.post.image_url ?? '', width: draft.post.width ?? 1, height: draft.post.height ?? 1, zoom: draft.zoom, x: draft.x, y: draft.y }
}

export function AvatarPicker({ nickname, current, onClose, onSaved }: {
  nickname: string
  current: AvatarCrop | null
  onClose: () => void
  onSaved: () => void
}) {
  const [posts, setPosts] = useState<Post[] | null>(null)
  const [draft, setDraft] = useState<Draft>(null)
  const [saving, setSaving] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const drag = useRef<{ x: number; y: number; size: number } | null>(null)

  useEffect(() => {
    let cancelled = false
    api<PostPage>(`/api/users/${encodeURIComponent(nickname)}/posts`)
      .then((page) => {
        if (cancelled) return
        setPosts(page.posts)
        const selected = current && page.posts.find((post) => post.image_url === current.url)
        setDraft(selected ? { post: selected, zoom: current.zoom, x: current.x, y: current.y } : null)
      })
      .catch(() => !cancelled && setPosts([]))
    return () => {
      cancelled = true
    }
  }, [nickname, current])

  const startDrag = (event: PointerEvent<HTMLDivElement>) => {
    if (!draft) return
    event.currentTarget.setPointerCapture(event.pointerId)
    drag.current = { x: event.clientX, y: event.clientY, size: event.currentTarget.clientWidth }
  }

  // Dragging the photo right reveals more of its left side, so x goes down.
  const moveDrag = (event: PointerEvent<HTMLDivElement>) => {
    if (!drag.current || !draft) return
    const layout = cropLayout({ width: draft.post.width ?? 1, height: draft.post.height ?? 1, zoom: draft.zoom, x: draft.x, y: draft.y })
    const dx = (event.clientX - drag.current.x) / drag.current.size / (layout.width / 100)
    const dy = (event.clientY - drag.current.y) / drag.current.size / (layout.height / 100)
    drag.current = { ...drag.current, x: event.clientX, y: event.clientY }
    const next = clampCentre({ width: draft.post.width ?? 1, height: draft.post.height ?? 1, zoom: draft.zoom, x: draft.x - dx, y: draft.y - dy })
    setDraft({ ...draft, ...next })
  }

  const setZoom = (zoom: number) => {
    if (!draft) return
    setDraft({ ...draft, zoom, ...clampCentre({ width: draft.post.width ?? 1, height: draft.post.height ?? 1, zoom, x: draft.x, y: draft.y }) })
  }

  const save = async () => {
    setSaving(true)
    setProblem(null)
    try {
      const body = draft ? { post_id: draft.post.id, zoom: draft.zoom, x: draft.x, y: draft.y } : { post_id: null }
      await api('/api/me/avatar', { method: 'PUT', body })
      onSaved()
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't save your bear face. Try again."))
      setSaving(false)
    }
  }

  return (
    <Modal
      title="Choose your bear face"
      onClose={onClose}
      footer={
        <>
          <button className="btn ghost sm" onClick={onClose}>Cancel</button>
          <button className="btn sm" onClick={() => void save()} disabled={saving || posts === null}>
            {saving ? 'Saving…' : 'Save bear face'}
          </button>
        </>
      }
    >
      <div className="avpick">
        <div className="avprev">
          <div
            className={`ring-wrap ${draft ? 'draggable' : ''}`}
            onPointerDown={startDrag}
            onPointerMove={moveDrag}
            onPointerUp={() => (drag.current = null)}
            onPointerCancel={() => (drag.current = null)}
          >
            <Avatar avatar={draft && toCrop(draft)} size="ring" />
          </div>
          {draft ? (
            <>
              <input
                type="range"
                min={1}
                max={4}
                step={0.05}
                value={draft.zoom}
                onChange={(event) => setZoom(Number(event.target.value))}
                aria-label="Zoom"
              />
              <div className="hint">Drag the photo and zoom to frame the bear's face.</div>
            </>
          ) : (
            <div className="hint">The classic blank bear</div>
          )}
        </div>
        <div>
          {posts === null && <p className="fine">Loading your bears…</p>}
          {posts?.length === 0 && <p className="fine">Post a bear first, then you can use it as your bear face.</p>}
          {posts && posts.length > 0 && <p className="lead">Pick one of your photos. We'll start on the bear.</p>}
          <div className="avgrid">
            <button className={`blank ${!draft ? 'on' : ''}`} onClick={() => setDraft(null)} aria-label="Blank bear">
              <BlankBear />
            </button>
            {posts?.map((post) => (
              <button
                key={post.id}
                className={draft?.post.id === post.id ? 'on' : ''}
                onClick={() => setDraft(initialDraft(post))}
                aria-label={`Use the bear from ${post.place_name}`}
              >
                {post.image_url && <img src={post.image_url} alt="" loading="lazy" />}
              </button>
            ))}
          </div>
          {problem && <p className="msg bad">{problem}</p>}
        </div>
      </div>
    </Modal>
  )
}
