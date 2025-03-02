{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeFamilies  #-}
{-# LANGUAGE TypeOperators #-}

-- | associating types to GraphQL Kinds
module Data.Morpheus.Kind
  ( SCALAR
  , OBJECT
  , ENUM
  , WRAPPER
  , UNION
  , INPUT_OBJECT
  , INPUT_UNION
  , GQL_KIND
  ) where

data GQL_KIND
  = SCALAR
  | OBJECT
  | ENUM
  | INPUT_OBJECT
  | UNION
  | INPUT_UNION
  | WRAPPER

-- | GraphQL Scalar: Int, Float, String, Boolean or any user defined custom Scalar type
type SCALAR = 'SCALAR

-- | GraphQL Object
type OBJECT = 'OBJECT

-- | GraphQL Enum
type ENUM = 'ENUM

-- | GraphQL input Object
type INPUT_OBJECT = 'INPUT_OBJECT

-- | GraphQL Union
type UNION = 'UNION

-- | extension for graphQL
type INPUT_UNION = 'INPUT_UNION

-- | GraphQL Arrays , Resolvers and NonNull fields
type WRAPPER = 'WRAPPER
