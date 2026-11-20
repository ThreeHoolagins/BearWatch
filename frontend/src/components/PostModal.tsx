import { useState } from 'react'
import { Link } from 'react-router-dom'
import { api, errorMessage } from '../api'
import { forgetChampion } from '../champion'
import { currentFatBearYear, FIRST_FAT_BEAR_YEAR, LAST_FAT_BEAR_YEAR, profilePath, timeAgo, type Post } from '../posts'
import { useSession } from '../session'
import { Avatar } from './Avatar'
import { PinIcon, TrophyIcon } from './icons'
import { Modal } from './Modal'
import { PhotoCredit } from './PhotoCredit'

// onChanged: the post was awarded/revoked/removed, so lists should reload.
export function PostModal({ post: initial, onClose, onChanged }: { post: Post; onClose: () => void; onChanged?: () => void }) {
  const { session } = useSession()
  const [post, setPost] = useState(initial)
  const isAdmin = session?.user?.is_admin ?? false
  const isMine = post.user.nickname === session?.user?.nickname
  const removed = () => {
    onChanged?.()
    onClose()
  }

  return (
    <Modal
      title={`Bear spotted by ${post.user.nickname}`}
      onClose={onClose}
      size="sm"
      className="postm"
      footer={
        isAdmin ? (
          <RangerTools post={post} onPost={setPost} onRemoved={removed} onChanged={onChanged} />
        ) : isMine ? (
          <OwnerTools post={post} onRemoved={removed} />
        ) : undefined
      }
    >
      <Link className="who" to={profilePath(post.user, session?.user?.nickname)} onClick={onClose}>
        <Avatar avatar={post.user.avatar} />
        <b>{post.user.nickname}</b>
        <time dateTime={post.created_at}>{timeAgo(post.created_at)}</time>
      </Link>
      {post.image_url && <img className="full" src={post.image_url} alt={`Bear at ${post.place_name}`} />}
      <div className="where">
        <PinIcon />
        {post.place_name}
        {post.fat_bear_win && <span className="winbadge inline"><TrophyIcon />Fat Bear Week {post.fat_bear_win.year} winner</span>}
      </div>
      <PhotoCredit post={post} />
    </Modal>
  )
}

// Your own post: delete it (asks once to confirm).
function OwnerTools({ post, onRemoved }: { post: Post; onRemoved: () => void }) {
  const [confirming, setConfirming] = useState(false)
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  const remove = async () => {
    setBusy(true)
    setProblem(null)
    try {
      await api(`/api/posts/${post.id}`, { method: 'DELETE' })
      onRemoved()
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't delete that. Try again."))
      setBusy(false)
    }
  }

  return (
    <div className="ranger-tools">
      {confirming && <span className="confirm">Delete this bear for good?</span>}
      {confirming && <button className="btn ghost sm" onClick={() => setConfirming(false)} disabled={busy}>Keep it</button>}
      <button className="btn ghost danger sm" onClick={() => (confirming ? void remove() : setConfirming(true))} disabled={busy}>
        {confirming ? 'Delete' : 'Delete post'}
      </button>
      {problem && <p className="msg bad">{problem}</p>}
    </div>
  )
}

// Newest first, for the award picker.
const YEARS = Array.from({ length: LAST_FAT_BEAR_YEAR - FIRST_FAT_BEAR_YEAR + 1 }, (_, i) => LAST_FAT_BEAR_YEAR - i)

// Admin-only: award/revoke a Fat Bear Week win, or take the post down.
function RangerTools({ post, onPost, onRemoved, onChanged }: {
  post: Post
  onPost: (post: Post) => void
  onRemoved: () => void
  onChanged?: () => void
}) {
  const [year, setYear] = useState(currentFatBearYear())
  const [busy, setBusy] = useState(false)
  const [confirmRemove, setConfirmRemove] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  const run = async (action: () => Promise<void>) => {
    setBusy(true)
    setProblem(null)
    try {
      await action()
    } catch (error) {
      setProblem(errorMessage(error, "That didn't work. Try again."))
    } finally {
      setBusy(false)
    }
  }

  const award = () => run(async () => {
    const { win } = await api<{ win: { id: number; year: number } }>('/api/admin/wins', { method: 'POST', body: { post_id: post.id, year } })
    onPost({ ...post, fat_bear_win: { id: win.id, year: win.year } })
    forgetChampion()
    onChanged?.()
  })

  const revoke = () => run(async () => {
    if (!post.fat_bear_win) return
    await api(`/api/admin/wins/${post.fat_bear_win.id}`, { method: 'DELETE' })
    onPost({ ...post, fat_bear_win: null })
    onChanged?.()
  })

  const remove = () => run(async () => {
    await api(`/api/admin/posts/${post.id}`, { method: 'DELETE' })
    onRemoved()
  })

  return (
    <div className="ranger-tools">
      <span className="adminchip">Ranger</span>
      {post.fat_bear_win ? (
        <button className="btn ghost sm" onClick={() => void revoke()} disabled={busy}>Revoke {post.fat_bear_win.year} win</button>
      ) : (
        <span className="award">
          <select value={year} onChange={(event) => setYear(Number(event.target.value))} aria-label="Fat Bear Week year">
            {YEARS.map((y) => <option key={y} value={y}>{y}</option>)}
          </select>
          <button className="btn gold sm" onClick={() => void award()} disabled={busy}><TrophyIcon />Award win</button>
        </span>
      )}
      <button className="btn ghost danger sm" onClick={() => (confirmRemove ? void remove() : setConfirmRemove(true))} disabled={busy}>
        {confirmRemove ? 'Really remove?' : 'Remove post'}
      </button>
      {problem && <p className="msg bad">{problem}</p>}
    </div>
  )
}
