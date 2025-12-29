import { useQuery, useMutation } from '@apollo/client'
import { useAuth } from '../hooks/useAuth'
import { CHATS_QUERY } from '../graphql/queries/chats'
import { CHAT_HISTORIES_QUERY } from '../graphql/queries/messages'
import { CREATE_CHAT_HISTORY_MUTATION } from '../graphql/mutations/messages'
import { CREATE_CHAT_MUTATION } from '../graphql/mutations/chats'
import Card from '../components/UI/Card'
import DiaryEntry from '../components/Diary/DiaryEntry'
import MessageInput from '../components/Messages/MessageInput'
import DiaryModal from '../components/Diary/DiaryModal'
import { useState, useEffect } from 'react'
import Button from '../components/UI/Button'

export default function Diary() {
  const { token } = useAuth()
  const [userId, setUserId] = useState<string>('')
  const [selectedEntry, setSelectedEntry] = useState<any | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isCreating, setIsCreating] = useState(false)

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

  const { data: chatsData, loading: chatsLoading, refetch: refetchChats } = useQuery(CHATS_QUERY, {
    variables: { limit: 100, offset: 0 },
  })

  const chats = chatsData?.chats || []
  const diaryChat = chats.find((chat: any) => chat.name === 'Дневник')
  const diaryChatId = diaryChat?.id

  const { data: messagesData, loading: messagesLoading, refetch } = useQuery(
    CHAT_HISTORIES_QUERY,
    {
      variables: { chatId: diaryChatId, limit: 100 },
      skip: !diaryChatId,
      pollInterval: 2000,
    }
  )

  const [createChat] = useMutation(CREATE_CHAT_MUTATION, {
    onCompleted: () => {
      refetchChats()
      setIsCreating(false)
    },
  })

  const [createMessage] = useMutation(CREATE_CHAT_HISTORY_MUTATION, {
    onCompleted: () => {
      refetch()
    },
  })

  const handleCreateDiary = async () => {
    if (!userId) return
    setIsCreating(true)
    await createChat({
      variables: {
        input: {
          name: 'Дневник',
          userIds: [userId],
        },
      },
    })
  }

  if (chatsLoading || isCreating) {
    return <div className="text-text-primary">Loading...</div>
  }

  if (!diaryChat) {
    return (
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-5xl font-bold text-text-primary mb-2">Дневник</h1>
          <p className="text-text-secondary">Ваши личные записи и размышления</p>
        </div>
        <Card>
          <div className="text-center py-8">
            <p className="text-text-secondary mb-4">
              Дневник не найден. Создайте дневник для начала работы.
            </p>
            <Button onClick={handleCreateDiary} disabled={!userId}>
              Создать дневник
            </Button>
          </div>
        </Card>
      </div>
    )
  }

  if (messagesLoading) {
    return <div className="text-text-primary">Loading...</div>
  }

  const messages = messagesData?.chatHistories || []
  const diaryEntries = messages.filter((m: any) => m.type === 'diary')

  const handleSendMessage = async (text: string) => {
    if (!diaryChatId || !userId || !text.trim()) return

    await createMessage({
      variables: {
        input: {
          chatId: diaryChatId,
          userId,
          messageText: text,
          type: 'diary',
        },
      },
    })
  }

  const handleViewDetails = (entry: any) => {
    setSelectedEntry(entry)
    setIsModalOpen(true)
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-8">
        <h1 className="text-5xl font-bold text-text-primary mb-2">Дневник</h1>
        <p className="text-text-secondary">Ваши личные записи и размышления</p>
      </div>

      <Card className="mb-4">
        <h2 className="text-xl font-bold text-text-primary mb-4">Новая запись</h2>
        <MessageInput onSend={handleSendMessage} />
      </Card>

      <div>
        <h2 className="text-2xl font-bold text-text-primary mb-4">Предыдущие записи</h2>
        {diaryEntries.length === 0 ? (
          <Card>
            <p className="text-text-secondary text-center py-8">
              Пока нет записей. Создайте первую запись в дневнике!
            </p>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {diaryEntries.map((entry: any) => (
              <DiaryEntry key={entry.id} entry={entry} onViewDetails={handleViewDetails} />
            ))}
          </div>
        )}
      </div>

      <DiaryModal
        isOpen={isModalOpen}
        entry={selectedEntry}
        onClose={() => {
          setIsModalOpen(false)
          setSelectedEntry(null)
        }}
      />
    </div>
  )
}

