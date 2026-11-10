import type { ReactElement } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Avatar } from '../components/Avatar'
import { CheckIcon, GitHubIcon, GoogleIcon, ShieldIcon, SignOutIcon, TrophyIcon } from '../components/icons'
import { Shell } from '../components/Shell'
import { SsoButton } from '../components/SsoButton'
import { PROVIDER_LABELS, useSession, type Provider, type User } from '../session'
import { useOpenTerms } from '../terms'

const LINK_ERRORS: Record<string, string> = {
  taken: 'That account is already linked to a different Bear Watch user.',
  already_linked: 'You already have an account from that provider linked.',
}

const PROVIDER_ICONS: Partial<Record<Provider, ReactElement>> = {
  google_oauth2: <GoogleIcon />,
  github: <GitHubIcon />,
}

export function Profile({ user }: { user: User }) {
  const { session, signOut } = useSession()
  const openTerms = useOpenTerms()
  const [params] = useSearchParams()
  const linked = session?.linked_providers ?? []
  // Offer every real provider that's switched on, plus any already linked.
  const providers = [...new Set([...(session?.providers ?? []), ...linked])].filter((p) => p !== 'developer' || linked.includes(p))
  const justLinked = params.get('linked') as Provider | null
  const linkError = params.get('link_error')

  return (
    <Shell>
      <div className="phead">
        <Avatar size="xl" />
        <div>
          <h2>
            {user.nickname}
            {user.is_admin && <span className="adminchip">Ranger</span>}
          </h2>
          <div className="stats">
            <div><b>0</b><small>Followers</small></div>
            <div><b>0</b><small>Following</small></div>
            <div><b><TrophyIcon className="gold" />0</b><small>Fat Bear Wins</small></div>
          </div>
        </div>
      </div>

      <div className="ptitle">0 bears spotted</div>
      <p className="fine pad">Photos you post will show up here, three across.</p>

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
        {user.is_admin && (
          <Link className="btn ghost" to="/admin"><ShieldIcon />Admin panel</Link>
        )}
        <button className="btn ghost danger" onClick={() => void signOut()}><SignOutIcon />Sign out</button>
        <p className="fine center">
          <button className="link" onClick={openTerms}>Terms of Service</button>
        </p>
      </div>
    </Shell>
  )
}
