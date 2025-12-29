import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation } from '@apollo/client'
import { useAuth } from '../hooks/useAuth'
import { LOGIN_MUTATION } from '../graphql/mutations/auth'
import { CREATE_USER_MUTATION } from '../graphql/mutations/users'
import Input from '../components/UI/Input'
import Button from '../components/UI/Button'
import Card from '../components/UI/Card'

export default function Login() {
  const [isLogin, setIsLogin] = useState(true)
  const [name, setName] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const { login } = useAuth()
  const navigate = useNavigate()

  const [loginMutation] = useMutation(LOGIN_MUTATION, {
    onCompleted: (data) => {
      login(data.login)
      navigate('/')
    },
    onError: (err) => {
      setError(err.message)
    },
  })

  const [createUserMutation] = useMutation(CREATE_USER_MUTATION, {
    onCompleted: () => {
      setError('')
      setIsLogin(true)
    },
    onError: (err) => {
      setError(err.message)
    },
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!name || !password) {
      setError('Please fill in all fields')
      return
    }

    if (isLogin) {
      await loginMutation({ variables: { input: { name, password } } })
    } else {
      await createUserMutation({ variables: { input: { name, password } } })
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-6">
      <Card className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-5xl font-bold mb-6 text-text-primary">MetaChat</h1>
          <p className="text-xl text-gray-300">
            {isLogin ? 'Sign in to continue' : 'Create your account'}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <Input
            label="Username"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter your username"
          />

          <Input
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter your password"
          />

          {error && (
            <div className="text-red-400 text-sm">{error}</div>
          )}

          <Button type="submit" className="w-full">
            {isLogin ? 'Login' : 'Register'}
          </Button>
        </form>

        <div className="mt-6 text-center">
          <button
            onClick={() => {
              setIsLogin(!isLogin)
              setError('')
            }}
            className="text-white/60 hover:text-white/90 transition-colors text-sm"
          >
            {isLogin ? "Don't have an account? Register" : 'Already have an account? Login'}
          </button>
        </div>
      </Card>
    </div>
  )
}

