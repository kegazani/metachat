import { format } from 'date-fns'
import Button from '../UI/Button'

interface DiaryEntryProps {
  entry: any
  onViewDetails: (entry: any) => void
}

export default function DiaryEntry({ entry, onViewDetails }: DiaryEntryProps) {
  const entryData = typeof entry.data === 'string' ? JSON.parse(entry.data) : entry.data
  const mood = entryData?.mood || 'unknown'

  return (
    <div className="bg-black/30 border border-white/10 rounded-lg p-4 hover:bg-black/40 transition-colors cursor-pointer" onClick={() => onViewDetails(entry)}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-semibold text-text-primary">
          {format(new Date(entry.createdAt), 'MMM d, yyyy HH:mm')}
        </span>
        <span className={`text-xs px-2 py-1 rounded ${
          mood === 'happy' ? 'bg-green-500/20 text-green-300' :
          mood === 'sad' ? 'bg-blue-500/20 text-blue-300' :
          mood === 'neutral' ? 'bg-gray-500/20 text-gray-300' :
          'bg-yellow-500/20 text-yellow-300'
        }`}>
          {mood}
        </span>
      </div>
      <p className="text-text-primary line-clamp-2">{entry.messageText}</p>
      <Button
        variant="secondary"
        onClick={(e) => {
          e.stopPropagation()
          onViewDetails(entry)
        }}
        className="mt-2 !px-3 !py-1 text-xs"
      >
        Подробнее
      </Button>
    </div>
  )
}

