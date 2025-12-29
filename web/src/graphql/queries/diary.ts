import { gql } from '@apollo/client'

export const DIARY_QUERY = gql`
  query Diary($userId: ID!) {
    diary(userId: $userId) {
      id
      userId
      chatId
      data
      createdAt
      updatedAt
    }
  }
`

