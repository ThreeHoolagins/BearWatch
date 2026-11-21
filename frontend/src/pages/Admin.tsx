import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { api, errorMessage } from '../api'
import { BULLETIN_EVERY, forgetBulletins } from '../bulletins'
import { forgetChampion } from '../champion'
import { Avatar } from '../components/Avatar'
import { BulletinCard } from '../components/BulletinCard'
import { ChampionCard } from '../components/ChampionCard'
import { ShieldIcon } from '../components/icons'
import { Modal } from '../components/Modal'
import { PostModal } from '../components/PostModal'
import { Shell } from '../components/Shell'
import { currentFatBearYear, FIRST_FAT_BEAR_YEAR, LAST_FAT_BEAR_YEAR, profilePath, type AdminUser, type Bulletin, type Champion, type Post, type Win } from '../posts'
import { useSession } from '../session'

export function Admin() {
  const [tab, setTab] = useState<'users' | 'fbw' | 'bulletins'>('users')
  return (
    <Shell wide={tab !== 'users'}>
      <div className="pagehead">
        <h2>Ranger station</h2>
        <span className="near"><ShieldIcon />Admins only</span>
      </div>
      <div className="atabs" role="tablist">
        <button role="tab" aria-selected={tab === 'users'} className={tab === 'users' ? 'on' : ''} onClick={() => setTab('users')}>Users</button>
        <button role="tab" aria-selected={tab === 'fbw'} className={tab === 'fbw' ? 'on' : ''} onClick={() => setTab('fbw')}>Fat Bear Week</button>
        <button role="tab" aria-selected={tab === 'bulletins'} className={tab === 'bulletins' ? 'on' : ''} onClick={() => setTab('bulletins')}>Bulletins</button>
      </div>
      {tab === 'users' ? <UsersTab /> : tab === 'fbw' ? <FatBearWeekTab /> : <BulletinsTab />}
    </Shell>
  )
}

/* ---------------- Users ---------------- */

const joinedLabel = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: 'short', year: 'numeric' })

const BAN_REASONS = ["Photos that aren't bears", 'Photos with people in them', 'Inappropriate nickname', 'Explicit content']

function UsersTab() {
  const { session } = useSession()
  const [query, setQuery] = useState('')
  const [bannedOnly, setBannedOnly] = useState(false)
  const [users, setUsers] = useState<AdminUser[] | null>(null)
  const [banning, setBanning] = useState<AdminUser | null>(null)
  const [problem, setProblem] = useState<string | null>(null)

  const load = useCallback(async () => {
    const params = new URLSearchParams({ q: query.trim(), banned: bannedOnly ? '1' : '' })
    try {
      const data = await api<{ users: AdminUser[] }>(`/api/admin/users?${params}`)
      setUsers(data.users)
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't load users."))
    }
  }, [query, bannedOnly])

  useEffect(() => {
    const timer = setTimeout(() => void load(), 250)
    return () => clearTimeout(timer)
  }, [load])

  const unban = async (user: AdminUser) => {
    try {
      await api(`/api/admin/users/${user.nickname}/ban`, { method: 'DELETE' })
      void load()
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't unban."))
    }
  }

  return (
    <>
      <div className="admin-filters">
        <input className="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search nicknames" aria-label="Search nicknames" />
        <label className="toggle">
          <input type="checkbox" checked={bannedOnly} onChange={(event) => setBannedOnly(event.target.checked)} />
          Banned only
        </label>
      </div>
      {problem && <p className="msg bad pad">{problem}</p>}
      <div className="ulist panel">
        {users === null && <div className="urow meta">Loading…</div>}
        {users?.length === 0 && <div className="urow meta">No bear watchers match.</div>}
        {users?.map((user) => (
          <div className="urow" key={user.id}>
            <Avatar avatar={user.avatar} />
            <div className="info">
              <Link className="uname" to={profilePath(user, session?.user?.nickname)}>{user.nickname}</Link>
              <span className={`status ${user.banned ? 'banned' : 'active'}`}>{user.banned ? 'Banned' : 'Active'}</span>
              {user.ranger && <span className="status ranger">Ranger</span>}
              <div className="meta">
                {user.posts_count} bear{user.posts_count === 1 ? '' : 's'} · joined {joinedLabel(user.created_at)}
              </div>
              {user.banned && user.ban_reason && <div className="why">“{user.ban_reason}”</div>}
            </div>
            {user.banned ? (
              <button className="btn ghost sm" onClick={() => void unban(user)}>Unban</button>
            ) : (
              !user.ranger && <button className="btn ghost danger sm" onClick={() => setBanning(user)}>Ban</button>
            )}
          </div>
        ))}
      </div>
      {banning && <BanModal user={banning} onClose={() => setBanning(null)} onBanned={() => { setBanning(null); void load() }} />}
    </>
  )
}

function BanModal({ user, onClose, onBanned }: { user: AdminUser; onClose: () => void; onBanned: () => void }) {
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)

  const submit = async (event?: FormEvent) => {
    event?.preventDefault()
    setBusy(true)
    try {
      await api(`/api/admin/users/${user.nickname}/ban`, { method: 'POST', body: { reason } })
      onBanned()
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't ban them."))
      setBusy(false)
    }
  }

  return (
    <Modal
      title={`Ban ${user.nickname}?`}
      onClose={onClose}
      size="sm"
      footer={
        <>
          <button className="btn ghost sm" onClick={onClose}>Cancel</button>
          <button className="btn danger sm" onClick={() => void submit()} disabled={busy || !reason.trim()}>Ban user</button>
        </>
      }
    >
      <p className="tight-top">They'll see this reason every time they sign in, and their bears disappear from feeds.</p>
      <div className="chips">
        {BAN_REASONS.map((preset) => (
          <button key={preset} type="button" onClick={() => setReason(`${preset}.`)}>{preset}</button>
        ))}
      </div>
      <form className="field" onSubmit={submit}>
        <label htmlFor="ban-reason">Reason (shown to the user)</label>
        <textarea id="ban-reason" value={reason} onChange={(event) => setReason(event.target.value)} maxLength={500} rows={3} />
      </form>
      {problem && <p className="msg bad">{problem}</p>}
    </Modal>
  )
}

/* ---------------- Fat Bear Week ---------------- */

interface Draft {
  year: number
  bear_name: string
  bear_number: string
  blurb: string
  source: 'post' | 'outside'
  post_id: number | null
  credit: string
  link_url: string
  link_text: string
}

const emptyDraft = (year: number): Draft => ({
  year, bear_name: '', bear_number: '', blurb: '', source: 'outside', post_id: null, credit: '', link_url: '', link_text: '',
})

function FatBearWeekTab() {
  const [draft, setDraft] = useState<Draft>(emptyDraft(currentFatBearYear()))
  const [saved, setSaved] = useState<Champion | null>(null)
  const [posts, setPosts] = useState<Post[]>([])
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)
  const [wins, setWins] = useState<Win[] | null>(null)
  const [openPost, setOpenPost] = useState<Post | null>(null)

  const loadWins = useCallback(async () => {
    const data = await api<{ wins: Win[] }>('/api/admin/wins')
    setWins(data.wins)
  }, [])

  useEffect(() => {
    let cancelled = false
    void Promise.all([
      api<{ champion: Champion | null }>('/api/admin/champion'),
      api<{ posts: Post[] }>('/api/admin/posts'),
      api<{ wins: Win[] }>('/api/admin/wins'),
    ]).then(([{ champion }, { posts }, { wins }]) => {
      if (cancelled) return
      setPosts(posts)
      setWins(wins)
      if (champion) {
        setSaved(champion)
        setDraft({
          year: champion.year, bear_name: champion.bear_name, bear_number: champion.bear_number ?? '', blurb: champion.blurb ?? '',
          source: champion.source, post_id: champion.post_id, credit: champion.credit ?? '', link_url: champion.link_url ?? '',
          link_text: champion.link_text ?? '',
        })
      }
    })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview) }, [preview])

  const set = <K extends keyof Draft>(key: K, value: Draft[K]) => setDraft((current) => ({ ...current, [key]: value }))

  const chosenPost = posts.find((post) => post.id === draft.post_id) ?? null
  const previewPhoto = draft.source === 'post'
    ? chosenPost?.image_url && { url: chosenPost.image_url, width: chosenPost.width ?? 1, height: chosenPost.height ?? 1 }
    : preview ? { url: preview, width: 1, height: 1 } : saved?.source === 'outside' && saved.year === draft.year ? saved.photo : null
  const previewCard: Champion = {
    year: draft.year, bear_name: draft.bear_name || 'Bear name', bear_number: draft.bear_number || null, blurb: draft.blurb || null,
    photo: previewPhoto || null, source: draft.source, post_id: draft.post_id, poster: draft.source === 'post' ? chosenPost?.user ?? null : null,
    credit: draft.source === 'outside' ? draft.credit || null : null, link_url: draft.source === 'outside' ? draft.link_url || null : null,
    link_text: draft.link_text || null,
  }

  const save = async (event: FormEvent) => {
    event.preventDefault()
    setBusy(true)
    setMessage(null)
    const form = new FormData()
    const fields: (keyof Draft)[] = ['bear_name', 'bear_number', 'blurb', 'source', 'credit', 'link_url', 'link_text']
    fields.forEach((key) => form.append(key, String(draft[key] ?? '')))
    if (draft.source === 'post' && draft.post_id) form.append('post_id', String(draft.post_id))
    if (draft.source === 'outside' && file) form.append('photo', file)
    try {
      const { champion } = await api<{ champion: Champion }>(`/api/admin/champion/${draft.year}`, { method: 'PUT', body: form })
      setSaved(champion)
      setFile(null)
      setPreview(null)
      forgetChampion()
      setMessage({ ok: true, text: 'Champion card saved.' })
    } catch (error) {
      setMessage({ ok: false, text: errorMessage(error, "Couldn't save the champion card.") })
    } finally {
      setBusy(false)
    }
  }

  const revoke = async (win: Win) => {
    await api(`/api/admin/wins/${win.id}`, { method: 'DELETE' })
    void loadWins()
  }

  return (
    <div className="fbw">
      <div>
        <form className="form panel" onSubmit={save}>
          <h3>Champion card</h3>
          <div className="two">
            <div className="field">
              <label htmlFor="fbw-year">Year</label>
              <input id="fbw-year" type="number" min={FIRST_FAT_BEAR_YEAR} max={LAST_FAT_BEAR_YEAR} value={draft.year}
                     onChange={(event) => set('year', Number(event.target.value))} />
            </div>
            <div className="field">
              <label htmlFor="fbw-num">Bear number</label>
              <input id="fbw-num" value={draft.bear_number} maxLength={10} placeholder="optional" onChange={(event) => set('bear_number', event.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="fbw-name">Bear name</label>
            <input id="fbw-name" value={draft.bear_name} maxLength={60} onChange={(event) => set('bear_name', event.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="fbw-blurb">Blurb</label>
            <input id="fbw-blurb" value={draft.blurb} maxLength={200} placeholder="Crowned the fattest bear of Fat Bear Week." onChange={(event) => set('blurb', event.target.value)} />
          </div>

          <div className="label">Photo</div>
          <div className="radios">
            <label className={draft.source === 'outside' ? 'on' : ''}>
              <input type="radio" checked={draft.source === 'outside'} onChange={() => set('source', 'outside')} />Outside photo
            </label>
            <label className={draft.source === 'post' ? 'on' : ''}>
              <input type="radio" checked={draft.source === 'post'} onChange={() => set('source', 'post')} />A Bear Watch post
            </label>
          </div>

          {draft.source === 'outside' ? (
            <>
              <div className="field">
                <input type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif" aria-label="Upload photo"
                       onChange={(event) => {
                         const picked = event.target.files?.[0] ?? null
                         setFile(picked)
                         setPreview(picked ? URL.createObjectURL(picked) : null)
                       }} />
                <div className="hint">Re-encoded and stripped of metadata like any upload. Make sure you're allowed to use it, and credit the photographer.</div>
              </div>
              <div className="field">
                <label htmlFor="fbw-credit">Photo credit</label>
                <input id="fbw-credit" value={draft.credit} maxLength={150} placeholder="Photo: NPS / photographer name" onChange={(event) => set('credit', event.target.value)} />
              </div>
              <div className="two">
                <div className="field">
                  <label htmlFor="fbw-link">Link URL</label>
                  <input id="fbw-link" type="url" value={draft.link_url} maxLength={500} placeholder="https://explore.org/fat-bear-week" onChange={(event) => set('link_url', event.target.value)} />
                </div>
                <div className="field">
                  <label htmlFor="fbw-linktext">Link text</label>
                  <input id="fbw-linktext" value={draft.link_text} maxLength={80} placeholder="Fat Bear Week" onChange={(event) => set('link_text', event.target.value)} />
                </div>
              </div>
            </>
          ) : (
            <div className="field">
              <label htmlFor="fbw-post">Post</label>
              <select id="fbw-post" value={draft.post_id ?? ''} onChange={(event) => set('post_id', event.target.value ? Number(event.target.value) : null)}>
                <option value="">Choose a recent post…</option>
                {posts.map((post) => (
                  <option key={post.id} value={post.id}>#{post.id} · {post.user.nickname} · {post.place_name}</option>
                ))}
              </select>
              <div className="hint">Credit links to the poster's profile automatically.</div>
            </div>
          )}

          {message && <p className={`msg ${message.ok ? 'ok' : 'bad'}`}>{message.text}</p>}
          <button className="btn wide" type="submit" disabled={busy || !draft.bear_name.trim()}>
            {busy ? 'Saving…' : 'Save champion card'}
          </button>
        </form>

        <div className="ulist panel winlist">
          <div className="urow title">Fat Bear Wins awarded</div>
          {wins?.length === 0 && <div className="urow meta">None yet.</div>}
          {wins?.map((win) => (
            <div className="urow" key={win.id}>
              <button className="thumb" onClick={() => setOpenPost(win.post)} aria-label="Open post">
                {win.post.image_url && <img src={win.post.image_url} alt="" />}
              </button>
              <div className="info">
                <b>{win.year}</b> · {win.post.user.nickname}
                <div className="meta">#{win.post.id} · {win.post.place_name}</div>
              </div>
              <button className="btn ghost danger sm" onClick={() => void revoke(win)}>Revoke</button>
            </div>
          ))}
          <div className="urow meta">To award a win, open any post and choose “Award win”.</div>
        </div>
      </div>
      <div>
        <p className="previewlabel">Live preview</p>
        <ChampionCard champion={previewCard} />
      </div>
      {openPost && <PostModal post={openPost} onClose={() => setOpenPost(null)} onChanged={() => void loadWins()} />}
    </div>
  )
}

/* ---------------- Bulletins ---------------- */

type BulletinDraft = Omit<Bulletin, 'id' | 'link_url' | 'sponsor'> & { id: number | null; link_url: string; paid: boolean; sponsor: string }

const nextPosition = (bulletins: Bulletin[]) => Math.max(0, ...bulletins.map((bulletin) => bulletin.position)) + 1

const newBulletin = (bulletins: Bulletin[]): BulletinDraft => ({
  id: null, title: '', body: '', kind: 'link', link_url: '', link_text: '', paid: false, sponsor: '', photo: null, active: true, position: nextPosition(bulletins),
})

function BulletinsTab() {
  const [bulletins, setBulletins] = useState<Bulletin[] | null>(null)
  const [draft, setDraft] = useState<BulletinDraft>(newBulletin([]))
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [fileInput, setFileInput] = useState(0) // bumped to clear the file picker

  const load = useCallback(async () => {
    const data = await api<{ bulletins: Bulletin[] }>('/api/admin/bulletins')
    setBulletins(data.bulletins)
    return data.bulletins
  }, [])

  useEffect(() => {
    let cancelled = false
    void api<{ bulletins: Bulletin[] }>('/api/admin/bulletins').then((data) => {
      if (cancelled) return
      setBulletins(data.bulletins)
      setDraft(newBulletin(data.bulletins))
    })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview) }, [preview])

  const set = <K extends keyof BulletinDraft>(key: K, value: BulletinDraft[K]) => setDraft((current) => ({ ...current, [key]: value }))

  const pickPhoto = (picked: File | null) => {
    setFile(picked)
    setPreview(picked ? URL.createObjectURL(picked) : null)
  }

  const clearPicker = () => {
    pickPhoto(null)
    setFileInput((count) => count + 1)
  }

  const startDraft = (next: BulletinDraft) => {
    setDraft(next)
    clearPicker()
  }

  const removePhoto = () => {
    set('photo', null)
    clearPicker()
  }

  const edit = (bulletin: Bulletin) => {
    startDraft({ ...bulletin, link_url: bulletin.link_url ?? '', paid: Boolean(bulletin.sponsor), sponsor: bulletin.sponsor ?? '' })
    setMessage(null)
  }

  const save = async (event: FormEvent) => {
    event.preventDefault()
    setBusy(true)
    setMessage(null)
    const { id, paid, photo, ...fields } = draft
    const form = new FormData()
    Object.entries({ ...fields, sponsor: paid ? fields.sponsor : '' }).forEach(([key, value]) => form.append(key, String(value)))
    if (file) form.append('photo', file)
    else if (!photo) form.append('remove_photo', 'true')
    try {
      const { bulletin } = await api<{ bulletin: Bulletin }>(id ? `/api/admin/bulletins/${id}` : '/api/admin/bulletins', {
        method: id ? 'PATCH' : 'POST',
        body: form,
      })
      await load()
      edit(bulletin)
      forgetBulletins()
      setMessage({ ok: true, text: 'Bulletin saved.' })
    } catch (error) {
      setMessage({ ok: false, text: errorMessage(error, "Couldn't save the bulletin.") })
    } finally {
      setBusy(false)
    }
  }

  const remove = async (bulletin: Bulletin) => {
    if (!window.confirm(`Delete “${bulletin.title}”?`)) return
    await api(`/api/admin/bulletins/${bulletin.id}`, { method: 'DELETE' })
    forgetBulletins()
    const list = await load()
    if (draft.id === bulletin.id) startDraft(newBulletin(list))
  }

  const inFeeds = bulletins?.filter((bulletin) => bulletin.active).length ?? 0
  const previewCard: Bulletin = {
    ...draft, id: draft.id ?? 0, title: draft.title || 'Title', body: draft.body || 'Message', link_text: draft.link_text || 'Button',
    link_url: draft.link_url || '#', sponsor: draft.paid ? draft.sponsor.trim() || 'Sponsor name' : null,
    photo: preview ? { url: preview, width: 1, height: 1 } : draft.photo,
  }

  return (
    <div className="fbw">
      <div>
        <form className="form panel" onSubmit={save}>
          <h3>{draft.id ? 'Edit bulletin' : 'New bulletin'}</h3>
          <div className="field">
            <label htmlFor="bul-title">Title</label>
            <input id="bul-title" value={draft.title} maxLength={80} placeholder="Know a bear enthusiast?" onChange={(event) => set('title', event.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="bul-body">Message</label>
            <textarea id="bul-body" value={draft.body} maxLength={300} rows={4} onChange={(event) => set('body', event.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="bul-photo">Photo (optional)</label>
            <input key={fileInput} id="bul-photo" type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif"
                   onChange={(event) => pickPhoto(event.target.files?.[0] ?? null)} />
            {(file || draft.photo) && (
              <button type="button" className="link" onClick={removePhoto}>Remove photo</button>
            )}
            <div className="hint">Shown full width like a bear post. Re-encoded and stripped of metadata like any upload.</div>
          </div>

          <div className="label">Button</div>
          <div className="radios">
            <label className={draft.kind === 'link' ? 'on' : ''}>
              <input type="radio" checked={draft.kind === 'link'} onChange={() => set('kind', 'link')} />Opens a link
            </label>
            <label className={draft.kind === 'share' ? 'on' : ''}>
              <input type="radio" checked={draft.kind === 'share'} onChange={() => set('kind', 'share')} />Shares Bear Watch
            </label>
          </div>
          <div className="two">
            <div className="field">
              <label htmlFor="bul-text">Button text</label>
              <input id="bul-text" value={draft.link_text} maxLength={40} placeholder={draft.kind === 'share' ? 'Invite a friend' : 'Support on Ko-fi'}
                     onChange={(event) => set('link_text', event.target.value)} required />
            </div>
            {draft.kind === 'link' && (
              <div className="field">
                <label htmlFor="bul-link">Link URL</label>
                <input id="bul-link" type="url" value={draft.link_url} maxLength={500} placeholder="https://ko-fi.com/…"
                       onChange={(event) => set('link_url', event.target.value)} required />
              </div>
            )}
          </div>
          <div className="two">
            <div className="field">
              <label htmlFor="bul-pos">Order</label>
              <input id="bul-pos" type="number" value={draft.position} onChange={(event) => set('position', Number(event.target.value))} />
            </div>
            <label className="toggle bul-active">
              <input type="checkbox" checked={draft.active} onChange={(event) => set('active', event.target.checked)} />
              Show in feeds
            </label>
          </div>
          <label className="toggle bul-paid">
            <input type="checkbox" checked={draft.paid} onChange={(event) => set('paid', event.target.checked)} />
            Paid placement (someone paid to be here)
          </label>
          {draft.paid && (
            <div className="field">
              <label htmlFor="bul-sponsor">Sponsor name</label>
              <input id="bul-sponsor" value={draft.sponsor} maxLength={60} placeholder="REI" onChange={(event) => set('sponsor', event.target.value)} required />
              <div className="hint">Shown as “Sponsored · name” on the card. The law requires paid placements to be clearly labeled.</div>
            </div>
          )}
          <div className="hint bul-hint">
            One bulletin shows after every {BULLETIN_EVERY} posts in Global and Following, cycling through the ones shown in feeds, lowest order first.
          </div>

          {message && <p className={`msg ${message.ok ? 'ok' : 'bad'}`}>{message.text}</p>}
          <button className="btn wide" type="submit" disabled={busy || !draft.title.trim() || !draft.body.trim() || !draft.link_text.trim() || (draft.paid && !draft.sponsor.trim())}>
            {busy ? 'Saving…' : draft.id ? 'Save bulletin' : 'Add bulletin'}
          </button>
        </form>

        <div className="ulist panel winlist">
          <div className="urow title">
            <span className="info">Bulletins <span className="meta">· {inFeeds} in feeds</span></span>
            {draft.id && <button className="btn ghost sm" onClick={() => startDraft(newBulletin(bulletins ?? []))}>New bulletin</button>}
          </div>
          {bulletins?.length === 0 && <div className="urow meta">None yet. Feeds show only bears.</div>}
          {bulletins?.map((bulletin) => (
            <div className={`urow ${bulletin.id === draft.id ? 'picked' : ''}`} key={bulletin.id}>
              <div className="info">
                <b>{bulletin.position}.</b> {bulletin.title}
                {bulletin.sponsor && <span className="status ranger">Sponsored</span>}
                {!bulletin.active && <span className="status banned">Hidden</span>}
                <div className="meta">{bulletin.kind === 'share' ? 'Shares Bear Watch' : bulletin.link_url}</div>
              </div>
              <button className="btn ghost sm" onClick={() => edit(bulletin)}>Edit</button>
              <button className="btn ghost danger sm" onClick={() => void remove(bulletin)}>Delete</button>
            </div>
          ))}
        </div>
      </div>
      <div>
        <p className="previewlabel">Live preview</p>
        <BulletinCard bulletin={previewCard} />
      </div>
    </div>
  )
}
