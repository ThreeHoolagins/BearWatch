import { CameraIcon } from '../components/icons'
import { Shell } from '../components/Shell'
import { useOpenTerms } from '../terms'

// Uploads arrive in Phase 2 (libvips re-encoding + bear detection).
export function Post() {
  const openTerms = useOpenTerms()

  return (
    <Shell>
      <div className="pagehead">
        <h2>Post a bear</h2>
      </div>
      <div className="drop disabled" aria-disabled="true">
        <CameraIcon className="big" />
        <h3>Uploads open soon</h3>
        <p>
          We're still building the trail. Soon you'll be able to post JPG, PNG, WebP or HEIC photos up to 12 MB, with
          location and camera data removed before anything is saved.
        </p>
      </div>
      <p className="fine center">
        Bears only, no people. See the <button className="link" onClick={openTerms}>Terms of Service</button>.
      </p>
    </Shell>
  )
}
