{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}

module Main
  ( main
  ) where

import           Control.Monad.IO.Class         (liftIO)
import           Data.ByteString.Lazy           (ByteString)
import           Data.Functor.Identity          (Identity (..))
import           Data.Morpheus                  (Interpreter (..))
import           Data.Morpheus.Client           (Fetch (..), defineByDocumentFile, defineByIntrospectionFile, gql)
import           Data.Morpheus.Document         (toGraphQLDocument)
import           Data.Morpheus.Server           (GQLState, gqlSocketApp, initGQLState)
import           Data.Morpheus.Types            (ScalarValue (..))
import           Deprecated.API                 (Channel, Content, gqlRoot)
import           Mythology.API                  (mythologyApi)
import qualified Network.Wai                    as Wai
import qualified Network.Wai.Handler.Warp       as Warp
import qualified Network.Wai.Handler.WebSockets as WaiWs
import           Network.WebSockets             (defaultConnectionOptions)
import           TH.API                         (thApi)
import           Web.Scotty                     (body, file, get, post, raw, scottyApp)

ioRes :: ByteString -> IO ByteString
ioRes req = do
  print req
  return
    "{\"data\":{\"deity\":{ \"fullName\": \"name\" }, \"character\":{ \"__typename\":\"Human\", \"lifetime\": \"Lifetime\", \"profession\": \"Artist\" }  }}"

defineByIntrospectionFile
  "./assets/introspection.json"
  [gql|
    # Query Hero with Compile time Validation
    query GetUser ($userCoordinates: Coordinates!)
      {
        myUser: user {
           boo3: name
           email
           address (coordinates: $userCoordinates ){
            city
           }
        }
      }
  |]

defineByDocumentFile
  "./assets/simple.gql"
  [gql|
    # Query Hero with Compile time Validation
    query GetHero ($god: Realm, $charID: String!)
      {
        deity (mythology:$god) {
          power
          fullName
        }
        character(characterID: $charID ) {
          ...on Creature {
            creatureName
          }
          ...on Human {
            lifetime
            profession
          }
        }
      }
  |]

fetchHero :: IO (Either String GetHero)
fetchHero = fetch ioRes GetHeroArgs {god = Just Realm {owner = "Zeus", surface = Just 10}, charID = "Hercules"}

fetUser :: GQLState IO Channel Content -> IO (Either String GetUser)
fetUser state = fetch (interpreter gqlRoot state) userArgs
  where
    userArgs :: Args GetUser
    userArgs = GetUserArgs {userCoordinates = Coordinates {longitude = [], latitude = String "1"}}

main :: IO ()
main = do
  fetchHero >>= print
  state <- initGQLState
  httpApp <- httpServer state
  fetUser state >>= print
  Warp.runSettings settings $ WaiWs.websocketsOr defaultConnectionOptions (wsApp state) httpApp
  where
    settings = Warp.setPort 3000 Warp.defaultSettings
    wsApp = gqlSocketApp gqlRoot
    httpServer :: GQLState IO Channel Content -> IO Wai.Application
    httpServer state =
      scottyApp $ do
        post "/" $ raw =<< (liftIO . interpreter gqlRoot state =<< body)
        get "/" $ file "examples/index.html"
        get "/schema.gql" $ raw $ toGraphQLDocument $ Identity gqlRoot
        post "/mythology" $ raw =<< (liftIO . mythologyApi =<< body)
        get "/mythology" $ file "examples/index.html"
        post "/th" $ raw =<< (liftIO . thApi =<< body)
        get "/th" $ file "examples/index.html"
