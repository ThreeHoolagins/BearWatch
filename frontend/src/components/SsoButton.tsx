import type { ReactNode } from 'react'
import { getCsrfToken } from '../api'
import type { Provider } from '../session'

// Starting sign-in is a real form POST (OmniAuth requires POST + CSRF token);
// the browser then follows redirects to the provider and back.
export function SsoButton({ provider, className, children }: { provider: Provider; className: string; children: ReactNode }) {
  return (
    <form method="post" action={`/auth/${provider}`} className="ssoform">
      <input type="hidden" name="authenticity_token" value={getCsrfToken()} />
      <button type="submit" className={className}>
        {children}
      </button>
    </form>
  )
}
