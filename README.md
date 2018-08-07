# Usage

## Calculating probability of event:

We calculate the probabilility of getting more than four (4) "heads" out of nine (9) coin-flips. We do this by letting `omega` be the product space (in mathematical symbols)

    {True, False}^9

and then applying `pPred` to find the probability of predicate occuring in a distribution.

    $ ghci -i Prob.hs

    > let omega = crossSeq $ replicate 9 coinflip
    > pPred omega ((>4) . length . filter (==True))
    >>> 1 % 2

## Sampling events:

Here we create a distribution `omega` and sample a random event from the distribution (in the `IO` monad).

    $ ghci -i Prob.hs

    > let numberDistrib = fmap (\x -> x * x `mod` 5) $ uniformOnSample [1..10]
    > let omega = uniformOnSample ["Type 1", "Type 2"] `cross` numberDistrib
    > event <- randomEvent omega
    > putStrLn $ show event
    >>> ("Type 2", 4)
