import { useState, useEffect } from 'react'
import { useMutation, useQuery } from '@apollo/client'
import { CREATE_CHAT_MUTATION } from '../../graphql/mutations/chats'
import { USERS_QUERY } from '../../graphql/queries/users'
import Modal from '../UI/Modal'
import Input from '../UI/Input'
import Button from '../UI/Button'

interface ChatModalProps {
  isOpen: boolean
  onClose: () => void
  onSuccess: () => void
}

export default function ChatModal({ isOpen, onClose, onSuccess }: ChatModalProps) {
  const [name, setName] = useState('')
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([])

  const { data: usersData } = useQuery(USERS_QUERY, {
    variables: { limit: 100, offset: 0 },
    skip: !isOpen,
  })

  const [createChat] = useMutation(CREATE_CHAT_MUTATION, {
    onCompleted: () => {
      onSuccess()
      setName('')
      setSelectedUserIds([])
    },
  })

  useEffect(() => {
    if (!isOpen) {
      setName('')
      setSelectedUserIds([])
    }
  }, [isOpen])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim() || selectedUserIds.length === 0) return

    await createChat({
      variables: {
        input: {
          name: name.trim(),
          userIds: selectedUserIds,
        },
      },
    })
  }

  const toggleUser = (userId: string) => {
    setSelectedUserIds((prev) =>
      prev.includes(userId) ? prev.filter((id) => id !== userId) : [...prev, userId]
    )
  }

  const users = usersData?.users || []

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create Chat">
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label="Chat Name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Enter chat name"
          required
        />

        <div>
          <label className="block text-sm font-medium text-text-primary mb-2">
            Select Users
          </label>
          <div className="max-h-60 overflow-y-auto space-y-2 border border-white/10 rounded-lg p-4 bg-black/20">
            {users.length === 0 ? (
              <p className="text-text-secondary text-sm">No users available</p>
            ) : (
              users.map((user: any) => (
                <label
                  key={user.id}
                  className="flex items-center space-x-3 cursor-pointer hover:bg-white/5 p-2 rounded"
                >
                  <input
                    type="checkbox"
                    checked={selectedUserIds.includes(user.id)}
                    onChange={() => toggleUser(user.id)}
                    className="w-4 h-4 rounded border-white/20 bg-black/30 text-white focus:ring-white/20"
                  />
                  <span className="text-text-primary">{user.name}</span>
                </label>
              ))
            )}
          </div>
        </div>

        <div className="flex gap-3 justify-end">
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={!name.trim() || selectedUserIds.length === 0}>
            Create
          </Button>
        </div>
      </form>
    </Modal>
  )
}

