import type { ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import { useOpenTerms } from '../terms'
import { Band } from './Band'
import { FollowingIcon, GlobalIcon, PostIcon, ProfileIcon, TreeIcon } from './icons'

const TABS = [
  { to: '/', label: 'Global', sign: 'Global', Icon: GlobalIcon },
  { to: '/following', label: 'Following', sign: 'Following', Icon: FollowingIcon },
  { to: '/post', label: 'Post', sign: 'Post a bear', Icon: PostIcon },
  { to: '/profile', label: 'Profile', sign: 'Profile', Icon: ProfileIcon },
]

// Signed-in layout: signpost nav on desktop, bottom tabs on mobile, and an
// optional right column on wide screens.
export function Shell({ children, rail = false, wide = false, back = false }: { children: ReactNode; rail?: boolean; wide?: boolean; back?: boolean }) {
  const openTerms = useOpenTerms()

  return (
    <>
      <Band signedIn back={back} />
      <div className={`layout ${rail ? 'withrail' : ''}`}>
        <nav className="side desk" aria-label="Main">
          {TABS.map(({ to, sign, Icon }) => (
            <NavLink key={to} to={to} end className={({ isActive }) => `plank ${isActive ? 'on' : ''} ${to === '/post' ? 'post-cta' : ''}`}>
              <Icon />
              {sign}
            </NavLink>
          ))}
          <button className="link tos-link" onClick={openTerms}>
            Terms of Service
          </button>
        </nav>
        <main className={`main ${wide ? 'wide' : ''}`}>{children}</main>
        {rail && (
          <aside className="rail">
            <div className="rcard panel">
              <h3>
                <TreeIcon className="tree" />
                Trail rules
              </h3>
              <ol>
                <li>Bears only.</li>
                <li>No people in photos.</li>
                <li>Keep nicknames and photos clean.</li>
              </ol>
              <p className="fine">
                <button className="link" onClick={openTerms}>Full Terms of Service</button>
              </p>
            </div>
            <div className="foot">Bear Watch · Fort Collins, CO</div>
          </aside>
        )}
      </div>
      <nav className="tabs" aria-label="Main">
        {TABS.map(({ to, label, Icon }) => (
          <NavLink key={to} to={to} end className={({ isActive }) => (isActive ? 'on' : '')}>
            <Icon />
            {label}
          </NavLink>
        ))}
      </nav>
    </>
  )
}
