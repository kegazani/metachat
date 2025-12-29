import { ReactNode } from 'react'

interface CardProps {
  children: ReactNode
  className?: string
}

export default function Card({ children, className = '' }: CardProps) {
  return (
    <div className={`backdrop-blur-md bg-black/30 border border-white/10 rounded-2xl p-6 shadow-lg ${className}`}>
      {children}
    </div>
  )
}

