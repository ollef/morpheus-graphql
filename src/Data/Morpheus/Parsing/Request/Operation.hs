{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Morpheus.Parsing.Request.Operation
  ( parseAnonymousQuery
  , parseOperation
  ) where

import           Data.Functor                               (($>))
import           Data.Text                                  (Text)
import           Text.Megaparsec                            (label, (<?>), (<|>))
import           Text.Megaparsec.Char                       (space1, string)

--
-- MORPHEUS
import           Data.Morpheus.Parsing.Internal.Internal    (Parser, getLocation)
import           Data.Morpheus.Parsing.Internal.Terms       (parseAssignment, parseMaybeTuple, parseNonNull,
                                                             parseWrappedType, token, variable)
import           Data.Morpheus.Parsing.Request.Body         (entries)
import           Data.Morpheus.Types.Internal.AST.Operation (Operation (..), OperationKind (..), RawOperation,
                                                             Variable (..))

operationArgument :: Parser (Text, Variable ())
operationArgument =
  label "operatorArgument" $ do
    ((name, variablePosition), (wrappers, variableType)) <- parseAssignment variable parseWrappedType
    nonNull <- parseNonNull
    pure
      ( name
      , Variable
          { variableType
          , isVariableRequired = 0 < length nonNull
          , variableTypeWrappers = nonNull ++ wrappers
          , variablePosition
          , variableValue = ()
          })

parseOperation :: Parser RawOperation
parseOperation =
  label "operator" $ do
    operationPosition <- getLocation
    operationKind <- parseOperationKind
    operationName <- token
    operationArgs <- parseMaybeTuple operationArgument
    operationSelection <- entries
    pure (Operation {operationName, operationKind, operationArgs, operationSelection, operationPosition})

parseAnonymousQuery :: Parser RawOperation
parseAnonymousQuery =
  label "AnonymousQuery" $ do
    operationPosition <- getLocation
    operationSelection <- entries
    pure
      (Operation
         { operationName = "AnonymousQuery"
         , operationKind = QUERY
         , operationArgs = []
         , operationSelection
         , operationPosition
         }) <?>
      "can't parse AnonymousQuery"

parseOperationKind :: Parser OperationKind
parseOperationKind =
  label "operatorKind" $ do
    kind <- (string "query" $> QUERY) <|> (string "mutation" $> MUTATION) <|> (string "subscription" $> SUBSCRIPTION)
    space1
    return kind
