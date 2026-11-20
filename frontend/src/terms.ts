import { createContext, useContext } from 'react'

export type LegalDoc = 'terms' | 'privacy'

export const TermsContext = createContext<(doc: LegalDoc) => void>(() => {})

// Returns a function that opens the Terms of Service modal.
export function useOpenTerms() {
  const open = useContext(TermsContext)
  return () => open('terms')
}

// Returns a function that opens the Privacy Policy modal.
export function useOpenPrivacy() {
  const open = useContext(TermsContext)
  return () => open('privacy')
}
