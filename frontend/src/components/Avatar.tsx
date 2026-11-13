import type { CSSProperties } from 'react'
import { cropLayout, type Crop } from '../avatarCrop'
import { BlankBear } from './icons'

export function Avatar({ avatar, size, className = '' }: { avatar?: Crop | null; size?: 'xl' | 'ring'; className?: string }) {
  if (!avatar) {
    return (
      <div className={`av ${size ?? ''} ${className}`}>
        <BlankBear />
      </div>
    )
  }
  const box = cropLayout(avatar)
  const style: CSSProperties = { width: `${box.width}%`, height: `${box.height}%`, left: `${box.left}%`, top: `${box.top}%` }
  return (
    <div className={`av photo ${size ?? ''} ${className}`}>
      <img src={avatar.url} alt="" style={style} draggable={false} />
    </div>
  )
}
