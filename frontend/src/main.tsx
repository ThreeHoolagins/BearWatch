import '@fontsource/poppins/400.css'
import '@fontsource/poppins/500.css'
import '@fontsource/poppins/600.css'
import '@fontsource/poppins/700.css'
import '@fontsource/zilla-slab/500.css'
import '@fontsource/zilla-slab/600.css'
import '@fontsource/zilla-slab/700.css'
import './styles.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { TermsProvider } from './components/TermsProvider'
import { SessionProvider } from './SessionProvider'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <SessionProvider>
        <div className="app">
          <TermsProvider>
            <App />
          </TermsProvider>
        </div>
      </SessionProvider>
    </BrowserRouter>
  </StrictMode>,
)
