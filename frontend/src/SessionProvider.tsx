import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, setCsrfToken } from './api'
import { SessionContext, type SessionData } from './session'

const fetchSession = () => api<SessionData>('/api/session')

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<SessionData | null>(null)
  const [failed, setFailed] = useState(false)

  const apply = useCallback((data: SessionData) => {
    setCsrfToken(data.csrf_token)
    setSession(data)
    setFailed(false)
  }, [])

  const refresh = useCallback(async () => {
    try {
      apply(await fetchSession())
    } catch {
      setFailed(true)
    }
  }, [apply])

  const signOut = useCallback(async () => {
    await api('/api/session', { method: 'DELETE' })
    await refresh()
  }, [refresh])

  useEffect(() => {
    let cancelled = false
    fetchSession()
      .then((data) => !cancelled && apply(data))
      .catch(() => !cancelled && setFailed(true))
    return () => {
      cancelled = true
    }
  }, [apply])

  const value = useMemo(() => ({ session, failed, refresh, signOut }), [session, failed, refresh, signOut])
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}
