import type { Post } from '../posts'

// Archive photos say who took them and link to the public-domain source.
export function PhotoCredit({ post }: { post: Post }) {
  if (!post.credit) return null
  return (
    <div className="photo-credit">
      Photo: {post.credit}
      {post.source_url && (
        <>
          {' · '}
          <a className="link" href={post.source_url} target="_blank" rel="noopener noreferrer">Source ↗</a>
        </>
      )}
    </div>
  )
}
