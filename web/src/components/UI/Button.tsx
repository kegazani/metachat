import { ButtonHTMLAttributes, ReactNode } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode
  variant?: 'primary' | 'secondary'
}

export default function Button({ children, variant = 'primary', className = '', ...props }: ButtonProps) {
  const baseClasses = 'px-6 py-2.5 rounded-lg font-bold text-sm tracking-wide transition-colors'
  const variantClasses = {
    primary: 'bg-zinc-800 text-white hover:bg-zinc-700',
    secondary: 'bg-zinc-700/50 text-white/90 hover:bg-zinc-700/70',
  }

  return (
    <button
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  )
}

