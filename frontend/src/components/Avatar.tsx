import { BlankBear } from './icons'

// Until bear-face avatars land (Phase 3), everyone gets the blank bear.
export function Avatar({ size }: { size?: 'xl' }) {
  return (
    <div className={`av ${size ?? ''}`}>
      <BlankBear />
    </div>
  )
}
