import { useLocalStorageString } from './useLocalStorage'

export function useAuth() {
  const [token, setToken] = useLocalStorageString('token', '')

  const login = (newToken: string) => {
    setToken(newToken)
  }

  const logout = () => {
    setToken('')
    localStorage.removeItem('token')
  }

  return {
    token,
    login,
    logout,
    isAuthenticated: !!token,
  }
}

