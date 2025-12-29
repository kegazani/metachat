import { gql } from '@apollo/client'

export const CREATE_CHAT_HISTORY_MUTATION = gql`
  mutation CreateChatHistory($input: CreateChatHistoryInput!) {
    createChatHistory(input: $input) {
      id
      chatId
      userId
      messageText
      type
      createdAt
    }
  }
`

export const DELETE_CHAT_HISTORY_MUTATION = gql`
  mutation DeleteChatHistory($id: ID!) {
    deleteChatHistory(id: $id)
  }
`

export const UPDATE_DIARY_MUTATION = gql`
  mutation UpdateDiary($userId: ID!, $data: JSON!) {
    updateDiary(userId: $userId, data: $data) {
      id
      userId
      chatId
      data
      updatedAt
    }
  }
`

