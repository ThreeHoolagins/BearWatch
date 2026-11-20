import { Link } from 'react-router-dom'
import { profilePath, timeAgo, type Post } from '../posts'
import { Avatar } from './Avatar'
import { PinIcon, TrophyIcon } from './icons'
import { PhotoCredit } from './PhotoCredit'

export function PostCard({ post, me, onOpen }: { post: Post; me?: string; onOpen: (post: Post) => void }) {
  return (
    <article className="post panel">
      <Link className="who" to={profilePath(post.user, me)}>
        <Avatar avatar={post.user.avatar} />
        <b>{post.user.nickname}</b>
        <time dateTime={post.created_at}>{timeAgo(post.created_at)}</time>
      </Link>
      <button className="photo-btn" onClick={() => onOpen(post)} aria-label={`Open bear photo from ${post.place_name}`}>
        {post.fat_bear_win && <span className="winbadge"><TrophyIcon />Fat Bear Week {post.fat_bear_win.year}</span>}
        {post.image_url && (
          <img
            src={post.image_url}
            alt={`Bear spotted at ${post.place_name}`}
            loading="lazy"
            width={post.width ?? undefined}
            height={post.height ?? undefined}
          />
        )}
      </button>
      <div className="where">
        <PinIcon />
        {post.place_name}
      </div>
      <PhotoCredit post={post} />
    </article>
  )
}
