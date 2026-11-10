import { Navigate, Route, Routes } from 'react-router-dom'
import logo from './assets/bearwatch-logo.svg'
import { Admin } from './pages/Admin'
import { Banned } from './pages/Banned'
import { Following } from './pages/Following'
import { Global } from './pages/Global'
import { Login } from './pages/Login'
import { Nickname } from './pages/Nickname'
import { Post } from './pages/Post'
import { Profile } from './pages/Profile'
import { useSession, type User } from './session'

export default function App() {
  const { session, failed, refresh } = useSession()

  if (failed) {
    return (
      <div className="splash">
        <img src={logo} alt="Bear Watch" />
        <p>We can't reach the trail right now.</p>
        <button className="btn" onClick={() => void refresh()}>Try again</button>
      </div>
    )
  }
  if (!session) {
    return (
      <div className="splash">
        <img src={logo} alt="Bear Watch" />
      </div>
    )
  }

  const { user } = session
  // Whatever URL they land on, these states win: banned, mid-signup, signed out.
  if (user?.banned) return <Banned reason={user.ban_reason} />
  if (!user && session.pending_signup) return <Nickname />
  if (!user) return <Login />
  return <SignedIn user={user} />
}

function SignedIn({ user }: { user: User }) {
  return (
    <Routes>
      <Route path="/" element={<Global />} />
      <Route path="/following" element={<Following />} />
      <Route path="/post" element={<Post />} />
      <Route path="/profile" element={<Profile user={user} />} />
      <Route path="/admin" element={user.is_admin ? <Admin /> : <Navigate to="/" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
