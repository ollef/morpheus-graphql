{-# LANGUAGE DeriveLift        #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Morpheus.Types.Internal.Data
  ( Key
  , DataScalar
  , DataEnum
  , DataObject
  , DataInputField
  , DataArgument
  , DataOutputField
  , DataInputObject
  , DataOutputObject
  , DataUnion
  , DataOutputType
  , DataInputType
  , DataArguments
  , DataField(..)
  , DataType(..)
  , DataLeaf(..)
  , DataKind(..)
  , DataFullType(..)
  , DataTypeLib(..)
  , DataTypeWrapper(..)
  , DataValidator(..)
  , DataTypeKind(..)
  , DataFingerprint(..)
  , isTypeDefined
  , initTypeLib
  , defineType
  , showWrappedType
  , showFullAstType
  , isFieldNullable
  , allDataTypes
  , lookupDataType
  , kindOf
  ) where

import           Data.Morpheus.Types.Internal.Value (Value (..))
import           Data.Text                          (Text)
import qualified Data.Text                          as T (concat)
import           GHC.Fingerprint.Type               (Fingerprint)
import           Language.Haskell.TH.Syntax         (Lift)

type Key = Text

data DataTypeKind
  = KindScalar
  | KindObject
  | KindUnion
  | KindEnum
  | KindInputObject
  | KindList
  | KindNonNull
  | KindInputUnion
  deriving (Eq, Show, Lift)

data DataFingerprint
  = SystemFingerprint Text
  | TypeableFingerprint [Fingerprint]
  deriving (Show, Eq, Ord)

newtype DataValidator = DataValidator
  { validateValue :: Value -> Either Text Value
  }

instance Show DataValidator where
  show _ = "DataValidator"

type DataScalar = DataType DataValidator

type DataEnum = DataType [Key]

type DataObject a = DataType [(Key, a)]

type DataInputField = DataField ()

type DataArgument = DataInputField

type DataOutputField = DataField [(Key, DataArgument)]

type DataInputObject = DataObject DataInputField

type DataOutputObject = DataObject DataOutputField

type DataUnion = DataType [DataField ()]

type DataOutputType = DataKind DataOutputField

type DataInputType = DataKind DataInputField

type DataArguments = [(Key, DataArgument)]

data DataTypeWrapper
  = ListType
  | NonNullType
  deriving (Show, Lift)

data DataField a = DataField
  { fieldArgs         :: a
  , fieldName         :: Text
  , fieldType         :: Text
  , fieldTypeWrappers :: [DataTypeWrapper]
  , fieldHidden       :: Bool
  } deriving (Show)

isFieldNullable :: DataField a -> Bool
isFieldNullable DataField {fieldTypeWrappers = NonNullType:_} = False
isFieldNullable _                                             = True

data DataType a = DataType
  { typeName        :: Text
  , typeFingerprint :: DataFingerprint
  , typeDescription :: Text
  , typeVisibility  :: Bool
  , typeData        :: a
  } deriving (Show)

data DataLeaf
  = BaseScalar DataScalar
  | CustomScalar DataScalar
  | LeafEnum DataEnum
  deriving (Show)

data DataKind a
  = ScalarKind DataScalar
  | EnumKind DataEnum
  | ObjectKind (DataObject a)
  | UnionKind DataUnion
  deriving (Show)

data DataFullType
  = Leaf DataLeaf
  | InputObject DataInputObject
  | OutputObject DataOutputObject
  | Union DataUnion
  | InputUnion DataUnion
  deriving (Show)

data DataTypeLib = DataTypeLib
  { leaf         :: [(Text, DataLeaf)]
  , inputObject  :: [(Text, DataInputObject)]
  , object       :: [(Text, DataOutputObject)]
  , union        :: [(Text, DataUnion)]
  , inputUnion   :: [(Text, DataUnion)]
  , query        :: (Text, DataOutputObject)
  , mutation     :: Maybe (Text, DataOutputObject)
  , subscription :: Maybe (Text, DataOutputObject)
  } deriving (Show)

showWrappedType :: [DataTypeWrapper] -> Text -> Text
showWrappedType [] type'               = type'
showWrappedType (ListType:xs) type'    = T.concat ["[", showWrappedType xs type', "]"]
showWrappedType (NonNullType:xs) type' = T.concat [showWrappedType xs type', "!"]

showFullAstType :: [DataTypeWrapper] -> DataKind a -> Text
showFullAstType wrappers' (ScalarKind x) = showWrappedType wrappers' (typeName x)
showFullAstType wrappers' (EnumKind x)   = showWrappedType wrappers' (typeName x)
showFullAstType wrappers' (ObjectKind x) = showWrappedType wrappers' (typeName x)
showFullAstType wrappers' (UnionKind x)  = showWrappedType wrappers' (typeName x)

initTypeLib :: (Text, DataOutputObject) -> DataTypeLib
initTypeLib query' =
  DataTypeLib
    { leaf = []
    , inputObject = []
    , query = query'
    , object = []
    , union = []
    , inputUnion = []
    , mutation = Nothing
    , subscription = Nothing
    }

allDataTypes :: DataTypeLib -> [(Text, DataFullType)]
allDataTypes (DataTypeLib leaf' inputObject' object' union' inputUnion' query' mutation' subscription') =
  packType OutputObject query' :
  fromMaybeType mutation' ++
  fromMaybeType subscription' ++
  map (packType Leaf) leaf' ++
  map (packType InputObject) inputObject' ++
  map (packType InputUnion) inputUnion' ++ map (packType OutputObject) object' ++ map (packType Union) union'
  where
    packType f (x, y) = (x, f y)
    fromMaybeType :: Maybe (Text, DataOutputObject) -> [(Text, DataFullType)]
    fromMaybeType (Just (key', dataType')) = [(key', OutputObject dataType')]
    fromMaybeType Nothing                  = []

lookupDataType :: Text -> DataTypeLib -> Maybe DataFullType
lookupDataType name lib = name `lookup` allDataTypes lib

kindOf :: DataFullType -> DataTypeKind
kindOf (Leaf (BaseScalar _))   = KindScalar
kindOf (Leaf (CustomScalar _)) = KindScalar
kindOf (Leaf (LeafEnum _))     = KindEnum
kindOf (InputObject _)         = KindInputObject
kindOf (OutputObject _)        = KindObject
kindOf (Union _)               = KindUnion
kindOf (InputUnion _)          = KindInputUnion

isTypeDefined :: Text -> DataTypeLib -> Maybe DataFingerprint
isTypeDefined name lib = getTypeFingerprint <$> lookupDataType name lib
  where
    getTypeFingerprint :: DataFullType -> DataFingerprint
    getTypeFingerprint (Leaf (BaseScalar dataType'))   = typeFingerprint dataType'
    getTypeFingerprint (Leaf (CustomScalar dataType')) = typeFingerprint dataType'
    getTypeFingerprint (Leaf (LeafEnum dataType'))     = typeFingerprint dataType'
    getTypeFingerprint (InputObject dataType')         = typeFingerprint dataType'
    getTypeFingerprint (OutputObject dataType')        = typeFingerprint dataType'
    getTypeFingerprint (Union dataType')               = typeFingerprint dataType'
    getTypeFingerprint (InputUnion dataType')          = typeFingerprint dataType'

defineType :: (Text, DataFullType) -> DataTypeLib -> DataTypeLib
defineType (key', Leaf type') lib         = lib {leaf = (key', type') : leaf lib}
defineType (key', InputObject type') lib  = lib {inputObject = (key', type') : inputObject lib}
defineType (key', OutputObject type') lib = lib {object = (key', type') : object lib}
defineType (key', Union type') lib        = lib {union = (key', type') : union lib}
defineType (key', InputUnion type') lib   = lib {inputUnion = (key', type') : inputUnion lib}
