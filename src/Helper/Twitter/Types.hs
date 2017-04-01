module Helper.Twitter.Types
    ( Endpoint(..)
    , Credentials(..)
    ) where

import ClassyPrelude.Yesod
import Data.Aeson
    ( FromJSON
    , withObject
    )

data Endpoint = Endpoint
    { endpointPath :: String
    , endpointMethod :: Method
    , endpointBody :: SimpleQuery
    }

data Credentials = Credentials
    { twitterConsumerKey :: Text
    , twitterConsumerSecret :: Text
    , twitterAccessToken :: Text
    , twitterAccessTokenSecret :: Text
    } deriving (Eq, Show)

instance FromJSON Credentials where
    parseJSON = withObject "twitter" $ \o -> do
        twitterConsumerKey <- o .: "consumer-key"
        twitterConsumerSecret <- o .: "consumer-secret"
        twitterAccessToken <- o .: "access-token"
        twitterAccessTokenSecret <- o .: "access-token-secret"

        return Credentials {..}
