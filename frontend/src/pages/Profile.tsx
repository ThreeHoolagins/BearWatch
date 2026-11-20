import { useCallback, useEffect, useState, type ReactElement } from 'react'
import { Link, Navigate, useParams, useSearchParams } from 'react-router-dom'
import { api, errorMessage } from '../api'
import { Avatar } from '../components/Avatar'
import { AvatarPicker } from '../components/AvatarPicker'
import { CheckIcon, GitHubIcon, GoogleIcon, ShieldIcon, SignOutIcon, TrophyIcon } from '../components/icons'
import { PostModal } from '../components/PostModal'
import { Shell } from '../components/Shell'
import { SsoButton } from '../components/SsoButton'
import type { Post, Profile as ProfileData } from '../posts'
import { PROVIDER_LABELS, useSession, type Provider } from '../session'
import { useOpenPrivacy, useOpenTerms } from '../terms'
import { usePostPages } from '../usePostPages'

const LINK_ERRORS: Record<string, string> = {
  taken: 'That account is already linked to a different Bear Watch user.',
  already_linked: 'You already have an account from that provider linked.',
}

const PROVIDER_ICONS: Partial<Record<Provider, ReactElement>> = {
  google_oauth2: <GoogleIcon />,
  github: <GitHubIcon />,
}

// /profile: your own profile.
export function MyProfile() {
  const { session } = useSession()
  return session?.user ? <ProfileView nickname={session.user.nickname} /> : null
}

// /u/:nickname: someone else's profile (or yours, which redirects).
export function UserProfile() {
  const { nickname = '' } = useParams()
  const { session } = useSession()
  if (nickname === session?.user?.nickname) return <Navigate to="/profile" replace />
  return <ProfileView key={nickname} nickname={nickname} />
}

function ProfileView({ nickname }: { nickname: string }) {
  const { refresh } = useSession()
  const [profile, setProfile] = useState<ProfileData | null>(null)
  const [missing, setMissing] = useState(false)
  const [open, setOpen] = useState<Post | null>(null)
  const [picking, setPicking] = useState(false)
  const [followBusy, setFollowBusy] = useState(false)
  const [problem, setProblem] = useState<string | null>(null)
  const grid = usePostPages(`/api/users/${encodeURIComponent(nickname)}/posts`)

  const loadProfile = useCallback(async () => {
    try {
      const { user } = await api<{ user: ProfileData }>(`/api/users/${encodeURIComponent(nickname)}`)
      setProfile(user)
    } catch {
      setMissing(true)
    }
  }, [nickname])

  useEffect(() => {
    let cancelled = false
    api<{ user: ProfileData }>(`/api/users/${encodeURIComponent(nickname)}`)
      .then(({ user }) => !cancelled && setProfile(user))
      .catch(() => !cancelled && setMissing(true))
    return () => {
      cancelled = true
    }
  }, [nickname])

  const toggleFollow = async () => {
    if (!profile) return
    setFollowBusy(true)
    setProblem(null)
    try {
      const result = await api<{ following: boolean; followers_count: number }>(
        `/api/users/${encodeURIComponent(nickname)}/follow`,
        { method: profile.following ? 'DELETE' : 'POST' },
      )
      setProfile({ ...profile, following: result.following, followers_count: result.followers_count })
    } catch (error) {
      setProblem(errorMessage(error, "Couldn't update that. Try again."))
    } finally {
      setFollowBusy(false)
    }
  }

  if (missing) {
    return (
      <Shell back>
        <div className="empty panel">
          <h3>Trail not found</h3>
          There's no bear watcher called <b>{nickname}</b>.
          <br />
          <Link className="btn" to="/">Back to Global</Link>
        </div>
      </Shell>
    )
  }

  const count = profile?.posts_count ?? grid.posts?.length ?? 0

  return (
    <Shell back={profile ? !profile.me : true}>
      <div className="phead">
        <Avatar avatar={profile?.avatar} size="xl" />
        <div>
          <h2>
            {nickname}
            {profile?.ranger && <span className="adminchip">Ranger</span>}
          </h2>
          <div className="stats">
            <div><b>{profile?.followers_count ?? '–'}</b><small>Followers</small></div>
            <div><b>{profile?.following_count ?? '–'}</b><small>Following</small></div>
            <div><b><TrophyIcon className="gold" />{profile?.fat_bear_wins ?? '–'}</b><small>Fat Bear Wins</small></div>
          </div>
        </div>
      </div>

      {profile && (
        <div className="pactions">
          {profile.me ? (
            <button className="btn ghost" onClick={() => setPicking(true)}>Change bear face</button>
          ) : (
            <button className={`btn ${profile.following ? 'ghost' : ''}`} onClick={() => void toggleFollow()} disabled={followBusy}>
              {profile.following ? 'Following ✓' : 'Follow'}
            </button>
          )}
        </div>
      )}
      {problem && <p className="msg bad pad">{problem}</p>}

      <div className="ptitle">
        {grid.posts === null ? 'Loading bears…' : `${count} bear${count === 1 ? '' : 's'} spotted`}
      </div>
      {grid.posts?.length === 0 && (
        <p className="fine pad">
          {profile?.me ? (
            <>Photos you post will show up here, three across. <Link className="link" to="/post">Post your first bear</Link></>
          ) : (
            'No bears spotted yet.'
          )}
        </p>
      )}
      {grid.posts && grid.posts.length > 0 && (
        <div className="grid3">
          {grid.posts.map((post) => (
            <button key={post.id} className="tile" onClick={() => setOpen(post)} aria-label={`Bear at ${post.place_name}`}>
              {post.image_url && <img src={post.image_url} alt="" loading="lazy" />}
              {post.fat_bear_win && (
                <span className="winbadge"><TrophyIcon /><span>Fat Bear Week {post.fat_bear_win.year}</span></span>
              )}
            </button>
          ))}
        </div>
      )}
      {grid.hasMore && (
        <div className="center more">
          <button className="btn ghost sm" onClick={grid.loadMore} disabled={grid.loading}>
            {grid.loading ? 'Loading…' : 'Show more bears'}
          </button>
        </div>
      )}
      {open && (
        <PostModal
          post={open}
          onClose={() => setOpen(null)}
          onChanged={() => {
            void grid.reload()
            void loadProfile()
          }}
        />
      )}

      {profile?.me && <MyAccount />}

      {picking && profile && (
        <AvatarPicker
          nickname={nickname}
          current={profile.avatar}
          onClose={() => setPicking(false)}
          onSaved={() => {
            setPicking(false)
            void loadProfile()
            void refresh() // updates the header avatar
          }}
        />
      )}
    </Shell>
  )
}

// Only on your own profile: linked sign-ins, and (on phones) admin + sign out.
function MyAccount() {
  const { session, signOut } = useSession()
  const openTerms = useOpenTerms()
  const openPrivacy = useOpenPrivacy()
  const [params] = useSearchParams()
  const user = session?.user
  const linked = session?.linked_providers ?? []
  // Offer every real provider that's switched on, plus any already linked.
  const providers = [...new Set([...(session?.providers ?? []), ...linked])].filter((p) => p !== 'developer' || linked.includes(p))
  const justLinked = params.get('linked') as Provider | null
  const linkError = params.get('link_error')

  return (
    <>
      <section className="signins panel">
        <h3>Sign-in methods</h3>
        <p className="fine">Link more than one so you can always get back into your account.</p>
        {justLinked && <div className="alert ok">{PROVIDER_LABELS[justLinked] ?? 'Account'} is now linked.</div>}
        {linkError && <div className="alert">{LINK_ERRORS[linkError] ?? "Couldn't link that account."}</div>}
        {providers.map((provider) => (
          <div className="signin-row" key={provider}>
            <span className="pname">
              {PROVIDER_ICONS[provider]}
              {PROVIDER_LABELS[provider]}
            </span>
            {linked.includes(provider) ? (
              <span className="okchip"><CheckIcon />Linked</span>
            ) : (
              <SsoButton provider={provider} className="btn ghost sm">Link</SsoButton>
            )}
          </div>
        ))}
      </section>

      <div className="meonly mob">
        {user?.is_admin && (
          <Link className="btn ghost" to="/admin"><ShieldIcon />Admin panel</Link>
        )}
        <button className="btn ghost danger" onClick={() => void signOut()}><SignOutIcon />Sign out</button>
        <p className="fine center">
          <button className="link" onClick={openTerms}>Terms of Service</button> ·{' '}
          <button className="link" onClick={openPrivacy}>Privacy Policy</button>
        </p>
      </div>
    </>
  )
}
