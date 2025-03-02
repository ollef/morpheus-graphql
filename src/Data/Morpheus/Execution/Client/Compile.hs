{-# LANGUAGE NamedFieldPuns  #-}
{-# LANGUAGE QuasiQuotes     #-}
{-# LANGUAGE TemplateHaskell #-}

module Data.Morpheus.Execution.Client.Compile
  ( compileSyntax
  , validateWith
  ) where

import qualified Data.Text                                  as T (pack)
import           Language.Haskell.TH

import           Data.Morpheus.Error.Client.Client          (renderGQLErrors)

import           Data.Morpheus.Execution.Client.Selection   (operationTypes)
import           Data.Morpheus.Parsing.Request.Parser       (parseGQL)
import qualified Data.Morpheus.Types.Internal.AST.Operation as O (Operation (..))
import           Data.Morpheus.Types.Internal.Data          (DataTypeLib)
import           Data.Morpheus.Types.IO                     (GQLRequest (..))
--
--  Morpheus
import           Data.Morpheus.Types.Internal.DataD         (QueryD (..))
import           Data.Morpheus.Types.Internal.Validation    (Validation)
import           Data.Morpheus.Types.Types                  (GQLQueryRoot (..))
import           Data.Morpheus.Validation.Utils.Utils       (VALIDATION_MODE (..))
import           Data.Morpheus.Validation.Validation        (validateRequest)

compileSyntax :: String -> Q Exp
compileSyntax queryText =
  case parseGQL request of
    Left errors -> fail (renderGQLErrors errors)
    Right root  -> [|(root, queryText)|]
  where
    request = GQLRequest {query = T.pack queryText, operationName = Nothing, variables = Nothing}

validateWith :: DataTypeLib -> (GQLQueryRoot, String) -> Validation QueryD
validateWith schema (rawRequest@GQLQueryRoot {operation}, queryText) = do
  validOperation <- validateRequest schema WITHOUT_VARIABLES rawRequest
  (queryArgTypes, queryTypes) <- operationTypes schema (O.operationArgs operation) validOperation
  return QueryD {queryText, queryTypes, queryArgTypes}
