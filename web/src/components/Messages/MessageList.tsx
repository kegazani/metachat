import MessageItem from './MessageItem'

interface MessageListProps {
  messages: any[]
  currentUserId: string
  onDelete: (messageId: string) => void
  onDiaryClick?: (message: any) => void
}

export default function MessageList({ messages, currentUserId, onDelete, onDiaryClick }: MessageListProps) {
  return (
    <div className="flex-1 overflow-y-auto space-y-4 mb-4">
      {messages.length === 0 ? (
        <div className="text-center text-text-secondary py-8">
          No messages yet. Start the conversation!
        </div>
      ) : (
        messages.map((message) => (
          <MessageItem
            key={message.id}
            message={message}
            isOwn={message.userId === currentUserId}
            onDelete={onDelete}
            onDiaryClick={onDiaryClick}
          />
        ))
      )}
    </div>
  )
}

