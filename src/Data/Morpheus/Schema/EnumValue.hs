{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies      #-}

module Data.Morpheus.Schema.EnumValue
  ( EnumValue(..)
  , createEnumValue
  , isEnumOf
  ) where

import           Data.Aeson                  (FromJSON (..))
import           Data.Morpheus.Kind          (OBJECT)
import           Data.Morpheus.Types.GQLType (GQLType (KIND, __typeName, __typeVisibility))
import           Data.Text                   (Text)
import           GHC.Generics

instance GQLType EnumValue where
  type KIND EnumValue = OBJECT
  __typeName = const "__EnumValue"
  __typeVisibility = const False

data EnumValue = EnumValue
  { name              :: Text
  , description       :: Maybe Text
  , isDeprecated      :: Bool
  , deprecationReason :: Maybe Text
  } deriving (Show, Generic, FromJSON)

createEnumValue :: Text -> EnumValue
createEnumValue enumName =
  EnumValue {name = enumName, description = Nothing, isDeprecated = False, deprecationReason = Nothing}

isEnumValue :: Text -> EnumValue -> Bool
isEnumValue inpName enum = inpName == name enum

isEnumOf :: Text -> [EnumValue] -> Bool
isEnumOf enumName enumValues =
  case filter (isEnumValue enumName) enumValues of
    [] -> False
    _  -> True
