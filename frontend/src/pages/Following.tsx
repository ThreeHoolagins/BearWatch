import { Link } from 'react-router-dom'
import { TreeIcon } from '../components/icons'
import { Shell } from '../components/Shell'

export function Following() {
  return (
    <Shell rail>
      <div className="pagehead">
        <h2>Following</h2>
        <span className="near">0 bear watchers</span>
      </div>
      <div className="empty panel">
        <TreeIcon className="big tree" />
        <h3>Quiet on the trail</h3>
        You're not following anyone yet. Tap a nickname on the Global feed to visit their profile and follow them.
        <br />
        <Link className="btn" to="/">Browse Global</Link>
      </div>
    </Shell>
  )
}
