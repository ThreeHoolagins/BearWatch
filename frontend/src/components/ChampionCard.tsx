import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useChampion } from '../champion'
import { profilePath, type Champion } from '../posts'
import { useSession } from '../session'
import { TrophyIcon } from './icons'
import { Modal } from './Modal'

function Credit({ champion, onNavigate }: { champion: Champion; onNavigate?: () => void }) {
  const { session } = useSession()
  if (champion.poster) {
    return (
      <div className="credit">
        Photo by{' '}
        <Link className="link" to={profilePath(champion.poster, session?.user?.nickname)} onClick={onNavigate}>
          {champion.poster.nickname}
        </Link>{' '}
        on Bear Watch
      </div>
    )
  }
  if (!champion.credit && !champion.link_url) return null
  return (
    <div className="credit">
      {champion.credit}
      {champion.credit && champion.link_url && ' · '}
      {champion.link_url && (
        <a className="link" href={champion.link_url} target="_blank" rel="noopener noreferrer">
          {champion.link_text || 'Learn more'} ↗
        </a>
      )}
    </div>
  )
}

function ChampionBody({ champion, onNavigate }: { champion: Champion; onNavigate?: () => void }) {
  return (
    <>
      {champion.photo && <img className="champ-photo" src={champion.photo.url} alt={`${champion.bear_name}, Fat Bear Week ${champion.year} champion`} />}
      <div className="name">
        {champion.bear_name}
        {champion.bear_number && <span className="num"> (Bear {champion.bear_number})</span>}
      </div>
      {champion.blurb && <div>{champion.blurb}</div>}
      <Credit champion={champion} onNavigate={onNavigate} />
    </>
  )
}

// Sidebar card on wide screens. Also used as the admin's live preview.
export function ChampionCard({ champion }: { champion: Champion }) {
  return (
    <div className="rcard panel champ">
      <h3>
        <TrophyIcon className="gold" />
        Fat Bear Week {champion.year}
      </h3>
      <ChampionBody champion={champion} />
    </div>
  )
}

export function RailChampion() {
  const champion = useChampion()
  return champion ? <ChampionCard champion={champion} /> : null
}

// Compact banner above the feeds when there's no sidebar; tap for the full card.
export function ChampionBanner() {
  const champion = useChampion()
  const [open, setOpen] = useState(false)
  if (!champion) return null
  return (
    <>
      <button className="champ-mob panel" onClick={() => setOpen(true)}>
        {champion.photo && <img src={champion.photo.url} alt="" />}
        <div>
          <div className="k"><TrophyIcon />Fat Bear Week {champion.year} champion</div>
          <div className="name">{champion.bear_name}</div>
          <div className="tap">Tap to see the champ</div>
        </div>
      </button>
      {open && (
        <Modal title={`Fat Bear Week ${champion.year}`} onClose={() => setOpen(false)} size="sm" className="champ">
          <ChampionBody champion={champion} onNavigate={() => setOpen(false)} />
        </Modal>
      )}
    </>
  )
}
