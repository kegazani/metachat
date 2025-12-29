import { gql } from '@apollo/client'

export const CHATS_QUERY = gql`
  query Chats($limit: Int, $offset: Int) {
    chats(limit: $limit, offset: $offset) {
      id
      name
      users {
        id
        name
      }
      createdAt
      updatedAt
    }
  }
`

export const CHAT_QUERY = gql`
  query Chat($id: ID!) {
    chat(id: $id) {
      id
      name
      users {
        id
        name
      }
      createdAt
      updatedAt
    }
  }
`

