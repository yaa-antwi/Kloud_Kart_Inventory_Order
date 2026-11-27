# ADR-003: The order and stock functions write the stock history

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Data Engineering Consultant

## Context

Nana wants a record of every stock movement (sale, restock, correction) that an auditor could walk through. Today's history has gaps: 262,088 old sale rows are not linked to any order, and 144 products have a stock count that disagrees with their history. Nobody can say which side is right without counting the shelves.

## Decision

Three functions (place an order, restock, correct the count) each write their own history row in the same step as the stock change. A new sale row carries the order number, so an auditor can walk from a movement to its order. A correction must come with a written reason. A guard trigger rejects direct stock edits unless one of the three functions authorizes its own update. The trigger does not create a second, generic history row. Old history rows are left as they are and counted in a check, because rewriting them would be guessing.

## Alternatives considered

### Alternative A: A trigger that writes a row for every change

- **How it would work:** The database writes a generic row whenever the stock number changes, however it changed.
- **Why it is attractive:** It catches a number typed in by hand and cannot be forgotten.
- **Why rejected:** The approved functions already write rows with the reason and (for sales) order number. A second logging trigger would duplicate those rows or lose that context. The guard trigger is smaller and rejects the untracked path instead.

### Alternative B: Remove the right to edit stock directly

- **How it would work:** Staff can only use the three functions.
- **Why it is attractive:** It closes the gap at the source.
- **Why rejected:** It needs access to Kloud Kart's accounts and website, which I have not seen. It goes in the memo as a recommendation.

## Consequences

- **What this buys:** A simple design that passed the race test's audit check (5 sold, 5 movements recorded) in all three runs. On your machine, restock and correction both worked, and a correction with no reason was refused.
- **What this costs:** Any application that changes stock directly must be updated to call the three functions. A database superuser can bypass the guard; it is an operational safeguard, not a security boundary.
- **What it costs the client if I am wrong:** An unexpected caller will receive a permission error instead of silently changing stock.
- **What would make me revisit this:** A legitimate stock workflow cannot use the three functions; extend the approved API rather than bypassing the guard.
- **Who decides:** Nana, with whoever looks after the website (they know what else changes stock).

## What this survives

Each sale writes its history row in the same step as the stock change, so under the 400-buyer sale a sale cannot be recorded without its history or the other way round. A direct stock edit is rejected before it can create an untracked change.