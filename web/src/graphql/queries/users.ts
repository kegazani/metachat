import { gql } from '@apollo/client'

export const USERS_QUERY = gql`
  query Users($limit: Int, $offset: Int) {
    users(limit: $limit, offset: $offset) {
      id
      name
      createdAt
      updatedAt
    }
  }
`

export const USER_QUERY = gql`
  query User($id: ID!) {
    user(id: $id) {
      id
      name
      createdAt
      updatedAt
    }
  }
`

