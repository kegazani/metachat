import { gql } from '@apollo/client'

export const CREATE_CHAT_MUTATION = gql`
  mutation CreateChat($input: CreateChatInput!) {
    createChat(input: $input) {
      id
      name
      users {
        id
        name
      }
      createdAt
    }
  }
`

export const UPDATE_CHAT_MUTATION = gql`
  mutation UpdateChat($input: UpdateChatInput!) {
    updateChat(input: $input) {
      id
      name
      users {
        id
        name
      }
      updatedAt
    }
  }
`

export const DELETE_CHAT_MUTATION = gql`
  mutation DeleteChat($id: ID!) {
    deleteChat(id: $id)
  }
`

export const ADD_USER_TO_CHAT_MUTATION = gql`
  mutation AddUserToChat($chatId: ID!, $userId: ID!) {
    addUserToChat(chatId: $chatId, userId: $userId) {
      id
      name
      users {
        id
        name
      }
    }
  }
`

export const REMOVE_USER_FROM_CHAT_MUTATION = gql`
  mutation RemoveUserFromChat($chatId: ID!, $userId: ID!) {
    removeUserFromChat(chatId: $chatId, userId: $userId) {
      id
      name
      users {
        id
        name
      }
    }
  }
`

