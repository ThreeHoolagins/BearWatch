export type PostStatus = 'processing' | 'published' | 'rejected' | 'failed'

export interface Post {
  id: number
  status: PostStatus
  image_url: string | null
  width: number | null
  height: number | null
  place_name: string
  failure_reason: string | null
  created_at: string
  user: { nickname: string }
}

export interface Place {
  name: string
  latitude: number
  longitude: number
}

export const MAX_UPLOAD_BYTES = 12 * 1024 * 1024
export const ACCEPTED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']

// "12m", "3h", "2d", "Nov 3"
export function timeAgo(iso: string, now = Date.now()): string {
  const seconds = Math.max(0, (now - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  if (seconds < 7 * 86400) return `${Math.floor(seconds / 86400)}d`
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}
