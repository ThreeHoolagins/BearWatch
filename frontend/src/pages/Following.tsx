import { Link } from 'react-router-dom'
import { ChampionBanner } from '../components/ChampionCard'
import { Feed } from '../components/Feed'
import { TreeIcon } from '../components/icons'
import { Shell } from '../components/Shell'

export function Following() {
  return (
    <Shell rail>
      <div className="pagehead">
        <h2>Following</h2>
      </div>
      <ChampionBanner />
      <Feed
        url="/api/feed/following"
        empty={
          <div className="empty panel">
            <TreeIcon className="big tree" />
            <h3>Quiet on the trail</h3>
            Bears from people you follow show up here. Tap a nickname on the Global feed to visit their profile and follow
            them.
            <br />
            <Link className="btn" to="/">Browse Global</Link>
          </div>
        }
      />
    </Shell>
  )
}
