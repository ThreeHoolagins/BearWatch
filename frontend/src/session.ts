import { createContext, useContext } from 'react'

export type Provider = 'google_oauth2' | 'github' | 'developer'

// A crop of one of the user's photos: x/y (0-1) is the point at the circle's centre.
export interface AvatarCrop {
  url: string
  width: number
  height: number
  zoom: number
  x: number
  y: number
}

export interface User {
  id: number
  nickname: string
  is_admin: boolean
  banned: boolean
  ban_reason: string | null
  avatar: AvatarCrop | null
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
