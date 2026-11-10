import { createContext, useContext } from 'react'

export const TermsContext = createContext<() => void>(() => {})

// Returns a function that opens the Terms of Service modal.
export function useOpenTerms() {
  return useContext(TermsContext)
}
