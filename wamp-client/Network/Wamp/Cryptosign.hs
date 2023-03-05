module Network.Wamp.Cryptosign where

import qualified Data.ByteString.Base16 as BSB16
import qualified Data.ByteString as BS
import qualified Data.Text.Encoding as T
import qualified Data.Text as T
import qualified Data.Aeson.KeyMap   as KM
import qualified Crypto.Sign.Ed25519 as Ed
import           Network.Wamp.Messages
import           Network.Wamp.Types
import Data.Aeson
import Data.Aeson.Types
import Data.Maybe

processChallenge :: Ed.SecretKey -> Extra -> Either String Signature
processChallenge secretKey (Extra dict) =
  case KM.lookup "challenge" dict of
    Nothing -> Left "could not find challenge data"
    Just (String challengeHex) ->
      let echallenge = BSB16.decode $ T.encodeUtf8 challengeHex
      in case echallenge of
           Left e -> Left $ "could not base16-decode challenge data: "++e
           Right challenge ->
             let Ed.Signature res = Ed.dsign secretKey challenge
             in Right $ Signature $ T.decodeUtf8 $ BSB16.encode $ res <> challenge

computeAuthExtra :: T.Text -> Ed.SecretKey -> [Pair]
computeAuthExtra authId secretKey =
  let pubkey = toJSON $ T.decodeUtf8 $ BSB16.encode $ Ed.unPublicKey $ Ed.toPublicKey secretKey
  in ["authmethods" .= toJSON ["anonymous"::T.Text,"cryptosign"]
     ,"authid" .= toJSON authId
     ,"authextra" .= object
      ["pubkey" .= pubkey]
     ]

extractSecretKey :: T.Text -> Either String Ed.SecretKey
extractSecretKey secretKey =
  let ekey = BSB16.decode $ T.encodeUtf8 secretKey
      badformat = Left "could not interpret format of cryptosign secret key"
  in case ekey of
     Left _ -> badformat
     Right key ->
       case BS.length key of
         64 -> Right $ Ed.SecretKey key
         32 -> case Ed.createKeypairFromSeed_ key of
                 Nothing -> Left "failed to create secret key from given data"
                 Just sk -> Right $ snd sk
         _ -> badformat
