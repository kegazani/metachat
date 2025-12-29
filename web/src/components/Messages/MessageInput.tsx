import { useState } from 'react'
import Button from '../UI/Button'

interface MessageInputProps {
  onSend: (text: string) => void
}

export default function MessageInput({ onSend }: MessageInputProps) {
  const [message, setMessage] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (message.trim()) {
      onSend(message.trim())
      setMessage('')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-3">
      <input
        type="text"
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        placeholder="Type a message..."
        className="flex-1 px-4 py-2.5 bg-black/30 border border-white/10 rounded-lg text-text-primary placeholder:text-white/40 focus:outline-none focus:border-white/30 transition-colors"
      />
      <Button type="submit" disabled={!message.trim()}>
        Send
      </Button>
    </form>
  )
}

