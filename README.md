twitterlanes
============

Split your twitter feed into fast, medium and slow lists. Fast posters go in the fast list. Slow posters go in the slow list. etc.

Currently uses an exponential curve so that speed lane 3 should be about 5x slower than speed lane 1. Try out your own preferences!

Instructions:
1. Get your [twitter ID](https://tweeterid.com)
2. Get a twitter [developer account](https://developer.twitter.com/en/apply-for-access) (may take some time)
3. Get [Julia](https://julialang.org)
4. Clone this repo
5. Put in all your keys and tokens etc at the start of src/twitterlanes.jl
6. Check over the script to reassure yourself I'm not doing anything untoward with those keys and tokens
7. Run

        julia --project=.
        using twitterlanes
        twitterlanes.go()

Try to figure out any changes you might want to make before you run the script as if you redo it too many times you'll get rate-limited.
