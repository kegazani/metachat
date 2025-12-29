import { useParams } from 'react-router-dom'
import { useQuery, useMutation } from '@apollo/client'
import { CHAT_QUERY } from '../graphql/queries/chats'
import { CHAT_HISTORIES_QUERY } from '../graphql/queries/messages'
import { CREATE_CHAT_HISTORY_MUTATION, DELETE_CHAT_HISTORY_MUTATION } from '../graphql/mutations/messages'
import Card from '../components/UI/Card'
import MessageList from '../components/Messages/MessageList'
import MessageInput from '../components/Messages/MessageInput'
import DiaryModal from '../components/Diary/DiaryModal'
import { useState, useEffect } from 'react'
import { useAuth } from '../hooks/useAuth'

export default function Chat() {
  const { chatId } = useParams<{ chatId: string }>()
  const { token } = useAuth()
  const [userId, setUserId] = useState<string>('')
  const [selectedDiaryEntry, setSelectedDiaryEntry] = useState<any | null>(null)
  const [isDiaryModalOpen, setIsDiaryModalOpen] = useState(false)

  const { data: chatData, loading: chatLoading, error: chatError } = useQuery(CHAT_QUERY, {
    variables: { id: chatId },
    skip: !chatId,
  })

  const { data: messagesData, loading: messagesLoading, error: messagesError, refetch } = useQuery(
    CHAT_HISTORIES_QUERY,
    {
      variables: { chatId: chatId!, limit: 100 },
      skip: !chatId,
      pollInterval: 2000,
    }
  )

  useEffect(() => {
    if (token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]))
        setUserId(String(payload.user_id))
      } catch (e) {
        console.error('Failed to parse token', e)
      }
    }
  }, [token])

  const [createMessage] = useMutation(CREATE_CHAT_HISTORY_MUTATION, {
    onCompleted: () => {
      refetch()
    },
  })

  const [deleteMessage] = useMutation(DELETE_CHAT_HISTORY_MUTATION, {
    onCompleted: () => {
      refetch()
    },
  })

  if (chatLoading || messagesLoading) return <div className="text-text-primary">Loading...</div>
  if (chatError) return <div className="text-red-400">Error: {chatError.message}</div>
  if (messagesError) return <div className="text-red-400">Error: {messagesError.message}</div>

  const chat = chatData?.chat
  const messages = messagesData?.chatHistories || []
  const isDiaryChat = chat?.name === 'Дневник'

  const handleSendMessage = async (text: string) => {
    if (!chatId || !userId || !text.trim()) return

    await createMessage({
      variables: {
        input: {
          chatId,
          userId,
          messageText: text,
          type: isDiaryChat ? 'diary' : undefined,
        },
      },
    })
  }

  const handleDiaryClick = (message: any) => {
    setSelectedDiaryEntry(message)
    setIsDiaryModalOpen(true)
  }

  const handleDeleteMessage = async (messageId: string) => {
    await deleteMessage({
      variables: { id: messageId },
    })
  }

  return (
    <div className="max-w-4xl mx-auto h-[calc(100vh-8rem)] flex flex-col">
      <Card className="mb-4">
        <h2 className="text-2xl font-bold text-text-primary">{chat?.name}</h2>
        <p className="text-text-secondary text-sm mt-1">
          {chat?.users.length} {chat?.users.length === 1 ? 'participant' : 'participants'}
        </p>
      </Card>

      <Card className="flex-1 flex flex-col overflow-hidden">
        <MessageList
          messages={messages}
          currentUserId={userId}
          onDelete={handleDeleteMessage}
          onDiaryClick={isDiaryChat ? handleDiaryClick : undefined}
        />
        <MessageInput onSend={handleSendMessage} />
      </Card>

      <DiaryModal
        isOpen={isDiaryModalOpen}
        entry={selectedDiaryEntry}
        onClose={() => {
          setIsDiaryModalOpen(false)
          setSelectedDiaryEntry(null)
        }}
      />
    </div>
  )
}

