import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ChampionBanner } from '../components/ChampionCard'
import { Feed } from '../components/Feed'
import { LocateIcon, PinIcon } from '../components/icons'
import { Shell } from '../components/Shell'

type Location = { state: 'off' } | { state: 'asking' } | { state: 'on'; lat: number; lng: number } | { state: 'denied' } | { state: 'unavailable' }

// The browser location is kept in memory for this page only and never saved.
// It's rounded to ~11 km before being sent with the feed request.
export function Global() {
  const [location, setLocation] = useState<Location>({ state: 'off' })

  const locate = useCallback(() => {
    if (!('geolocation' in navigator)) return setLocation({ state: 'unavailable' })
    setLocation({ state: 'asking' })
    navigator.geolocation.getCurrentPosition(
      (position) => setLocation({ state: 'on', lat: position.coords.latitude, lng: position.coords.longitude }),
      (error) => setLocation({ state: error.code === error.PERMISSION_DENIED ? 'denied' : 'unavailable' }),
      { enableHighAccuracy: false, maximumAge: 10 * 60 * 1000, timeout: 15000 },
    )
  }, [])

  // If the person already allowed location before, don't make them click again.
  useEffect(() => {
    navigator.permissions
      ?.query({ name: 'geolocation' })
      .then((status) => status.state === 'granted' && locate())
      .catch(() => {})
  }, [locate])

  return (
    <Shell rail>
      <div className="pagehead">
        <h2>Global</h2>
        <span className="near">
          <PinIcon />
          {location.state === 'on' ? 'Within 500 mi of you' : 'Location off'}
        </span>
      </div>
      <ChampionBanner />

      {location.state === 'on' ? (
        <Feed
          url={`/api/feed/global?lat=${location.lat.toFixed(1)}&lng=${location.lng.toFixed(1)}`}
          empty={
            <div className="empty panel">
              <h3>No bears near you yet</h3>
              Nobody has spotted a bear within 500 miles of you. Be the first!
              <br />
              <Link className="btn gold" to="/post">Post a bear</Link>
            </div>
          }
        />
      ) : (
        <div className="locask panel">
          <b>See bears near you</b>
          <br />
          Allow location to see sightings within 500 miles. We use it for this search only and never save it.
          {location.state === 'denied' && (
            <p className="msg bad">Location is blocked for this site. Allow it in your browser settings, then try again.</p>
          )}
          {location.state === 'unavailable' && <p className="msg bad">We couldn't get your location. Try again in a moment.</p>}
          <button className="btn wide" onClick={locate} disabled={location.state === 'asking'}>
            <LocateIcon />
            {location.state === 'asking' ? 'Finding you…' : 'Use my location'}
          </button>
        </div>
      )}
    </Shell>
  )
}
