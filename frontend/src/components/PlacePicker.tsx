import { useState, type KeyboardEvent } from 'react'
import { api, errorMessage } from '../api'
import type { Place } from '../posts'
import { LocateIcon, PinIcon } from './icons'

// "Where did you see this bear?" Searches when the person presses Search or
// Enter (OpenStreetMap's geocoder doesn't allow search-as-you-type), or uses
// the browser's location once to find the nearest town.
export function PlacePicker({ value, onChange }: { value: Place | null; onChange: (place: Place | null) => void }) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Place[] | null>(null)
  const [busy, setBusy] = useState<'search' | 'locate' | null>(null)
  const [problem, setProblem] = useState<string | null>(null)

  const search = async () => {
    if (query.trim().length < 2) return
    setBusy('search')
    setProblem(null)
    try {
      const data = await api<{ places: Place[] }>(`/api/places/search?q=${encodeURIComponent(query.trim())}`)
      setResults(data.places)
    } catch (error) {
      setProblem(errorMessage(error, "Place search isn't working right now. Try again in a moment."))
    } finally {
      setBusy(null)
    }
  }

  const locate = () => {
    if (!('geolocation' in navigator)) return setProblem("Your browser can't share its location.")
    setBusy('locate')
    setProblem(null)
    navigator.geolocation.getCurrentPosition(
      async (position) => {
        // Rounded before it leaves the browser; the server only uses it to find the town.
        const lat = position.coords.latitude.toFixed(2)
        const lng = position.coords.longitude.toFixed(2)
        try {
          const data = await api<{ place: Place | null }>(`/api/places/reverse?lat=${lat}&lng=${lng}`)
          if (data.place) onChange(data.place)
          else setProblem("We couldn't find a town near you. Try searching instead.")
        } catch (error) {
          setProblem(errorMessage(error, "Place search isn't working right now. Try again in a moment."))
        } finally {
          setBusy(null)
        }
      },
      () => {
        setBusy(null)
        setProblem('Location is blocked for this site. Search for the place instead.')
      },
      { enableHighAccuracy: false, maximumAge: 10 * 60 * 1000, timeout: 15000 },
    )
  }

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault()
      void search()
    }
  }

  if (value) {
    return (
      <div className="field">
        <label>Where did you see this bear?</label>
        <div className="chosen-place">
          <span><PinIcon />{value.name}</span>
          <button type="button" className="link" onClick={() => onChange(null)}>Change</button>
        </div>
      </div>
    )
  }

  return (
    <div className="field">
      <label htmlFor="place-q">Where did you see this bear?</label>
      <div className="place-search">
        <input
          id="place-q"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          onKeyDown={onKeyDown}
          placeholder="A park or town, e.g. Katmai"
          autoComplete="off"
          maxLength={80}
        />
        <button type="button" className="btn sm" onClick={() => void search()} disabled={busy !== null || query.trim().length < 2}>
          {busy === 'search' ? '…' : 'Search'}
        </button>
      </div>
      <button type="button" className="here" onClick={locate} disabled={busy !== null}>
        <LocateIcon />
        {busy === 'locate' ? 'Finding you…' : 'Use where I am now'}
      </button>
      {results && (
        <div className="results">
          {results.length === 0 && <p className="fine">No parks or towns found. Try a different spelling.</p>}
          {results.map((place) => (
            <button type="button" key={place.name} onClick={() => onChange(place)}>
              <PinIcon />
              {place.name}
            </button>
          ))}
        </div>
      )}
      {problem && <p className="msg bad">{problem}</p>}
      <p className="hint">Shown under your photo as a place name. We round the spot to about 10 km to protect the bears.</p>
    </div>
  )
}
