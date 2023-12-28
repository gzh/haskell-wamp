{-# LANGUAGE FunctionalDependencies  #-}
{-# LANGUAGE TypeFamilies            #-}
{-# LANGUAGE UndecidableSuperClasses #-}

-- |
-- Module      : Network.Wamp.State
-- Description : Client state
-- Copyright   : (c) Maciej Kazulak, 2015
-- License     : MIT
-- Maintainer  : kazulakm@gmail.com
-- Stability   : experimental
-- Portability : portable
--
module Network.Wamp.State
  ( Subscription (..)
  , SubscriptionStore
  , Handler
  , Result

  , Registration(..)
  , RegistrationStore
  , Endpoint
  , CallResult

  , Store (..)
  , TicketStore(..)
  , Storeable (..)
  , HasPromise(..)
  , PublishRequest (..)
  , PublishRequestStore
  , SubscribeRequest (..)
  , SubscribeRequestStore
  , UnsubscribeRequest (..)
  , UnsubscribeRequestStore
  , CallRequest (..)
  , CallRequestStore
  , RegisterRequest (..)
  , RegisterRequestStore
  , UnregisterRequest (..)
  , UnregisterRequestStore

  , mkSubscriptionStore
  , insertSubscription
  , lookupSubscription
  , lookupSubscriptionByTopicUri
  , deleteSubscription
  , countSubscription

  , mkRegistrationStore
  , insertRegistration
  , lookupRegistration
  , lookupRegistrationByProcedureUri
  , deleteRegistration
  , countRegistration

  )
where

import           Control.Concurrent.MVar
import           Control.Exception        (SomeException (..))
import           Data.IxSet.Typed         hiding (insert)
import qualified Data.IxSet.Typed         as Ix (insert)
import           Data.Typeable

import Network.Wamp.Types

-- | Promise for a result
type Result a = MVar (Either SomeException a)

-- | Event handler
type Handler = Arguments -> ArgumentsKw -> Details -> IO ()


type SubscriptionIxs = '[SubId, TopicUri]

-- | Topic subscription as seen by a @Subscriber@
--
-- @Subscriber@ stores one subscription for each successful @Subscribed@ message.
data Subscription = Subscription
  { subscriptionId       :: SubId
  , subscriptionTopicUri :: TopicUri
  , subscriptionHandler  :: Handler
  , subscriptionOptions  :: Options
  }
  deriving (Typeable)

instance Eq Subscription where
  x == y = (subscriptionId x) == (subscriptionId y)

instance Ord Subscription where
  compare x y = compare (subscriptionId x) (subscriptionId y)

instance Show Subscription where
  show (Subscription subId topicUri _ _) = "Subscription " ++ show subId ++ " " ++ show topicUri

instance Indexable SubscriptionIxs Subscription where
  indices =
    ixList
      (ixFun $ \s -> [subscriptionId s])
      (ixFun $ \s -> [subscriptionTopicUri s])


-- | Current subscriptions known to a @Subscriber@
type SubscriptionStore = TicketStore SubscriptionIxs Subscription

instance TicketClass SubscriptionIxs Subscription where
  type TicketId Subscription = SubId
  type TicketUri Subscription = TopicUri

-- | Create a new 'SubscriptionStore'
mkSubscriptionStore :: IO SubscriptionStore
mkSubscriptionStore = mkTicketStore

-- | Insert a 'Subscription' into a 'SubscriptionStore'
insertSubscription :: SubscriptionStore -> Subscription -> IO ()
insertSubscription = insertTicket

-- | Lookup a  'Subscription' by 'Network.Wamp.Types.SubId'
lookupSubscription :: SubscriptionStore -> SubId -> IO (Maybe Subscription)
lookupSubscription = lookupTicket

-- | Lookup a  'Subscription' by 'Network.Wamp.Types.TopicUri'
lookupSubscriptionByTopicUri :: SubscriptionStore -> TopicUri -> IO [Subscription]
lookupSubscriptionByTopicUri = lookupTicketByUri

-- | Delete a  'Subscription' by 'Network.Wamp.Types.SubId'
deleteSubscription :: SubscriptionStore -> SubId -> IO ()
deleteSubscription = deleteTicket

-- | Return current registration count
countSubscription :: SubscriptionStore -> IO Int
countSubscription = countTicket


newtype Store ixs a = Store (MVar (IxSet ixs a))

class (Eq s, Ord s, Indexable ixs s, Typeable s) => Storeable ixs s where
  mkStore :: IO (Store ixs s)
  mkStore = do
    m <- newMVar empty
    return $ Store m

  insert :: Store ixs s -> s -> IO ()
  insert (Store m) s = do
    store <- takeMVar m
    putMVar m $ Ix.insert s store

  lookup :: IsIndexOf ReqId ixs => Store ixs s -> ReqId -> IO (Maybe s)
  lookup (Store m) reqId = do
    store <- readMVar m
    return $ getOne $ store @= reqId

  delete :: IsIndexOf ReqId ixs => Store ixs s -> ReqId -> IO ()
  delete (Store m) reqId = do
    store <- takeMVar m
    putMVar m $! deleteIx reqId store

  extract :: IsIndexOf ReqId ixs => Store ixs s -> ReqId -> IO (Maybe s)
  extract (Store m) reqId = do
    store <- takeMVar m
    putMVar m $! deleteIx reqId store
    return $ getOne $ store @= reqId

  count :: Store ixs s -> IO Int
  count (Store m) = do
    store <- readMVar m
    return $ size store


class HasPromise a b | a -> b where
  getPromise :: a -> Result b


type PublishRequestStore = Store PublishRequestIxs PublishRequest

type PublishRequestIxs = '[ReqId]

-- | Publish request
data PublishRequest = PublishRequest
  { publishPromise         :: Result PubId
  , publishRequestId       :: ReqId
  }
  deriving (Typeable)

instance Eq PublishRequest where
  x == y = (publishRequestId x) == (publishRequestId y)

instance Ord PublishRequest where
  compare x y = compare (publishRequestId x) (publishRequestId y)

instance Show PublishRequest where
  show p = "PublishRequest " ++ show (publishRequestId p)

instance Indexable PublishRequestIxs PublishRequest where
  indices =
    ixList
      (ixFun $ \s -> [publishRequestId s])

instance Storeable PublishRequestIxs PublishRequest

instance HasPromise PublishRequest PubId where
  getPromise = publishPromise


type SubscribeRequestStore = Store SubscribeRequestIxs SubscribeRequest

type SubscribeRequestIxs = '[ReqId]

-- | Subscribe request
data SubscribeRequest = SubscribeRequest
  { subscribePromise         :: Result Subscription
  , subscribeRequestId       :: ReqId
  , subscribeRequestTopicUri :: TopicUri
  , subscribeRequestHandler  :: Handler
  , subscribeRequestOptions  :: Options
  }
  deriving (Typeable)

instance Eq SubscribeRequest where
  x == y = (subscribeRequestId x) == (subscribeRequestId y)

instance Ord SubscribeRequest where
  compare x y = compare (subscribeRequestId x) (subscribeRequestId y)

instance Show SubscribeRequest where
  show s = "SubscribeRequest " ++ show (subscribeRequestId s)

instance Indexable SubscribeRequestIxs SubscribeRequest where
  indices =
    ixList
      (ixFun $ \s -> [subscribeRequestId s])

instance Storeable SubscribeRequestIxs SubscribeRequest

instance HasPromise SubscribeRequest Subscription where
  getPromise = subscribePromise


type UnsubscribeRequestStore = Store UnsubscribeRequestIxs UnsubscribeRequest

type UnsubscribeRequestIxs = '[ReqId]

-- | Unsubscribe request
data UnsubscribeRequest = UnsubscribeRequest
  { unsubscribePromise         :: Result Bool
  , unsubscribeRequestId       :: ReqId
  , unsubscribeRequestSubId    :: SubId
  }
  deriving (Typeable)

instance Eq UnsubscribeRequest where
  x == y = (unsubscribeRequestId x) == (unsubscribeRequestId y)

instance Ord UnsubscribeRequest where
  compare x y = compare (unsubscribeRequestId x) (unsubscribeRequestId y)

instance Show UnsubscribeRequest where
  show usub = "UnsubscribeRequest " ++ show (unsubscribeRequestId usub)

instance Indexable UnsubscribeRequestIxs UnsubscribeRequest where
  indices =
    ixList
      (ixFun $ \s -> [unsubscribeRequestId s])

instance Storeable UnsubscribeRequestIxs UnsubscribeRequest

instance HasPromise UnsubscribeRequest Bool where
  getPromise = unsubscribePromise


type CallRequestStore = Store CallRequestIxs CallRequest

type CallRequestIxs = '[ReqId]

-- | Call request
data CallRequest = CallRequest
  { callPromise         :: Result CallResult,
    callRequestId       :: ReqId
  }
  deriving (Typeable)

instance Eq CallRequest where
  x == y = (callRequestId x) == (callRequestId y)

instance Ord CallRequest where
  compare x y = compare (callRequestId x) (callRequestId y)

instance Show CallRequest where
  show r = "CallRequest " ++ (show $ callRequestId r)

instance Indexable CallRequestIxs CallRequest where
  indices =
    ixList
      (ixFun $ \s -> [callRequestId s])

instance Storeable CallRequestIxs CallRequest

instance HasPromise CallRequest CallResult where
  getPromise = callPromise


type RegisterRequestStore = Store RegisterRequestIxs RegisterRequest

type RegisterRequestIxs = '[ReqId]

-- | Register request
data RegisterRequest = RegisterRequest
  { registerPromise         :: Result Registration
  , registerRequestId       :: ReqId
  , registerRequestProcUri  :: ProcedureUri
  , registerRequestEndpoint :: Endpoint
  , registerRequestHandleAsync :: Bool
  , registerRequestOptions  :: Options
  }
  deriving (Typeable)

instance Eq RegisterRequest where
  x == y = (registerRequestId x) == (registerRequestId y)

instance Ord RegisterRequest where
  compare x y = compare (registerRequestId x) (registerRequestId y)

instance Show RegisterRequest where
  show r = "RegisterRequest " ++ (show $ registerRequestId r)

instance Indexable RegisterRequestIxs RegisterRequest where
  indices =
    ixList
      (ixFun $ \s -> [registerRequestId s])

instance Storeable RegisterRequestIxs RegisterRequest

instance HasPromise RegisterRequest Registration where
  getPromise = registerPromise


type UnregisterRequestStore = Store UnregisterRequestIxs UnregisterRequest

type UnregisterRequestIxs = '[ReqId]

-- | Unregister request
data UnregisterRequest = UnregisterRequest
  { unregisterPromise         :: Result Bool
  , unregisterRequestId       :: ReqId
  , unregisterRequestSubId    :: RegId
  }
  deriving (Typeable)

instance Eq UnregisterRequest where
  x == y = (unregisterRequestId x) == (unregisterRequestId y)

instance Ord UnregisterRequest where
  compare x y = compare (unregisterRequestId x) (unregisterRequestId y)

instance Show UnregisterRequest where
  show x = "UnregisterRequest " ++ (show $ unregisterRequestId x)

instance Indexable UnregisterRequestIxs UnregisterRequest where
  indices =
    ixList
      (ixFun $ \s -> [unregisterRequestId s])

instance Storeable UnregisterRequestIxs UnregisterRequest

instance HasPromise UnregisterRequest Bool where
  getPromise = unregisterPromise

type CallResult   = (Arguments, ArgumentsKw)
type Endpoint     = Arguments -> ArgumentsKw -> Details -> IO CallResult


type RegistrationIxs = '[RegId, ProcedureUri]

data Registration = Registration
  { registrationId            :: RegId
  , registrationProcedureUri  :: ProcedureUri
  , registrationEndpoint      :: Endpoint
  , registrationHandleAsync   :: Bool
  , registrationOptions       :: Options
  }
  deriving (Typeable)

instance Eq Registration where
  x == y = (registrationId x) == (registrationId y)

instance Ord Registration where
  compare x y = compare (registrationId x) (registrationId y)

instance Show Registration where
  show r = mconcat ["Registration "
                   ,show $ registrationId r
                   ," "
                   ,show $ registrationProcedureUri r]

instance Indexable RegistrationIxs Registration where
  indices =
    ixList
      (ixFun $ \s -> [registrationId s])
      (ixFun $ \s -> [registrationProcedureUri s])

type RegistrationStore = TicketStore RegistrationIxs Registration

instance TicketClass RegistrationIxs Registration where
  type TicketId Registration = RegId
  type TicketUri Registration = ProcedureUri

-- | Create a new 'RegistrationStore'
mkRegistrationStore :: IO RegistrationStore
mkRegistrationStore = mkTicketStore

-- | Insert a 'Registration' into a 'RegistrationStore'
insertRegistration :: RegistrationStore -> Registration -> IO ()
insertRegistration = insertTicket

-- | Lookup a  'Registration' by 'Network.Wamp.Types.RegId'
lookupRegistration :: RegistrationStore -> RegId -> IO (Maybe Registration)
lookupRegistration = lookupTicket

-- | Lookup a  'Registration' by 'Network.Wamp.Types.ProcedureUri'
lookupRegistrationByProcedureUri :: RegistrationStore -> ProcedureUri -> IO [Registration]
lookupRegistrationByProcedureUri = lookupTicketByUri

-- | Delete a  'Registration' by 'Network.Wamp.Types.RegId'
deleteRegistration :: RegistrationStore -> RegId -> IO ()
deleteRegistration = deleteTicket

-- | Return current registration count
countRegistration :: RegistrationStore -> IO Int
countRegistration = countTicket

-- common implementation for subscriptions and registrations:
-- we get a ticket from router. ticket has an id, and it also has an uri.

class (Eq a, Ord a, Indexable ixs a, Typeable a, Typeable (TicketId a), Typeable (TicketUri a)) =>
      TicketClass ixs a where
  type TicketId a
  type TicketUri a

newtype TicketStore ixs a = TicketStore (MVar (IxSet ixs a))

mkTicketStore :: (TicketClass ixs a) => IO (TicketStore ixs a)
mkTicketStore = do
  m <- newMVar empty
  return $ TicketStore m

-- | Insert a 'Ticket' into a 'TicketStore'
insertTicket :: (TicketClass ixs a) => TicketStore ixs a -> a -> IO ()
insertTicket (TicketStore m) reg = do
  store <- takeMVar m
  putMVar m $ Ix.insert reg store

-- | Lookup a  'Ticket' by 'Network.Wamp.Types.RegId'
lookupTicket
  :: (TicketClass ixs a, IsIndexOf (TicketId a) ixs)
  => TicketStore ixs a
  -> TicketId a
  -> IO (Maybe a)
lookupTicket (TicketStore m) regId = do
  store <- readMVar m
  return $ getOne $ store @= regId

-- | Lookup a  'Ticket' by 'Network.Wamp.Types.ProcedureUri'
lookupTicketByUri
  :: (TicketClass ixs a, IsIndexOf (TicketUri a) ixs)
  => TicketStore ixs a
  -> TicketUri a
  -> IO [a]
lookupTicketByUri (TicketStore m) uri = do
  store <- readMVar m
  return $ toList $ store @= uri

-- | Delete a  'Ticket' by 'Network.Wamp.Types.RegId'
deleteTicket
  :: (TicketClass ixs a, IsIndexOf (TicketId a) ixs)
  => TicketStore ixs a
  -> TicketId a
  -> IO ()
deleteTicket (TicketStore m) ticketId = do
  store <- takeMVar m
  putMVar m $ deleteIx ticketId store

-- | Return current registration count
countTicket :: (TicketClass ixs a) => TicketStore ixs a -> IO Int
countTicket (TicketStore m) = do
  store <- readMVar m
  return $ size store
