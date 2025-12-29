import { useState, useEffect } from 'react'
import { useMutation } from '@apollo/client'
import { CREATE_USER_MUTATION, UPDATE_USER_MUTATION } from '../../graphql/mutations/users'
import Modal from '../UI/Modal'
import Input from '../UI/Input'
import Button from '../UI/Button'

interface UserModalProps {
  isOpen: boolean
  onClose: () => void
  user?: any
  onSuccess: () => void
}

export default function UserModal({ isOpen, onClose, user, onSuccess }: UserModalProps) {
  const [name, setName] = useState('')
  const [password, setPassword] = useState('')

  const [createUser] = useMutation(CREATE_USER_MUTATION, {
    onCompleted: () => {
      onSuccess()
      setName('')
      setPassword('')
    },
  })

  const [updateUser] = useMutation(UPDATE_USER_MUTATION, {
    onCompleted: () => {
      onSuccess()
      setPassword('')
    },
  })

  useEffect(() => {
    if (user) {
      setName(user.name)
    } else {
      setName('')
    }
    setPassword('')
  }, [user, isOpen])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return

    if (user) {
      const input: any = { id: user.id }
      if (name.trim() !== user.name) {
        input.name = name.trim()
      }
      if (password.trim()) {
        input.password = password.trim()
      }
      await updateUser({ variables: { input } })
    } else {
      if (!password.trim()) return
      await createUser({
        variables: {
          input: {
            name: name.trim(),
            password: password.trim(),
          },
        },
      })
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={user ? 'Edit User' : 'Create User'}>
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label="Username"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Enter username"
          required
        />

        <Input
          label={user ? 'New Password (leave empty to keep current)' : 'Password'}
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Enter password"
          required={!user}
        />

        <div className="flex gap-3 justify-end">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!name.trim() || (!user && !password.trim())}>
            {user ? 'Update' : 'Create'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}

