import type { SVGProps } from 'react'

type IconProps = SVGProps<SVGSVGElement>

const stroke = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' } as const

export const GlobalIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="M3 12h18M12 3c2.8 3 2.8 15 0 18M12 3c-2.8 3-2.8 15 0 18" />
  </svg>
)

export const FollowingIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <circle cx="9" cy="8" r="3.5" />
    <path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5" />
    <circle cx="17" cy="9" r="2.8" />
    <path d="M16 14.6c2.9-.2 5 1.5 5.5 4.6" />
  </svg>
)

export const PostIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <rect x="3.5" y="3.5" width="17" height="17" rx="3" />
    <path d="M12 8v8M8 12h8" />
  </svg>
)

export const ProfileIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21c.8-4.2 4-6.5 8-6.5s7.2 2.3 8 6.5" />
  </svg>
)

export const ShieldIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <path d="M12 3l8 3v6c0 4.5-3.4 8-8 9-4.6-1-8-4.5-8-9V6z" />
  </svg>
)

export const SignOutIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10" />
  </svg>
)

export const DocIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} {...p}>
    <path d="M6 3h9l4 4v14H6z M14 3v5h5 M9 12h7 M9 16h7" />
  </svg>
)

export const LocateIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" className="ico" aria-hidden {...stroke} strokeWidth={2} {...p}>
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
  </svg>
)

export const CameraIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" aria-hidden {...stroke} strokeWidth={1.6} {...p}>
    <path d="M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z" />
    <circle cx="12" cy="13.5" r="4" />
  </svg>
)

export const PinIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden {...p}>
    <path d="M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z" />
  </svg>
)

export const TrophyIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden {...p}>
    <path d="M6 3h12v3h3v2a5 5 0 0 1-4.6 5A6 6 0 0 1 13 16.9V19h3v2H8v-2h3v-2.1A6 6 0 0 1 7.6 13 5 5 0 0 1 3 8V6h3V3zm0 5H5a3 3 0 0 0 1.4 2.5A6 6 0 0 1 6 9V8zm12 0v1a6 6 0 0 1-.4 1.5A3 3 0 0 0 19 8h-1z" />
  </svg>
)

export const TreeIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden {...p}>
    <path d="M12 2 5 11h3l-4 6h7v5h2v-5h7l-4-6h3z" />
  </svg>
)

export const CheckIcon = (p: IconProps) => (
  <svg viewBox="0 0 24 24" aria-hidden fill="none" stroke="currentColor" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round" {...p}>
    <path d="M4 12l5 5L20 6" />
  </svg>
)

// The default avatar until someone picks a bear face from their photos.
export const BlankBear = (p: IconProps) => (
  <svg viewBox="0 0 40 40" fill="currentColor" aria-hidden {...p}>
    <circle cx="9" cy="10" r="6" />
    <circle cx="31" cy="10" r="6" />
    <circle cx="20" cy="22" r="15" />
  </svg>
)

export const GoogleIcon = (p: IconProps) => (
  <svg viewBox="0 0 48 48" aria-hidden {...p}>
    <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z" />
    <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z" />
    <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z" />
    <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z" />
  </svg>
)

export const GitHubIcon = (p: IconProps) => (
  <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden {...p}>
    <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
  </svg>
)

export const ClosedSign = (p: IconProps) => (
  <svg viewBox="0 0 72 72" aria-hidden {...p}>
    <rect x="33" y="30" width="6" height="40" fill="#6B4A2F" />
    <rect x="6" y="10" width="60" height="28" rx="4" fill="#9c3219" />
    <rect x="9" y="13" width="54" height="22" rx="2" fill="none" stroke="#F2E6CC" strokeWidth="1.5" />
    <text x="36" y="29" textAnchor="middle" fontFamily="Zilla Slab, serif" fontWeight="700" fontSize="13" fill="#F2E6CC">CLOSED</text>
  </svg>
)

export const Ridge = (p: IconProps) => (
  <svg viewBox="0 0 600 220" preserveAspectRatio="none" aria-hidden {...p}>
    <circle cx="470" cy="70" r="30" fill="#D4A23C" opacity=".85" />
    <path fill="#7C9A7E" opacity=".45" d="M0,220 L0,140 L90,70 L170,125 L265,40 L370,135 L455,80 L600,150 L600,220Z" />
    <path fill="#16301f" d="M0,220 L0,175 L60,150 L120,180 L200,140 L285,185 L385,150 L470,185 L540,160 L600,175 L600,220Z" />
    <path fill="#10241a" d="M40,190 l14,-34 l14,34z M70,195 l11,-26 l11,26z M520,192 l13,-32 l13,32z M548,196 l10,-24 l10,24z M300,198 l9,-22 l9,22z" />
  </svg>
)
