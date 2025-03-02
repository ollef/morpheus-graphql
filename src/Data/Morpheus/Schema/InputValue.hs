{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies      #-}

module Data.Morpheus.Schema.InputValue
  ( InputValue(..)
  , createInputValueWith
  ) where

import           Data.Aeson
import           Data.Morpheus.Kind          (OBJECT)
import           Data.Morpheus.Types.GQLType (GQLType (KIND, __typeName, __typeVisibility))
import           Data.Text                   (Text)
import           Data.Typeable               (Typeable)
import           GHC.Generics

instance Typeable a => GQLType (InputValue a) where
  type KIND (InputValue a) = OBJECT
  __typeName = const "__InputValue"
  __typeVisibility = const False

data InputValue t = InputValue
  { name         :: Text
  , description  :: Maybe Text
  , type'        :: t
  , defaultValue :: Maybe Text
  } deriving (Show, Generic)

instance FromJSON a => FromJSON (InputValue a) where
  parseJSON = withObject "InputValue" objectParser
    where
      objectParser o = InputValue <$> o .: "name" <*> o .:? "description" <*> o .: "type" <*> o .:? "defaultValue"

createInputValueWith :: Text -> a -> InputValue a
createInputValueWith _name ofType =
  InputValue {name = _name, description = Nothing, type' = ofType, defaultValue = Nothing}
