import { format } from 'date-fns'
import Button from '../UI/Button'

interface MessageItemProps {
  message: any
  isOwn: boolean
  onDelete: (messageId: string) => void
  onDiaryClick?: (message: any) => void
}

export default function MessageItem({ message, isOwn, onDelete, onDiaryClick }: MessageItemProps) {
  const isDiary = message.type === 'diary'

  return (
    <div className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[70%] rounded-lg p-4 ${
          isOwn
            ? 'bg-white/10 border border-white/20'
            : 'bg-black/30 border border-white/10'
        } ${isDiary ? 'cursor-pointer hover:opacity-80' : ''}`}
        onClick={isDiary && onDiaryClick ? () => onDiaryClick(message) : undefined}
      >
        <div className="flex items-center justify-between gap-3 mb-2">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-text-primary">User {message.userId}</span>
            {isDiary && (
              <span className="text-xs bg-blue-500/20 text-blue-300 px-2 py-1 rounded">
                Дневник
              </span>
            )}
          </div>
          {isOwn && (
            <Button
              variant="secondary"
              onClick={(e) => {
                e.stopPropagation()
                onDelete(message.id)
              }}
              className="!px-2 !py-1 text-xs"
            >
              Delete
            </Button>
          )}
        </div>
        <p className="text-text-primary whitespace-pre-wrap break-words">{message.messageText}</p>
        <p className="text-xs text-text-secondary mt-2">
          {format(new Date(message.createdAt), 'MMM d, HH:mm')}
        </p>
      </div>
    </div>
  )
}

