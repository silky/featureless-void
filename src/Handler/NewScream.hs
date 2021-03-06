module Handler.NewScream
    ( getNewScreamR
    , postNewScreamR
    ) where

import Import
import Markdown
import qualified Helper.S3 as S3

import qualified Helper.Twitter as Twitter
import Helper.Twitter.Types (Tweet(..))

data ScreamFields = ScreamFields
    { bodyField :: Markdown
    , imageField :: Maybe FileInfo
    , twitterCrosspostField :: Bool
    }

getNewScreamR :: Handler Html
getNewScreamR = do
    (form, enctype) <- generateFormPost screamForm
    renderNewScream form enctype

postNewScreamR :: Handler Html
postNewScreamR = do
    ((res, form), enctype) <- runFormPost screamForm
    case res of
      FormSuccess fields -> do
          tid <- twitterCrosspostIfNecessary fields
          scream <- parseScream fields tid
          sid <- runDB $ insert scream
          images <- parseImages fields sid
          void $ runDB $ insertMany images
          redirect HomeR
      _ -> renderNewScream form enctype

twitterCrosspostIfNecessary :: ScreamFields -> Handler (Maybe Text)
twitterCrosspostIfNecessary fields
    | twitterCrosspostField fields = do
        images <- mapM Twitter.uploadImage $ maybeToList $ imageField fields
        let status = strippedText . bodyField $ fields
        tweet <- Twitter.postTweet status images
        return $ Just $ tweetId tweet
    | otherwise = return Nothing

parseImages :: ScreamFields -> ScreamId -> Handler [Image]
parseImages f sid = do
    images <- S3.uploadItems $ map createUpload $ maybeToList $ imageField f
    return $ fmap createImage images
  where
    createImage (desc, url) = Image sid (S3.uploadFileName desc) url

parseScream :: ScreamFields -> Maybe Text -> Handler Scream
parseScream f tid = do
    now <- liftIO getCurrentTime
    return Scream
        { screamBody = bodyField f
        , screamCreatedAt = now
        , screamTweetId = tid
        }

screamForm :: Form ScreamFields
screamForm = renderDivs $
    ScreamFields
        <$> areq markdownField ("Body" { fsId = Just "scream-body" }) Nothing
        <*> fileAFormOpt "Image"
        <*> areq checkBoxField "Crosspost to Twitter" (Just True)

renderNewScream :: Widget -> Enctype -> Handler Html
renderNewScream form enctype = defaultLayout $ do
    setTitle "New Scream"
    addScript $ StaticR js_markdown_min_js
    addScript $ StaticR js_char_count_js
    $(widgetFile "screams/new")

createUpload :: FileInfo -> S3.Upload
createUpload info = S3.Upload
    { uploadSource = (fileSource info)
    , uploadContentType = (fileContentType info)
    , uploadFileName = (fileName info)
    }
