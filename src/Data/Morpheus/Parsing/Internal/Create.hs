{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Morpheus.Parsing.Internal.Create
  ( createField
  , createArgument
  , createType
  , createScalarType
  , createEnumType
  , createUnionType
  , createDataTypeLib
  ) where

import           Data.Morpheus.Types.Internal.Data (DataField (..), DataFingerprint (..), DataFullType (..),
                                                    DataLeaf (..), DataType (..), DataTypeLib (..), DataTypeWrapper,
                                                    DataValidator (..), defineType, initTypeLib)
import           Data.Text                         (Text)

createField :: a -> Text -> ([DataTypeWrapper], Text) -> DataField a
createField fieldArgs fieldName (fieldTypeWrappers, fieldType) =
  DataField {fieldArgs, fieldName, fieldType, fieldTypeWrappers, fieldHidden = False}

createArgument :: Text -> ([DataTypeWrapper], Text) -> (Text, DataField ())
createArgument fieldName x = (fieldName, createField () fieldName x)

createType :: Text -> a -> DataType a
createType typeName typeData =
  DataType {typeName, typeDescription = "", typeFingerprint = SystemFingerprint "", typeVisibility = True, typeData}

createScalarType :: Text -> (Text, DataFullType)
createScalarType typeName = (typeName, Leaf $ CustomScalar $ createType typeName (DataValidator pure))

createEnumType :: Text -> [Text] -> (Text, DataFullType)
createEnumType typeName typeData = (typeName, Leaf $ LeafEnum $ createType typeName typeData)

createUnionType :: Text -> [Text] -> (Text, DataFullType)
createUnionType typeName typeData = (typeName, Union $ createType typeName $ map unionField typeData)
  where
    unionField fieldType = createField () "" ([], fieldType)

createDataTypeLib :: Monad m => [(Text, DataFullType)] -> m DataTypeLib
createDataTypeLib types =
  case takeByKey "Query" types of
    (Just query, lib1) ->
      case takeByKey "Mutation" lib1 of
        (mutation, lib2) ->
          case takeByKey "Subscription" lib2 of
            (subscription, lib3) -> pure ((foldr defineType (initTypeLib query) lib3) {mutation, subscription})
    _ -> fail "Query Not Defined"
  ----------------------------------------------------------------------------
  where
    takeByKey key lib =
      case lookup key lib of
        Just (OutputObject value) -> (Just (key, value), filter ((/= key) . fst) lib)
        _                         -> (Nothing, lib)
