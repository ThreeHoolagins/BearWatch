import { useEffect, useRef, useState, type ChangeEvent, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { api, ApiError, errorMessage } from '../api'
import { CameraIcon, CheckIcon } from '../components/icons'
import { PlacePicker } from '../components/PlacePicker'
import { Shell } from '../components/Shell'
import { ACCEPTED_EXTENSIONS, MAX_UPLOAD_BYTES, type Place, type Post as PostData } from '../posts'
import { useOpenTerms } from '../terms'

type Stage =
  | { name: 'choose' }
  | { name: 'ready' }
  | { name: 'uploading' }
  | { name: 'checking'; postId: number }
  | { name: 'published'; post: PostData }
  | { name: 'rejected'; reason: string | null }

const BLURRY = 'Oops! It seems your bear photo is a little bit blurry, try again with a clearer photo!'

const OUTCOME_MESSAGES: Record<string, string> = {
  no_bear: BLURRY,
  too_large: 'That photo has too many pixels for us (over 50 megapixels). Try a smaller version.',
  unreadable: "We couldn't open that photo. Try saving it as a JPG or PNG first.",
  detector_unavailable: 'Our bear checker is napping. Please try again in a few minutes.',
  person: "We spotted a person in this photo. Bear Watch is bears only, so please share one without people in it.",
  out_of_storage: 'Oops! Ran out of honey. A ranger needs to fix this.',
  storage_unavailable: "We couldn't save your photo just now. Please try again in a few minutes.",
  processing_error: 'Something went wrong with that photo on our end. Please try again.',
}

function fileProblem(file: File): string | null {
  const extension = file.name.split('.').pop()?.toLowerCase() ?? ''
  if (!ACCEPTED_EXTENSIONS.includes(extension)) return 'Use a JPG, PNG, WebP or HEIC photo.'
  if (file.size > MAX_UPLOAD_BYTES) return 'That photo is over 12 MB. Try a smaller one.'
  if (file.size === 0) return 'That photo is empty.'
  return null
}

export function Post() {
  const openTerms = useOpenTerms()
  const inputRef = useRef<HTMLInputElement>(null)
  const [stage, setStage] = useState<Stage>({ name: 'choose' })
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [previewFailed, setPreviewFailed] = useState(false)
  const [place, setPlace] = useState<Place | null>(null)
  const [problem, setProblem] = useState<string | null>(null)

  // Free the preview's memory when it changes or the page closes.
  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview) }, [preview])

  // Poll while the worker re-encodes the photo and checks for a bear.
  useEffect(() => {
    if (stage.name !== 'checking') return
    let cancelled = false
    let tries = 0
    const tick = async () => {
      tries += 1
      try {
        const { post } = await api<{ post: PostData }>(`/api/posts/${stage.postId}`)
        if (cancelled) return
        if (post.status === 'published') return setStage({ name: 'published', post })
        if (post.status !== 'processing') return setStage({ name: 'rejected', reason: post.failure_reason })
      } catch {
        // Network blip: keep polling.
      }
      if (cancelled) return
      if (tries > 150) return setStage({ name: 'rejected', reason: 'detector_unavailable' })
      timer = setTimeout(tick, tries < 10 ? 1000 : 2000)
    }
    let timer = setTimeout(tick, 1000)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [stage])

  const choose = (event: ChangeEvent<HTMLInputElement>) => {
    const picked = event.target.files?.[0]
    event.target.value = '' // let them pick the same file again later
    if (!picked) return
    const issue = fileProblem(picked)
    setProblem(issue)
    if (issue) return
    setFile(picked)
    setPreview(URL.createObjectURL(picked))
    setPreviewFailed(false)
    setStage({ name: 'ready' })
  }

  const startOver = () => {
    setFile(null)
    setPreview(null)
    setProblem(null)
    setStage({ name: 'choose' })
  }

  const submit = async (event: FormEvent) => {
    event.preventDefault()
    if (!file || !place) return
    const form = new FormData()
    form.append('photo', file)
    form.append('place_name', place.name)
    form.append('latitude', String(place.latitude))
    form.append('longitude', String(place.longitude))

    setStage({ name: 'uploading' })
    setProblem(null)
    try {
      const { post } = await api<{ post: PostData }>('/api/posts', { method: 'POST', body: form })
      setStage({ name: 'checking', postId: post.id })
    } catch (error) {
      const tooBig = error instanceof ApiError && error.status === 413
      setProblem(tooBig ? 'That photo is over 12 MB. Try a smaller one.' : errorMessage(error, "Your photo didn't upload. Check your connection and try again."))
      setStage({ name: 'ready' })
    }
  }

  return (
    <Shell>
      <div className="pagehead">
        <h2>Post a bear</h2>
      </div>

      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif"
        onChange={choose}
        hidden
      />

      {stage.name === 'choose' && (
        <>
          <button type="button" className="drop" onClick={() => inputRef.current?.click()}>
            <CameraIcon className="big" />
            <h3>Choose a bear photo</h3>
            <p>
              JPG, PNG, WebP or HEIC, up to 12 MB.
              <br />
              We remove location and camera data before anything is saved.
            </p>
            <span className="btn wood">Choose photo</span>
          </button>
          {problem && <p className="msg bad center">{problem}</p>}
          <p className="fine center">
            One bear a minute. Bears only, no people. See the{' '}
            <button type="button" className="link" onClick={openTerms}>Terms of Service</button>.
          </p>
        </>
      )}

      {(stage.name === 'ready' || stage.name === 'uploading') && (
        <form onSubmit={submit}>
          <div className="preview panel">
            {preview && !previewFailed ? (
              <img src={preview} alt="Your photo" onError={() => setPreviewFailed(true)} />
            ) : (
              <div className="nopreview">
                <CameraIcon className="big" />
                Preview isn't available for this format, but it will upload fine.
              </div>
            )}
            <div className="bar">
              <span className="okchip"><CheckIcon />Location and camera data get removed</span>
              <button type="button" className="link" onClick={() => inputRef.current?.click()} disabled={stage.name === 'uploading'}>
                Change
              </button>
            </div>
          </div>
          <div className="formpad">
            <PlacePicker value={place} onChange={setPlace} />
            {problem && <p className="msg bad">{problem}</p>}
            <button className="btn wide gold" type="submit" disabled={!place || stage.name === 'uploading'}>
              {stage.name === 'uploading' ? 'Uploading…' : 'Share bear'}
            </button>
          </div>
        </form>
      )}

      {stage.name === 'checking' && (
        <div className="checking panel" aria-live="polite">
          <div className="spin" />
          <h3>Checking for bears…</h3>
          <div className="sub">This usually takes a few seconds.</div>
          <ul className="steps">
            <li className="done">✓ Photo received</li>
            <li className="now">● Removing location data and looking for a bear</li>
            <li>○ Posting to the trail</li>
          </ul>
        </div>
      )}

      {stage.name === 'published' && (
        <div className="outcome panel">
          {stage.post.image_url && <img src={stage.post.image_url} alt="Your bear" />}
          <h3>Your bear is on the trail!</h3>
          <p>{stage.post.place_name}</p>
          <div className="row">
            <Link className="btn" to="/profile">See it on your profile</Link>
            <button className="btn ghost" onClick={startOver}>Post another</button>
          </div>
        </div>
      )}

      {stage.name === 'rejected' && (
        <div className="outcome oops panel" role="alert">
          <h3>
            {stage.reason === 'no_bear' ? 'Hmm, no bear found' : stage.reason === 'person' ? 'Bears only, please' : 'That one didn’t work'}
          </h3>
          <p>{OUTCOME_MESSAGES[stage.reason ?? ''] ?? "Something went wrong with that photo. Please try another."}</p>
          <button className="btn wood" onClick={startOver}>Try another photo</button>
        </div>
      )}
    </Shell>
  )
}
