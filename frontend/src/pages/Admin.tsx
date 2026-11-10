import { ShieldIcon } from '../components/icons'
import { Shell } from '../components/Shell'

// The full Ranger Station (bans, Fat Bear Week) arrives in Phase 4.
export function Admin() {
  return (
    <Shell>
      <div className="pagehead">
        <h2>Ranger station</h2>
        <span className="near"><ShieldIcon />Admins only</span>
      </div>
      <div className="empty panel">
        <h3>Under construction</h3>
        User bans and the Fat Bear Week champion card land here in a later update. Until then, admins can use the
        <code> bearwatch:ban</code>, <code>bearwatch:unban</code> and <code>bearwatch:admin</code> rake tasks.
      </div>
    </Shell>
  )
}
