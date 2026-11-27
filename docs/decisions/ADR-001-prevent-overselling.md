# ADR-001: Prevent overselling by making buyers take turns

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Data Engineering Consultant

## Context

Two customers can look at the same product at the same moment, both see "1 left", and both buy it. That is what happened to Nana twice. The database allows this by default, because looking at a record does not stop anyone else from looking at it too. The brief also says a flash sale will bring about 400 orders in ten seconds on one product.

## Decision

The order function (one call that places the whole order) first reserves that one product's record, which the database calls a row lock. The next buyer waits until the first has finished, then sees the new stock count. If nothing is left, that buyer gets a clear "Out of stock" reply, not an error. In the same step the function lowers the stock, creates the order and its item, and writes the history row, so it is all done or none of it is done.

Four smaller choices go with it:

- **A function, not a procedure.** The test calls it inside a normal query and reads an answer back, which only a function allows.
- **A 5-second wait limit.** A buyer who cannot get the record within 5 seconds hears "Busy, please try again". Nothing has been written at that point, so trying again is safe.
- **The database numbers new records.** The order, item and history tables could not create their own numbers. They now do, starting after the highest number already used. This is a change to the table design.
- **No new negative stock.** A rule refuses any stock change that would go below zero. The 14 products already below zero are left alone until someone counts them, because only a physical count tells us the true figure.

## Alternatives considered

### Alternative A: Strict mode (the database refuses the second buyer with an error)

- **How it would work:** The database cancels the second buyer's purchase with an error, and the website tries again.
- **Why it is attractive:** Nobody waits.
- **Why rejected:** On a practice copy, the second buyer got an error, not "Out of stock". The race test counts any error as a failure, and a function cannot retry itself. That practice test was on an older database version (16), not on Nana's version.

### Alternative B: Skip a product record that is busy

- **How it would work:** A buyer who finds the record reserved moves on.
- **Why it is attractive:** Nobody waits.
- **Why rejected:** The buyer could be told the product is gone while stock remains.

### Alternative C: Highest number plus one for new records

- **How it would work:** The function looks up the biggest number and adds one.
- **Why it is attractive:** It passes the race test, because every test buyer is on one product.
- **Why rejected:** Two buyers on different products at the same moment would pick the same number and one would fail. The test cannot catch it, so it would pass the test and fail on a busy day.

### Alternative D: No wait limit, or 15 seconds

- **How it would work:** Wait as long as it takes, or up to 15 seconds.
- **Why it is attractive:** Nobody is turned away by the clock.
- **Why rejected:** One stuck piece of work would freeze every buyer of that product. Fifteen seconds is longer than the whole flash sale.

## Consequences

- **What this buys:** Exactly one buyer gets the last unit. On your machine, 25 of 25 two-buyer rounds had one winner, and the 400-buyer test sold exactly 50 of 50 units with 0 errors, in all three runs. Every refused buyer got "Out of stock". The 5-second limit was seen firing on your machine: "Busy, please try again" after 5.005 seconds, with nothing written.
- **What this costs:** Buyers of the same product queue. In the 400-buyer test everyone was answered in about 2.2 to 2.5 seconds and the longest single wait was 1.07 seconds. That is quick, but it is not instant for everyone. Two buyers racing for the last unit were answered in about 5 to 15 milliseconds. The numbering leaves harmless gaps.
- **What it costs the client if I am wrong:** On a slower server a buyer could hear "Busy" while stock remains (one number to change). If another system writes numbers by hand, they could clash; I have not seen the website or any other system.
- **What would make me revisit this:** "Busy" appearing in normal use, or a sale far bigger than the one in the brief. My practice copy handled about 440 to 530 orders per second on one product; the brief needs about 40. 
- **Who decides:** Nana, with whoever looks after the website and other systems (they would see "Busy" replies and any clashing numbers).

## What this survives

The flash sale in the brief: 400 buyers at the same moment on one product with 50 units gives exactly 50 sold and 350 told "Out of stock". It does not survive a stock number typed in by hand, because that skips the order function. The 5 seconds is my judgement, not a proven best.