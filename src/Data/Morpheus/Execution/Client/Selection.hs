{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE NamedFieldPuns      #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}

module Data.Morpheus.Execution.Client.Selection
  ( operationTypes
  ) where

import           Data.Semigroup                             ((<>))
import           Data.Text                                  (Text, unpack)

--
-- MORPHEUS
import           Data.Morpheus.Error.Utils                  (globalErrorMessage)
import           Data.Morpheus.Types.Internal.AST.Operation (Operation (..), ValidOperation, Variable (..),
                                                             VariableDefinitions)
import           Data.Morpheus.Types.Internal.AST.Selection (Selection (..), SelectionRec (..))
import           Data.Morpheus.Types.Internal.Data          (DataField (..), DataFullType (..), DataLeaf (..),
                                                             DataType (..), DataTypeLib (..), DataTypeWrapper,
                                                             allDataTypes)
import           Data.Morpheus.Types.Internal.DataD         (ConsD (..), FieldD (..), TypeD (..), gqlToHSWrappers)
import           Data.Morpheus.Types.Internal.Validation    (GQLErrors, Validation)
import           Data.Morpheus.Validation.Utils.Utils       (lookupType)

compileError :: Text -> GQLErrors
compileError x = globalErrorMessage $ "Unhandled Compile Time Error: \"" <> x <> "\" ;"

operationTypes :: DataTypeLib -> VariableDefinitions -> ValidOperation -> Validation ([TypeD], [TypeD])
operationTypes lib variables = genOperation
  where
    queryDataType = OutputObject $ snd $ query lib
    -----------------------------------------------------
    typeByField :: Text -> DataFullType -> Validation DataFullType
    typeByField key datatype = fst <$> fieldDataType datatype key
    ------------------------------------------------------
    fieldDataType :: DataFullType -> Text -> Validation (DataFullType, [DataTypeWrapper])
    fieldDataType (OutputObject DataType {typeData}) key =
      case lookup key typeData of
        Just DataField {fieldTypeWrappers, fieldType} -> trans <$> getType lib fieldType
          where trans x = (x, fieldTypeWrappers)
        Nothing -> Left (compileError key)
    fieldDataType _ key = Left (compileError key)
    -----------------------------------------------------
    genOperation Operation {operationName, operationSelection} = do
      argTypes <- rootArguments (operationName <> "Args")
      queryTypes <- genRecordType operationName queryDataType operationSelection
      pure (argTypes, queryTypes)
    -------------------------------------------{--}
    genInputType :: Text -> Validation [TypeD]
    genInputType name = getType lib name >>= subTypes
      where
        subTypes (InputObject DataType {typeName, typeData}) = do
          types <- concat <$> mapM toInputTypeD typeData
          fields <- traverse toFieldD typeData
          pure $ typeD fields : types
          where
            typeD fields = TypeD {tName = unpack typeName, tCons = [ConsD {cName = unpack typeName, cFields = fields}]}
            ---------------------------------------------------------------
            toInputTypeD :: (Text, DataField a) -> Validation [TypeD]
            toInputTypeD (_, DataField {fieldType}) = genInputType fieldType
            ----------------------------------------------------------------
            toFieldD :: (Text, DataField a) -> Validation FieldD
            toFieldD (key, DataField {fieldType, fieldTypeWrappers}) = do
              fType <- typeFrom <$> getType lib fieldType
              pure $ FieldD (unpack key) (wrType fType)
              where
                wrType fieldT = gqlToHSWrappers fieldTypeWrappers (unpack fieldT)
        subTypes (Leaf x) = buildLeaf x
        subTypes _ = pure []
    -------------------------------------------
    rootArguments :: Text -> Validation [TypeD]
    rootArguments name = do
      types <- concat <$> mapM (genInputType . variableType . snd) variables
      pure $ typeD : types
      where
        typeD :: TypeD
        typeD = TypeD {tName = unpack name, tCons = [ConsD {cName = unpack name, cFields = map fieldD variables}]}
        ---------------------------------------
        fieldD :: (Text, Variable ()) -> FieldD
        fieldD (key, Variable {variableType, variableTypeWrappers}) = FieldD (unpack key) wrType
          where
            wrType = gqlToHSWrappers variableTypeWrappers (unpack variableType)
    -------------------------------------------
    getCon name dataType selectionSet = do
      cFields <- genFields dataType selectionSet
      subTypes <- newFieldTypes dataType selectionSet
      pure (ConsD {cName = unpack name, cFields}, subTypes)
      ---------------------------------------------------------------------------------------------
      where
        genFields datatype = mapM typeNameFromField
          where
            typeNameFromField :: (Text, Selection) -> Validation FieldD
            typeNameFromField (key, Selection {selectionRec = SelectionAlias {aliasFieldName}}) =
              FieldD (unpack key) <$> lookupFieldType aliasFieldName
            typeNameFromField (key, _) = FieldD (unpack key) <$> lookupFieldType key
            ------------------------------------------------------------
            lookupFieldType key = do
              (newType, wrappers) <- fieldDataType datatype key
              pure $ gqlToHSWrappers wrappers (unpack $ typeFrom newType)
    --------------------------------------------
    genRecordType name dataType selectionSet = do
      (con, subTypes) <- getCon name dataType selectionSet
      pure $ TypeD {tName = unpack name, tCons = [con]} : subTypes
    ------------------------------------------------------------------------------------------------------------
    newFieldTypes parentType = fmap concat <$> mapM validateSelection
      where
        validateSelection :: (Text, Selection) -> Validation [TypeD]
        validateSelection (key, Selection {selectionRec = SelectionField}) =
          key `typeByField` parentType >>= buildSelField
          where
            buildSelField (Leaf x) = buildLeaf x
            buildSelField _        = Left $ compileError "Invalid schema Expected scalar"
        validateSelection (key, Selection {selectionRec = SelectionSet selectionSet}) = do
          datatype <- key `typeByField` parentType
          genRecordType (typeFrom datatype) datatype selectionSet
        validateSelection (_, selection@Selection {selectionRec = SelectionAlias {aliasFieldName, aliasSelection}}) =
          validateSelection (aliasFieldName, selection {selectionRec = aliasSelection})
        validateSelection (key, Selection {selectionRec = UnionSelection unionSelections}) = do
          unionTypeName <- typeFrom <$> key `typeByField` parentType
          (tCons, subTypes) <- unzip <$> mapM getUnionType unionSelections
          pure $ TypeD {tName = unpack unionTypeName, tCons} : concat subTypes
          where
            getUnionType (typeKey, selSet) = do
              conDatatype <- getType lib typeKey
              getCon typeKey conDatatype selSet

buildLeaf :: DataLeaf -> Validation [TypeD]
buildLeaf (LeafEnum DataType {typeName, typeData}) =
  pure [TypeD {tName = unpack typeName, tCons = map enumOption typeData}]
  where
    enumOption name = ConsD {cName = unpack name, cFields = []}
buildLeaf _ = pure []

getType :: DataTypeLib -> Text -> Validation DataFullType
getType lib typename = lookupType (compileError typename) (allDataTypes lib) typename

isPrimitive :: Text -> Bool
isPrimitive "Boolean" = True
isPrimitive "Int"     = True
isPrimitive "Float"   = True
isPrimitive "String"  = True
isPrimitive "ID"      = True
isPrimitive _         = False

typeFrom :: DataFullType -> Text
typeFrom (Leaf (BaseScalar x)) = typeName x
typeFrom (Leaf (CustomScalar DataType {typeName}))
  | isPrimitive typeName = typeName
  | otherwise = "ScalarValue"
typeFrom (Leaf (LeafEnum x)) = typeName x
typeFrom (InputObject x) = typeName x
typeFrom (OutputObject x) = typeName x
typeFrom (Union x) = typeName x
typeFrom (InputUnion x) = typeName x
