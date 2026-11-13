import { timeAgo, type Post } from '../posts'
import { Avatar } from './Avatar'
import { PinIcon } from './icons'
import { Modal } from './Modal'

export function PostModal({ post, onClose }: { post: Post; onClose: () => void }) {
  return (
    <Modal title={`Bear spotted by ${post.user.nickname}`} onClose={onClose} size="sm" className="postm">
      <div className="who">
        <Avatar />
        <b>{post.user.nickname}</b>
        <time dateTime={post.created_at}>{timeAgo(post.created_at)}</time>
      </div>
      {post.image_url && <img className="full" src={post.image_url} alt={`Bear at ${post.place_name}`} />}
      <div className="where">
        <PinIcon />
        {post.place_name}
      </div>
    </Modal>
  )
}
