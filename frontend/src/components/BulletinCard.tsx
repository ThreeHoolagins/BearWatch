import { useState } from 'react'
import type { Bulletin } from '../posts'
import { HeartIcon, ShareIcon, TreeIcon } from './icons'

// Shares Bear Watch with the system share sheet, or copies the link.
async function shareBearWatch(): Promise<string | null> {
  const url = window.location.origin
  if (navigator.share) {
    try {
      await navigator.share({ title: 'Bear Watch', text: 'Come spot bears with me on Bear Watch!', url })
    } catch {
      // Closing the share sheet isn't an error worth showing.
    }
    return null
  }
  try {
    await navigator.clipboard.writeText(url)
    return 'Link copied. Send it to a bear enthusiast!'
  } catch {
    return `Share this link: ${url}`
  }
}

// A house notice between posts in the feeds. Also the admin's live preview.
// Paid placements are clearly labeled as sponsored (FTC disclosure).
export function BulletinCard({ bulletin }: { bulletin: Bulletin }) {
  const [note, setNote] = useState<string | null>(null)
  const link = bulletin.kind === 'link' && bulletin.link_url
    ? { href: bulletin.link_url, target: '_blank', rel: `noopener noreferrer${bulletin.sponsor ? ' sponsored' : ''}` }
    : null
  const photo = bulletin.photo && (
    <img src={bulletin.photo.url} alt="" loading="lazy" width={bulletin.photo.width} height={bulletin.photo.height} />
  )
  const photoClass = `bphoto ${bulletin.photo?.logo ? 'logo' : ''}`
  return (
    <aside className="post bulletin panel">
      <div className="who">
        <div className="av">{bulletin.sponsor ? <span>{bulletin.sponsor[0].toUpperCase()}</span> : <TreeIcon />}</div>
        <b>{bulletin.sponsor ?? 'Bear Watch'}</b>
        <span className={`tag ${bulletin.sponsor ? 'sponsored' : ''}`}>{bulletin.sponsor ? 'Sponsored' : 'Bulletin'}</span>
      </div>
      {photo && (link ? <a className={photoClass} {...link} tabIndex={-1}>{photo}</a> : <div className={photoClass}>{photo}</div>)}
      <div className="btext">
        <h3>{bulletin.title}</h3>
        <p>{bulletin.body}</p>
        {bulletin.kind === 'share' ? (
          <button className="btn gold" onClick={() => void shareBearWatch().then(setNote)}>
            <ShareIcon />
            {bulletin.link_text}
          </button>
        ) : (
          link && (
            <a className="btn gold" {...link}>
              {!bulletin.sponsor && <HeartIcon />}
              {bulletin.link_text}
            </a>
          )
        )}
        {note && <p className="msg ok">{note}</p>}
      </div>
    </aside>
  )
}
