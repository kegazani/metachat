import { useQuery } from '@apollo/client'
import { USERS_QUERY } from '../graphql/queries/users'
import Card from '../components/UI/Card'
import Button from '../components/UI/Button'
import { useState } from 'react'
import UserModal from '../components/Users/UserModal'

export default function Users() {
  const { data, loading, error, refetch } = useQuery(USERS_QUERY, {
    variables: { limit: 100, offset: 0 },
  })
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingUser, setEditingUser] = useState<any>(null)

  if (loading) return <div className="text-text-primary">Loading...</div>
  if (error) return <div className="text-red-400">Error: {error.message}</div>

  const users = data?.users || []

  const handleEdit = (user: any) => {
    setEditingUser(user)
    setIsModalOpen(true)
  }

  const handleClose = () => {
    setIsModalOpen(false)
    setEditingUser(null)
  }

  return (
    <div className="max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-5xl font-bold text-text-primary">Users</h1>
        <Button onClick={() => setIsModalOpen(true)}>Create User</Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {users.map((user: any) => (
          <Card key={user.id}>
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xl font-bold text-text-primary">{user.name}</h3>
                <p className="text-text-secondary text-sm mt-1">
                  ID: {user.id}
                </p>
              </div>
              <Button
                variant="secondary"
                onClick={() => handleEdit(user)}
              >
                Edit
              </Button>
            </div>
          </Card>
        ))}
      </div>

      <UserModal
        isOpen={isModalOpen}
        onClose={handleClose}
        user={editingUser}
        onSuccess={() => {
          handleClose()
          refetch()
        }}
      />
    </div>
  )
}

