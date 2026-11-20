import { useCallback, useState, type ReactNode } from 'react'
import { TermsContext, type LegalDoc } from '../terms'
import { Modal } from './Modal'

const CONTACT_URL = 'https://github.com/ThreeHoolagins/BearWatch/issues'

export function TermsProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState<LegalDoc | null>(null)
  const show = useCallback((doc: LegalDoc) => setOpen(doc), [])
  const hide = useCallback(() => setOpen(null), [])
  const other: LegalDoc = open === 'terms' ? 'privacy' : 'terms'

  return (
    <TermsContext.Provider value={show}>
      {children}
      {open && (
        <Modal
          title={open === 'terms' ? 'Terms of Service' : 'Privacy Policy'}
          onClose={hide}
          closeButton={false}
          className="tos"
          footer={
            <>
              <button className="link" onClick={() => setOpen(other)}>
                {other === 'terms' ? 'Terms of Service' : 'Privacy Policy'}
              </button>
              <button className="btn" onClick={hide}>Close</button>
            </>
          }
        >
          {open === 'terms' ? <TermsText /> : <PrivacyText />}
        </Modal>
      )}
    </TermsContext.Provider>
  )
}

function TermsText() {
  return (
    <>
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
        Only post photos you took yourself. You keep ownership of your photos. By posting one, you give Bear Watch a
        free, worldwide, non-exclusive license to store, display, copy, share and redistribute it, on the site and
        elsewhere (for example, featuring it in Fat Bear Week or sharing it on social media), with credit to your
        nickname where practical. You can delete your bears at any time; that ends the license for future use, but
        copies already shared may remain.
      </p>
      <h4>5. Privacy</h4>
      <p>
        We collect as little as we can. See the Privacy Policy for exactly what we keep and why.
      </p>
      <h4>6. Respect the bears</h4>
      <p>Keep a safe distance. Never approach, feed or disturb a bear for a photo. Follow park rules and ranger instructions.</p>
      <h4>7. Moderation and bans</h4>
      <p>
        New bears appear in the Global feed after a short delay so we can catch anything that breaks these terms.
        Bear Watch admins can remove any post and ban accounts that break these terms. Banned users will see the
        reason when they sign in.
      </p>
      <h4>8. No guarantees</h4>
      <p>
        Bear Watch is a free hobby project, provided as is. We may change or shut it down at any time. Sightings are
        posted by users and aren't safety information; always follow official park and wildlife guidance.
      </p>
      <h4>9. Changes</h4>
      <p>We may update these terms. If the changes are significant we'll let you know on the site.</p>
      <p className="updated">Last updated: November 19, 2026</p>
    </>
  )
}

function PrivacyText() {
  return (
    <>
      <p>
        Bear Watch is about bears, not people. We don't collect your name, email, password or phone number, we don't
        use tracking or advertising cookies, and we never sell or share data about you.
      </p>
      <h4>What we keep</h4>
      <p>
        <b>Your sign-in.</b> You sign in through Google or GitHub. We keep only the account ID they give us, so we can
        recognize you next time. We never see your password and don't keep your email.
      </p>
      <p>
        <b>Your profile.</b> Your nickname, who you follow, and the bears you post.
      </p>
      <p>
        <b>Your photos.</b> We remove location and camera data (EXIF) from every photo before storing it. The place
        you choose is rounded to about 10 km and shown as a place name. Photos must not include people.
      </p>
      <h4>What we don't keep</h4>
      <p>
        <b>Your location.</b> If you allow it, your browser location is rounded to about 10 km and used only to put
        nearby bears first in the Global feed. It's never saved.
      </p>
      <p>
        <b>Tracking.</b> The only cookie is the one that keeps you signed in. There are no analytics or ad trackers.
      </p>
      <p>
        Like any website, our servers keep short-lived technical logs (such as IP addresses and pages requested) to
        keep the site secure and working. They are kept briefly and deleted automatically as they roll over.
      </p>
      <h4>Your photos and redistribution</h4>
      <p>
        Bears you post are public. Under the Terms of Service, Bear Watch may display and redistribute them, credited
        to your nickname. No personal information about you is shared with them.
      </p>
      <h4>Services we use</h4>
      <p>
        Google or GitHub (sign-in), Amazon Web Services (hosting), Cloudflare (photo storage) and OpenStreetMap
        Nominatim (place-name search, sent from our server, not your browser).
      </p>
      <h4>Your choices</h4>
      <p>
        You can delete any of your bears at any time. To delete your whole account, or with any privacy question,{' '}
        <a href={CONTACT_URL} target="_blank" rel="noreferrer">contact us</a>.
      </p>
      <p>Bear Watch is not meant for children under 13.</p>
      <p className="updated">Last updated: November 19, 2026</p>
    </>
  )
}
