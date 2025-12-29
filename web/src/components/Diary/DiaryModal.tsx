import { format } from 'date-fns'
import Modal from '../UI/Modal'
import Button from '../UI/Button'

interface DiaryModalProps {
  isOpen: boolean
  entry: any | null
  onClose: () => void
}

export default function DiaryModal({ isOpen, entry, onClose }: DiaryModalProps) {
  if (!entry) return null

  const entryData = typeof entry.data === 'string' ? JSON.parse(entry.data) : entry.data
  const mood = entryData?.mood || 'unknown'
  const moodLabels: Record<string, string> = {
    happy: 'Радостное',
    sad: 'Грустное',
    neutral: 'Нейтральное',
    anxious: 'Тревожное',
    unknown: 'Не указано'
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Детали записи дневника">
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <span className="text-sm text-text-secondary">
            {format(new Date(entry.createdAt), 'dd MMMM yyyy, HH:mm')}
          </span>
          <span className={`text-xs px-3 py-1 rounded ${
            mood === 'happy' ? 'bg-green-500/20 text-green-300' :
            mood === 'sad' ? 'bg-blue-500/20 text-blue-300' :
            mood === 'neutral' ? 'bg-gray-500/20 text-gray-300' :
            'bg-yellow-500/20 text-yellow-300'
          }`}>
            {moodLabels[mood] || mood}
          </span>
        </div>

        <div>
          <h3 className="text-sm font-semibold text-text-secondary mb-2">Текст записи:</h3>
          <p className="text-text-primary whitespace-pre-wrap bg-black/20 p-3 rounded">
            {entry.messageText}
          </p>
        </div>

        {entryData && Object.keys(entryData).length > 0 && (
          <div>
            <h3 className="text-sm font-semibold text-text-secondary mb-2">Дополнительная информация:</h3>
            <pre className="text-text-primary bg-black/20 p-3 rounded text-xs overflow-auto">
              {JSON.stringify(entryData, null, 2)}
            </pre>
          </div>
        )}

        <div className="flex justify-end">
          <Button onClick={onClose}>Закрыть</Button>
        </div>
      </div>
    </Modal>
  )
}

