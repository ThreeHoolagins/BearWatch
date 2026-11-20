import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ChampionBanner } from '../components/ChampionCard'
import { Feed } from '../components/Feed'
import { LocateIcon, PinIcon } from '../components/icons'
import { Shell } from '../components/Shell'

type Location =
  | { state: 'checking' }
  | { state: 'off' }
  | { state: 'asking' }
  | { state: 'on'; lat: number; lng: number }
  | { state: 'denied' }
  | { state: 'unavailable' }

// Bears from everywhere, with ones near you first when location is on.
// The browser location is kept in memory for this page only and never saved.
// It's rounded to ~11 km before being sent with the feed request.
export function Global() {
  // Without the Permissions API we can't tell if location was allowed before.
  const [location, setLocation] = useState<Location>({ state: navigator.permissions ? 'checking' : 'off' })

  // `quiet` is the automatic attempt on page load: stay in 'checking' so the
  // feed waits for the location instead of loading twice.
  const locate = useCallback((quiet = false) => {
    if (!('geolocation' in navigator)) return setLocation({ state: quiet ? 'off' : 'unavailable' })
    if (!quiet) setLocation({ state: 'asking' })
    navigator.geolocation.getCurrentPosition(
      (position) => setLocation({ state: 'on', lat: position.coords.latitude, lng: position.coords.longitude }),
      (error) => setLocation({ state: quiet ? 'off' : error.code === error.PERMISSION_DENIED ? 'denied' : 'unavailable' }),
      { enableHighAccuracy: false, maximumAge: 10 * 60 * 1000, timeout: 15000 },
    )
  }, [])

  // If the person already allowed location before, don't make them click again.
  useEffect(() => {
    navigator.permissions
      ?.query({ name: 'geolocation' })
      .then((status) => (status.state === 'granted' ? locate(true) : setLocation({ state: 'off' })))
      .catch(() => setLocation({ state: 'off' }))
  }, [locate])

  const url =
    location.state === 'on'
      ? `/api/feed/global?lat=${location.lat.toFixed(1)}&lng=${location.lng.toFixed(1)}`
      : location.state === 'checking'
        ? null
        : '/api/feed/global'

  return (
    <Shell rail>
      <div className="pagehead">
        <h2>Global</h2>
        <span className="near">
          <PinIcon />
          {location.state === 'on' ? 'Near you first' : 'Everywhere'}
        </span>
      </div>
      <ChampionBanner />

      {location.state !== 'on' && location.state !== 'checking' && (
        <div className="locask panel">
          <b>See bears near you first</b>
          <br />
          Allow location to move nearby sightings up the feed. We use it for this search only and never save it.
          {location.state === 'denied' && (
            <p className="msg bad">Location is blocked for this site. Allow it in your browser settings, then try again.</p>
          )}
          {location.state === 'unavailable' && <p className="msg bad">We couldn't get your location. Try again in a moment.</p>}
          <button className="btn wide" onClick={() => locate()} disabled={location.state === 'asking'}>
            <LocateIcon />
            {location.state === 'asking' ? 'Finding you…' : 'Use my location'}
          </button>
        </div>
      )}

      <Feed
        url={url}
        empty={
          <div className="empty panel">
            <h3>No bears yet</h3>
            Nobody has spotted a bear yet. Be the first! New bears show up here after about 10 minutes.
            <br />
            <Link className="btn gold" to="/post">Post a bear</Link>
          </div>
        }
      />
    </Shell>
  )
}
