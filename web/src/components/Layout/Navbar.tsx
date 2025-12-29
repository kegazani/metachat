import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../../hooks/useAuth'

export default function Navbar() {
  const { logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <nav className="fixed top-0 left-1/2 -translate-x-1/2 w-[90vw] h-16 mt-6 px-6 flex items-center justify-between backdrop-blur-md bg-black/30 z-50 rounded-2xl border border-white/10 shadow-lg shadow-black/5">
      <div className="flex items-center gap-3">
        <span className="text-lg font-bold text-white">MetaChat</span>
      </div>
      <div className="flex items-center gap-6">
        <Link
          to="/"
          className="text-white/60 hover:text-white/90 transition-colors text-sm font-bold"
        >
          Chats
        </Link>
        <Link
          to="/users"
          className="text-white/60 hover:text-white/90 transition-colors text-sm font-bold"
        >
          Users
        </Link>
        <button
          onClick={handleLogout}
          className="text-white/60 hover:text-white/90 transition-colors text-sm font-bold"
        >
          Logout
        </button>
      </div>
    </nav>
  )
}

