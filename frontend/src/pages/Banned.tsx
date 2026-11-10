import { Band } from '../components/Band'
import { ClosedSign } from '../components/icons'
import { useSession } from '../session'
import { useOpenTerms } from '../terms'

export function Banned({ reason }: { reason: string | null }) {
  const { signOut } = useSession()
  const openTerms = useOpenTerms()

  return (
    <>
      <Band />
      <div className="cardwrap">
        <div className="card">
          <ClosedSign className="banicon" />
          <h1>This trail is closed</h1>
          <p className="lede tight">Your Bear Watch account has been banned.</p>
          <div className="reason">
            <small>Reason</small>
            {reason || 'Breaking the Terms of Service.'}
          </div>
          <button className="btn wide" onClick={() => void signOut()}>Sign out</button>
          <p className="fine">
            <button className="link" onClick={openTerms}>Terms of Service</button>
          </p>
        </div>
      </div>
    </>
  )
}
