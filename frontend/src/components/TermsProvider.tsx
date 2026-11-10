import { useCallback, useState, type ReactNode } from 'react'
import { TermsContext } from '../terms'
import { Modal } from './Modal'

export function TermsProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false)
  const show = useCallback(() => setOpen(true), [])
  const hide = useCallback(() => setOpen(false), [])

  return (
    <TermsContext.Provider value={show}>
      {children}
      {open && (
        <Modal
          title="Terms of Service"
          onClose={hide}
          closeButton={false}
          className="tos"
          footer={<button className="btn" onClick={hide}>Close</button>}
        >
          <TermsText />
        </Modal>
      )}
    </TermsContext.Provider>
  )
}

function TermsText() {
  return (
    <>
      <div className="draft">Draft. These terms need a proper legal review before launch.</div>
      <h4>1. Bears only</h4>
      <p>
        Bear Watch is for photos of bears. Every upload is checked automatically, and photos without a clear bear
        are turned away. Repeatedly posting photos that aren't bears can get your account banned.
      </p>
      <h4>2. No people, nothing explicit</h4>
      <p>Your photos must not include people, and must never include sexually explicit, violent or hateful content.</p>
      <h4>3. Nicknames</h4>
      <p>
        Nicknames must be 3 to 20 characters and must not contain slurs, profanity, or impersonate someone else
        (including Bear Watch staff). Nicknames can't be changed once chosen.
      </p>
      <h4>4. Your photos</h4>
      <p>
        You keep ownership of your photos. By posting, you let Bear Watch display them on the site. Only post
        photos you took yourself.
      </p>
      <h4>5. Location and privacy</h4>
      <p>
        We sign you in through Google or GitHub and only keep the account ID they give us, never your password or
        email. Your browser location is used for the Global feed search and is never saved. Photo locations are
        rounded to about 10 km and shown as a place name. We remove location and camera data from every photo.
      </p>
      <h4>6. Respect the bears</h4>
      <p>Keep a safe distance. Never approach, feed or disturb a bear for a photo. Follow park rules and ranger instructions.</p>
      <h4>7. Bans</h4>
      <p>Bear Watch admins can ban accounts that break these terms. Banned users will see the reason when they sign in.</p>
      <h4>8. Changes</h4>
      <p>We may update these terms. If the changes are significant we'll let you know on the site.</p>
      <p className="updated">Last updated: November 2026</p>
    </>
  )
}
