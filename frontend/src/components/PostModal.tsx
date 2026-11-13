import { Link } from 'react-router-dom'
import { profilePath, timeAgo, type Post } from '../posts'
import { useSession } from '../session'
import { Avatar } from './Avatar'
import { PinIcon } from './icons'
import { Modal } from './Modal'

export function PostModal({ post, onClose }: { post: Post; onClose: () => void }) {
  const { session } = useSession()

  return (
    <Modal title={`Bear spotted by ${post.user.nickname}`} onClose={onClose} size="sm" className="postm">
      <Link className="who" to={profilePath(post.user, session?.user?.nickname)} onClick={onClose}>
        <Avatar avatar={post.user.avatar} />
        <b>{post.user.nickname}</b>
        <time dateTime={post.created_at}>{timeAgo(post.created_at)}</time>
      </Link>
      {post.image_url && <img className="full" src={post.image_url} alt={`Bear at ${post.place_name}`} />}
      <div className="where">
        <PinIcon />
        {post.place_name}
      </div>
    </Modal>
  )
}
