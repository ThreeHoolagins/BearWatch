import { useSearchParams } from 'react-router-dom'
import logo from '../assets/bearwatch-logo.svg'
import { GitHubIcon, GoogleIcon, Ridge } from '../components/icons'
import { SsoButton } from '../components/SsoButton'
import { useSession } from '../session'
import { useOpenTerms } from '../terms'

export function Login() {
  const { session } = useSession()
  const openTerms = useOpenTerms()
  const [params] = useSearchParams()
  const providers = session?.providers ?? []
  const authError = params.get('auth_error')

  return (
    <div className="login">
      <div className="login-hero">
        <img className="logo" src={logo} alt="" />
        <div className="tag">Wild bear photography</div>
        <Ridge className="ridge" />
      </div>
      <div className="login-panel">
        <div className="inner">
          <img className="logo mob" src={logo} alt="Bear Watch" />
          <h1 className="desk">Welcome, bear watcher</h1>
          <p className="lede">
            Join the future of bear admiration based in Fort Collins, CO. Sign up or login using the following options:
          </p>

          {authError && (
            <div className="alert" role="alert">
              Sign-in didn't finish ({authError.replaceAll('_', ' ')}). Please try again.
            </div>
          )}

          {providers.includes('google_oauth2') && (
            <SsoButton provider="google_oauth2" className="sso">
              <span className="gbadge"><GoogleIcon /></span>Continue with Google
            </SsoButton>
          )}
          {providers.includes('github') && (
            <SsoButton provider="github" className="sso dark">
              <GitHubIcon />Continue with GitHub
            </SsoButton>
          )}
          {providers.includes('developer') && (
            <SsoButton provider="developer" className="sso ghost">
              Developer sign-in (dev only)
            </SsoButton>
          )}
          {!providers.some((p) => p !== 'developer') && (
            <p className="fine">Google and GitHub sign-in turn on once their client IDs are set in .env.</p>
          )}

          <p className="fine">
            By continuing you agree to our <button className="link" onClick={openTerms}>Terms of Service</button>. We never see your
            password.
          </p>
        </div>
      </div>
    </div>
  )
}
