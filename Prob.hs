module Prob
( Prob
, ProbDist
, getProbs
, pushForward
, uniformOnSample
, uniform
, randomEvent
, cross
, crossSeq
, p
, ps
, pPred
) where

-- TODO: Maybe converting all internal representations to use Data.Map we can simplify some code
-- TODO: and avoid need for (Ord a) type constraint
--
-- USAGE:
--
-- > let omega = crossSeq $ replicate 9 coinflip
-- > pPred omega ((>4) . length . filter (==True))
-- >>> 1 % 2

--import Data.Ratio
--
import System.Random
import Data.List (sort, sortBy, groupBy, elemIndex)
import Data.Maybe (fromJust, fromMaybe)

-- Internal helper method for debug strings
debug :: String -> IO ()
--debug str = putStrLn $ "[Debug: \"" ++ str ++ "\"]"
debug str = return ()

-- Represents a probability of an event occouring
type Prob = Rational

-- Represents a discrete probability distribution
data ProbDist a = ProbDist [(a, Prob)] deriving (Ord, Show, Eq)

-- This returns the "push-forward" probability distribution generated by a discrete random variable "x"
pushForward :: (a -> b) -> ProbDist a -> ProbDist b
pushForward x (ProbDist ys) = ProbDist . fmap (\(z, p) -> (x z, p)) $ ys

instance Functor ProbDist where
    fmap = pushForward

-- This returns the "internal list" of the probabilities, but also "regroups" the probabilities. So if there are duplicates (x, n), (x, k) pairs in the list, it merges them to (x, n + k)
getProbs :: (Eq a, Ord a) => ProbDist a -> [(a, Prob)]
getProbs (ProbDist xs) = regroup 0 (+) xs

-- See: "regroup" and "getProbs"
regroupProbs :: (Ord a, Eq a) => ProbDist a -> ProbDist a
regroupProbs = ProbDist . getProbs

-- Given a "folding" operation (an identity, and a associative, binary operation -- like for a monoid)
-- and a list of [(a, b)], will ensure that "a"s are unique: if there is a duplicate, it will "merge" them
-- by applying the monoid operation
regroup :: (Eq a, Ord a) => b -> (b -> b -> b) -> [(a, b)] -> [(a, b)]
regroup s f xs = fmap myFold . groupBy (\x y -> (fst x) == fst y) . sortBy (\x y -> fst x `compare` fst y) $ xs
    where myFold xs = foldl (\x y -> (fst x, f (snd x) (snd y))) (fst . head $ xs, s) xs

-- TODO: Make this a Monad that behaves the same way as the List monad, but with probabilities also

uniformOnSample :: [a] -> ProbDist a
uniformOnSample xs = ProbDist [(x, 1 / (toRational $ length xs)) | x <- xs]

uniform :: Int -> ProbDist Int
uniform n = uniformOnSample [1..n]

-- Uniform on sample defined as push-forward of "Int" uniform distribution
uniformOnSample' :: (Ord a) => [a] -> ProbDist a
uniformOnSample' xs = pushForward (\i -> xs !! (i - 1)) $ uniform $ length xs

bernoulli :: Prob -> ProbDist Bool
bernoulli p = ProbDist $ [(True, p), (False, 1 - p)]

ber = bernoulli

coinflip = ber (1/2)

flattenDist :: (Ord a) => ProbDist (ProbDist a) -> ProbDist a
flattenDist dist = ProbDist $ [ (x, prob1 * prob2) | (currDist, prob1) <- distPairs, (x, prob2) <- (getProbs currDist) ]
    where distPairs = getProbs dist

-- NOTE: Because of the type constraint (Ord a) which we need essentially everywhere for ProbDist,
-- NOTE: we cannot make our type an Applicative and Monad. This same problem occours in Data.Set, so
-- NOTE: it is a well-known problem.

--instance Applicative ProbDist where
    --pure x = uniformOnSample [x]
    --fsDist <*> dists = flattenDist $ fmap (fmap ($ dists)) fsDist

--instance Monad ProbDist where
    --return = pure
    --f >>= dist = flattenDist $ fmap f dist

isInHalfOpenInterval :: (Ord a) => a -> (a, a) -> Bool
isInHalfOpenInterval z (x, y) = x <= z && z < y

-- Sample random event from distribution.
randomEvent :: (Ord a) => ProbDist a -> IO a
randomEvent dist = do
    -- We first "regroup" the probabilities.
    let ProbDist(xs) = regroupProbs dist
    num <- randomRIO (0, 1) :: IO Double
    -- We select an element from distribution using "Roulette wheel method" or "Fitnes porpotional selectoin".
    -- See: http://growingthemoneytree.com/roulette-wheel-selection/
    -- See: https://en.wikipedia.org/wiki/Fitness_proportionate_selection
    let b = scanl (+) 0 (fmap snd xs)
    --putStrLn (show b)
    debug ("Number is " ++ show num)
    let intervals = zip (init b) (tail b)
    -- putStrLn (show intervals)
    let interval = fromJust $ True `elemIndex` (fmap (isInHalfOpenInterval (toRational $ num)) intervals)
    let res = (fst $ xs !! interval)
    return res


--instance Monad ProbDist where
    --return x = uniformOnSample [x]
    --dist >>= f = (flattenDist . fmap f) dist


-- Return the probability of an element of distribution
p :: (Ord a) => ProbDist a -> a -> Prob
p dist x = fromMaybe 0 $ lookup x pairs
    where pairs = (getProbs . regroupProbs) dist

-- Return the probability of an event A (where \( A \subset 2^{\Omega} \) )
ps :: (Ord a) => ProbDist a -> [a] -> Prob
ps dist xs = sum . (fmap (p dist)) $ xs

-- Return the probability of the event defined by the predicate p
pPred :: (Ord a) => ProbDist a -> (a -> Bool) -> Prob
pPred dist p = (ps dist) $ (filter p . fmap fst . getProbs $ dist)

-- Cross product of two
cross :: (Ord a, Ord b) => ProbDist a -> ProbDist b -> ProbDist (a, b)
cross aProb bProb = ProbDist $ [ ((x, y), aProb * bProb) | (x, aProb) <- aProbs, (y, bProb) <- bProbs ]
    where aProbs = getProbs aProb
          bProbs = getProbs bProb

-- Cross product of sequence of same type
crossSeq :: (Ord a) => [ProbDist a] -> ProbDist [a]
crossSeq (prob:[]) = fmap (:[]) prob
crossSeq (prob:probs) = ProbDist $ [ ((x : xs), aProb * bProb) | (x, aProb) <- first, (xs, bProb) <- rest ]
    where first = getProbs prob
          rest = getProbs (crossSeq probs)
crossSeq _ = error "Distributions to cross product must not be empty"
