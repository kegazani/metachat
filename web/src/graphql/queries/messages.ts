import { gql } from '@apollo/client'

export const CHAT_HISTORIES_QUERY = gql`
  query ChatHistories($chatId: ID!, $limit: Int) {
    chatHistories(chatId: $chatId, limit: $limit) {
      id
      chatId
      userId
      messageText
      type
      createdAt
    }
  }
`

export const CHAT_HISTORY_QUERY = gql`
  query ChatHistory($id: ID!) {
    chatHistory(id: $id) {
      id
      chatId
      userId
      messageText
      type
      createdAt
    }
  }
`

