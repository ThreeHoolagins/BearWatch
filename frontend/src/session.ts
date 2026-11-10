import { createContext, useContext } from 'react'

export type Provider = 'google_oauth2' | 'github' | 'developer'

export interface User {
  id: number
  nickname: string
  is_admin: boolean
  banned: boolean
  ban_reason: string | null
}

export interface SessionData {
  csrf_token: string
  user: User | null
  linked_providers: Provider[]
  pending_signup: boolean
  providers: Provider[]
}

export interface SessionContextValue {
  session: SessionData | null
  failed: boolean
  refresh: () => Promise<void>
  signOut: () => Promise<void>
}

export const SessionContext = createContext<SessionContextValue | null>(null)

export function useSession() {
  const value = useContext(SessionContext)
  if (!value) throw new Error('useSession must be used inside <SessionProvider>')
  return value
}

export const PROVIDER_LABELS: Record<Provider, string> = {
  google_oauth2: 'Google',
  github: 'GitHub',
  developer: 'Developer',
}
