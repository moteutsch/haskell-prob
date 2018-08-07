# Usage

## Calculating probability of event:

    $ ghci -i Prob.hs

    > let omega = crossSeq $ replicate 9 coinflip
    > pPred omega ((>4) . length . filter (==True))
    >>> 1 % 2

## Sampling events:

    $ ghci -i Prob.hs

    > let numberDistrib = fmap (\x -> x * x `mod` 5) $ uniformOnSample [1..10]
    > let omega = uniformOnSample ["Type 1", "Type 2"] `cross` numberDistrib
    > event <- randomEvent omega
    > putStrLn $ show event
    >>> ("Type 2", 4)
