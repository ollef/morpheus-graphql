{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE DefaultSignatures    #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE NamedFieldPuns       #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeApplications     #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Data.Morpheus.Types.GQLType
  ( GQLType(..)
  ) where

import           Data.Map                          (Map)
import           Data.Proxy                        (Proxy (..))
import           Data.Set                          (Set)
import           Data.Text                         (Text, intercalate, pack)
import           Data.Typeable                     (TyCon, TypeRep, Typeable, splitTyConApp, tyConFingerprint,
                                                    tyConName, typeRep)

-- MORPHEUS
import           Data.Morpheus.Kind
import           Data.Morpheus.Types.Custom        (MapKind, Pair)
import           Data.Morpheus.Types.Internal.Data (DataFingerprint (..))
import           Data.Morpheus.Types.Resolver      (Resolver)

resolverCon :: TyCon
resolverCon = fst $ splitTyConApp $ typeRep $ Proxy @(Resolver Maybe)

-- | replaces typeName (A,B) with Pair_A_B
replacePairCon :: TyCon -> TyCon
replacePairCon x
  | hsPair == x = gqlPair
  where
    hsPair = fst $ splitTyConApp $ typeRep $ Proxy @(Int, Int)
    gqlPair = fst $ splitTyConApp $ typeRep $ Proxy @(Pair Int Int)
replacePairCon x = x

-- Ignores Resolver name  from typeName
ignoreResolver :: (TyCon, [TypeRep]) -> [TyCon]
ignoreResolver (con, _)
  | con == resolverCon = []
ignoreResolver (con, args) =
  con : concatMap (ignoreResolver . splitTyConApp) args

-- | GraphQL type, every graphQL type should have an instance of 'GHC.Generics.Generic' and 'GQLType'.
--
--  @
--    ... deriving (Generic, GQLType)
--  @
--
-- if you want to add description
--
--  @
--       ... deriving (Generic)
--
--     instance GQLType ... where
--       description = const "your description ..."
--  @
class GQLType a where
  type KIND a :: GQL_KIND
  description :: Proxy a -> Text
  description _ = ""
  __typeVisibility :: Proxy a -> Bool
  __typeVisibility = const True
  __typeName :: Proxy a -> Text
  default __typeName :: (Typeable a) =>
    Proxy a -> Text
  __typeName _ = intercalate "_" (getName $ Proxy @a)
    where
      getName =
        fmap
          (map (pack . tyConName))
          (map replacePairCon . ignoreResolver . splitTyConApp . typeRep)
  __typeFingerprint :: Proxy a -> DataFingerprint
  default __typeFingerprint :: (Typeable a) =>
    Proxy a -> DataFingerprint
  __typeFingerprint _ = TypeableFingerprint $ conFingerprints (Proxy @a)
    where
      conFingerprints =
        fmap (map tyConFingerprint) (ignoreResolver . splitTyConApp . typeRep)

instance GQLType Int where
  type KIND Int = SCALAR
  __typeVisibility = const False

instance GQLType Float where
  type KIND Float = SCALAR
  __typeVisibility = const False

instance GQLType Text where
  type KIND Text = SCALAR
  __typeName = const "String"
  __typeVisibility = const False

instance GQLType Bool where
  type KIND Bool = SCALAR
  __typeName = const "Boolean"
  __typeVisibility = const False

instance GQLType a => GQLType (Maybe a) where
  type KIND (Maybe a) = WRAPPER
  __typeName _ = __typeName (Proxy @a)
  __typeFingerprint _ = __typeFingerprint (Proxy @a)

instance GQLType a => GQLType [a] where
  type KIND [a] = WRAPPER
  __typeName _ = __typeName (Proxy @a)
  __typeFingerprint _ = __typeFingerprint (Proxy @a)

instance (Typeable a, Typeable b, GQLType a, GQLType b) => GQLType (a, b) where
  type KIND (a, b) = WRAPPER
  __typeName _ = __typeName $ Proxy @(Pair a b)

instance GQLType a => GQLType (Set a) where
  type KIND (Set a) = WRAPPER
  __typeName _ = __typeName (Proxy @a)
  __typeFingerprint _ = __typeFingerprint (Proxy @a)

instance (Typeable a, Typeable b, GQLType a, GQLType b) =>
         GQLType (Pair a b) where
  type KIND (Pair a b) = OBJECT

instance (Typeable a, Typeable b, Typeable m, GQLType a, GQLType b) =>
         GQLType (MapKind a b m) where
  type KIND (MapKind a b m) = OBJECT

instance (Typeable k, Typeable v) => GQLType (Map k v) where
  type KIND (Map k v) = WRAPPER

instance GQLType a => GQLType (Resolver m a) where
  type KIND (Resolver m a) = WRAPPER
  __typeName _ = __typeName (Proxy @a)
  __typeFingerprint _ = __typeFingerprint (Proxy @a)

instance GQLType b => GQLType (a -> b) where
  type KIND (a -> b) = WRAPPER
  __typeName _ = __typeName (Proxy @b)
  __typeFingerprint _ = __typeFingerprint (Proxy @b)
