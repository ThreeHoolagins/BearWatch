import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import cornerLogo from '../assets/bearwatch-corner-logo.svg'
import { useSession } from '../session'
import { useOpenTerms } from '../terms'
import { Avatar } from './Avatar'
import { DocIcon, ProfileIcon, ShieldIcon, SignOutIcon } from './icons'

// The forest-green header. Signed in on desktop it carries the account
// dropdown (profile, admin, terms, sign out).
export function Band({ signedIn = false, back = false }: { signedIn?: boolean; back?: boolean }) {
  const { session, signOut } = useSession()
  const openTerms = useOpenTerms()
  const navigate = useNavigate()
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const user = session?.user

  useEffect(() => {
    if (!menuOpen) return
    const onClick = (event: MouseEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) setMenuOpen(false)
    }
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && setMenuOpen(false)
    document.addEventListener('mousedown', onClick)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onClick)
      document.removeEventListener('keydown', onKey)
    }
  }, [menuOpen])

  const go = (path: string) => {
    setMenuOpen(false)
    navigate(path)
  }

  return (
    <header className="band">
      {back && (
        <button className="back mob" onClick={() => (window.history.length > 1 ? navigate(-1) : navigate('/'))} aria-label="Back">
          ‹
        </button>
      )}
      <div className="mark">
        <img src={cornerLogo} alt="" />
      </div>
      <span className="t">Bear Watch</span>
      {signedIn && user && (
        <div className="account desk" ref={menuRef}>
          <button className={`me ${menuOpen ? 'open' : ''}`} onClick={() => setMenuOpen((open) => !open)} aria-haspopup="menu" aria-expanded={menuOpen}>
            <Avatar avatar={user.avatar} />
            {user.nickname}
            <span className="caret" aria-hidden>▼</span>
          </button>
          {menuOpen && (
            <div className="menu" role="menu">
              <button role="menuitem" onClick={() => go('/profile')}>
                <ProfileIcon />My profile
              </button>
              {user.is_admin && (
                <button role="menuitem" onClick={() => go('/admin')}>
                  <ShieldIcon />Admin panel
                </button>
              )}
              <button role="menuitem" onClick={() => { setMenuOpen(false); openTerms() }}>
                <DocIcon />Terms of Service
              </button>
              <hr />
              <button role="menuitem" className="danger" onClick={() => { setMenuOpen(false); void signOut() }}>
                <SignOutIcon />Sign out
              </button>
            </div>
          )}
        </div>
      )}
    </header>
  )
}
