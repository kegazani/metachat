import { useQuery, useMutation } from '@apollo/client'
import { CHATS_QUERY } from '../graphql/queries/chats'
import { DELETE_CHAT_MUTATION } from '../graphql/mutations/chats'
import Card from '../components/UI/Card'
import { Link } from 'react-router-dom'
import Button from '../components/UI/Button'
import { useState } from 'react'
import ChatModal from '../components/Chats/ChatModal'

export default function Dashboard() {
  const { data, loading, error, refetch } = useQuery(CHATS_QUERY, {
    variables: { limit: 100, offset: 0 },
  })
  const [isModalOpen, setIsModalOpen] = useState(false)
  
  const [deleteChat] = useMutation(DELETE_CHAT_MUTATION, {
    onCompleted: () => {
      refetch()
    },
  })

  const handleDeleteChat = async (e: React.MouseEvent, chatId: string) => {
    e.preventDefault()
    e.stopPropagation()
    if (window.confirm('Are you sure you want to delete this chat?')) {
      await deleteChat({ variables: { id: chatId } })
    }
  }

  if (loading) return <div className="text-text-primary">Loading...</div>
  if (error) return <div className="text-red-400">Error: {error.message}</div>

  const chats = data?.chats || []
  const regularChats = chats.filter((chat: any) => chat.name !== 'Дневник')

  return (
    <div className="max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-5xl font-bold text-text-primary">Chats</h1>
        <div className="flex gap-3">
          <Link to="/diary">
            <Button variant="secondary">Дневник</Button>
          </Link>
          <Button onClick={() => setIsModalOpen(true)}>Create Chat</Button>
        </div>
      </div>

      {regularChats.length === 0 ? (
        <Card>
          <p className="text-text-secondary text-center py-8">
            No chats yet. Create your first chat to get started.
          </p>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {regularChats.map((chat: any) => (
            <Link key={chat.id} to={`/chat/${chat.id}`}>
              <Card className="hover:bg-black/40 transition-colors cursor-pointer h-full">
                <div className="flex items-center justify-between mb-2">
                  <h3 className="text-xl font-bold text-text-primary">{chat.name}</h3>
                  <button
                    onClick={(e) => handleDeleteChat(e, chat.id)}
                    className="text-red-400 hover:text-red-300 px-2 py-1 rounded transition-colors"
                    title="Delete chat"
                  >
                    ×
                  </button>
                </div>
                <p className="text-text-secondary text-sm">
                  {chat.users.length} {chat.users.length === 1 ? 'participant' : 'participants'}
                </p>
                <div className="mt-3 flex flex-wrap gap-2">
                  {chat.users.slice(0, 3).map((user: any) => (
                    <span
                      key={user.id}
                      className="text-xs bg-white/10 px-2 py-1 rounded text-text-primary"
                    >
                      {user.name}
                    </span>
                  ))}
                  {chat.users.length > 3 && (
                    <span className="text-xs text-text-secondary">
                      +{chat.users.length - 3} more
                    </span>
                  )}
                </div>
              </Card>
            </Link>
          ))}
        </div>
      )}

      <ChatModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSuccess={() => {
          setIsModalOpen(false)
          refetch()
        }}
      />
    </div>
  )
}

