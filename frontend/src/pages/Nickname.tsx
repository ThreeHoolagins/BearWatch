import { useEffect, useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, ApiError, setCsrfToken } from '../api'
import { Band } from '../components/Band'
import { useSession } from '../session'
import { useOpenTerms } from '../terms'

type Check = { state: 'idle' } | { state: 'checking' } | { state: 'ok' } | { state: 'bad'; message: string }
type ServerResult = { nickname: string; available: boolean; message: string | null }

// Quick checks that don't need the server; the server re-validates everything.
function localProblem(nickname: string): string | null {
  if (!nickname) return null
  if (!/^[A-Za-z0-9_]+$/.test(nickname)) return 'Letters, numbers and underscores only.'
  if (nickname.length < 3) return 'Use at least 3 characters.'
  return null
}

export function Nickname() {
  const { refresh, signOut } = useSession()
  const openTerms = useOpenTerms()
  const navigate = useNavigate()
  const [nickname, setNickname] = useState('')
  const [server, setServer] = useState<ServerResult | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const local = localProblem(nickname)
  const check: Check = !nickname
    ? { state: 'idle' }
    : local
      ? { state: 'bad', message: local }
      : server?.nickname !== nickname
        ? { state: 'checking' }
        : server.available
          ? { state: 'ok' }
          : { state: 'bad', message: server.message ?? 'Not available.' }

  // Ask the server once typing pauses.
  useEffect(() => {
    if (!nickname || local) return
    const timer = setTimeout(async () => {
      try {
        const result = await api<{ available: boolean; message: string | null }>(
          `/api/nicknames/check?nickname=${encodeURIComponent(nickname)}`,
        )
        setServer({ nickname, ...result })
      } catch (error) {
        // The 30-minute sign-up window ran out: start over.
        if (error instanceof ApiError && error.status === 422) void refresh()
        else setServer({ nickname, available: false, message: "Couldn't check that nickname. Try again." })
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [nickname, local, refresh])

  const submit = async (event: FormEvent) => {
    event.preventDefault()
    if (check.state !== 'ok') return
    setSubmitting(true)
    try {
      const result = await api<{ csrf_token: string }>('/api/signup', { method: 'POST', body: { nickname } })
      setCsrfToken(result.csrf_token)
      navigate('/', { replace: true })
      await refresh()
    } catch (error) {
      const errors = error instanceof ApiError ? (error.body as { errors?: { nickname?: string[] } })?.errors : undefined
      if (errors?.nickname?.length) setServer({ nickname, available: false, message: errors.nickname[0] })
      else await refresh()
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <>
      <Band />
      <div className="cardwrap">
        <form className="card" onSubmit={submit}>
          <h1>Pick a nickname</h1>
          <p className="lede tight">
            This is how other bear watchers will see you. You can't change it later, so choose wisely.
          </p>
          <div className="field">
            <label htmlFor="nickname">Nickname</label>
            <div className="row">
              <input
                id="nickname"
                value={nickname}
                onChange={(event) => setNickname(event.target.value.trim())}
                maxLength={20}
                autoComplete="off"
                autoCapitalize="off"
                spellCheck={false}
                placeholder="e.g. otis_superfan"
                autoFocus
                aria-describedby="nickname-msg"
              />
              <span className="count">{nickname.length}/20</span>
            </div>
            <div id="nickname-msg" className={`msg ${check.state === 'ok' ? 'ok' : check.state === 'bad' ? 'bad' : ''}`} aria-live="polite">
              {check.state === 'ok' && 'Available!'}
              {check.state === 'checking' && 'Checking…'}
              {check.state === 'bad' && check.message}
            </div>
          </div>
          <button className="btn wide" type="submit" disabled={check.state !== 'ok' || submitting}>
            {submitting ? 'Setting up camp…' : 'Start watching bears'}
          </button>
          <p className="fine">
            3 to 20 characters: letters, numbers and underscores. By continuing you agree to the{' '}
            <button type="button" className="link" onClick={openTerms}>Terms of Service</button>.
          </p>
          <p className="fine">
            <button type="button" className="link" onClick={() => void signOut()}>Cancel and go back</button>
          </p>
        </form>
      </div>
    </>
  )
}
