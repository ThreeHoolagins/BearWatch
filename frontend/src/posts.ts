import type { AvatarCrop } from './session'

export type PostStatus = 'processing' | 'published' | 'rejected' | 'failed'

// How bear watchers see each other.
export interface PublicUser {
  nickname: string
  avatar: AvatarCrop | null
  ranger: boolean
}

export interface Profile extends PublicUser {
  followers_count: number
  following_count: number
  fat_bear_wins: number
  posts_count: number
  me: boolean
  following: boolean
}

export interface Post {
  id: number
  status: PostStatus
  image_url: string | null
  width: number | null
  height: number | null
  place_name: string
  failure_reason: string | null
  created_at: string
  // Archive photos only: who took it, and the public-domain source.
  credit: string | null
  source_url: string | null
  user: PublicUser
  fat_bear_win: { id: number; year: number } | null
  // Where the detector found the bear: centre x, centre y, width, height (0-1).
  bear_box: [number, number, number, number] | null
}

export interface PostPage {
  posts: Post[]
  // An id, or an opaque "rank-id" string for the Global feed.
  next_before: number | string | null
}

export interface Place {
  name: string
  latitude: number
  longitude: number
}

export const MAX_UPLOAD_BYTES = 12 * 1024 * 1024
export const ACCEPTED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']

// "12m", "3h", "2d", "Nov 3", "Nov 3, 2025", and just "1939" for archive photos
export function timeAgo(iso: string, now = Date.now()): string {
  const date = new Date(iso)
  const seconds = Math.max(0, (now - date.getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  if (seconds < 7 * 86400) return `${Math.floor(seconds / 86400)}d`
  const yearsBack = new Date(now).getFullYear() - date.getFullYear()
  if (yearsBack > 1) return String(date.getFullYear())
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: yearsBack ? 'numeric' : undefined })
}

export function profilePath(user: Pick<PublicUser, 'nickname'>, myNickname?: string) {
  return user.nickname === myNickname ? '/profile' : `/u/${encodeURIComponent(user.nickname)}`
}

export interface Champion {
  year: number
  bear_name: string
  bear_number: string | null
  blurb: string | null
  photo: { url: string; width: number; height: number } | null
  source: 'post' | 'outside'
  post_id: number | null
  poster: PublicUser | null
  credit: string | null
  link_url: string | null
  link_text: string | null
}

export interface AdminUser {
  id: number
  nickname: string
  avatar: PublicUser['avatar']
  ranger: boolean
  banned: boolean
  ban_reason: string | null
  banned_at: string | null
  created_at: string
  posts_count: number
}

export interface Win {
  id: number
  year: number
  post: Post
}

// Fat Bear Week started in 2014; wins can be awarded up to next year.
export const FIRST_FAT_BEAR_YEAR = 2014
export const LAST_FAT_BEAR_YEAR = new Date().getFullYear() + 1

// Fat Bear Week runs in early October.
export function currentFatBearYear(now = new Date()) {
  return now.getMonth() >= 9 ? now.getFullYear() : now.getFullYear() - 1
}
