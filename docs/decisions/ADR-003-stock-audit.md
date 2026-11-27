# ADR-003: Automatically record every stock change

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Data Engineering Consultant

## Context

Nana wants a record of every stock movement (sale, restock, correction) that an auditor could walk through. Today's history has gaps: 262,088 old sale rows are not linked to any order, and 144 products have a stock count that disagrees with their history. Nobody can say which side is right without counting the shelves.

## Decision

An after-trigger writes one history row in the same transaction whenever a product is created with opening stock or its stock quantity changes. The three stock functions provide the reason, note and (for sales) order number; a direct update is recorded as `manual_update`. This avoids duplicate logging in the functions while ensuring direct SQL updates do not silently bypass the trail. Old history rows are left as they are and counted in a check, because rewriting them would be guessing.

## Alternatives considered

### Alternative A: Reject direct edits

- **How it would work:** The database refuses any direct change to `products.stock_quantity`.
- **Why it is attractive:** Every caller must use the functions.
- **Why rejected:** Logging the direct change preserves existing maintenance workflows and still records the quantity delta for later review.

### Alternative B: Remove the right to edit stock directly

- **How it would work:** Staff can only use the three functions.
- **Why it is attractive:** It closes the gap at the source.
- **Why rejected:** It needs access to Kloud Kart's accounts and website, which I have not seen. It goes in the memo as a recommendation.

## Consequences

- **What this buys:** Direct SQL changes are visible in the history. The functions still produce one detailed movement row each, including the sale's order number, without duplicate inserts.
- **What this costs:** Each stock change performs one history insert. Direct updates are recorded as `manual_update` and still need an authorized person to review their reason.
- **What it costs the client if I am wrong:** A direct stock change is recorded, but its business reason is not known automatically.
- **What would make me revisit this:** A legitimate direct update needs a structured reason; add a controlled function parameter rather than suppressing the audit row.
- **Who decides:** Nana, with whoever looks after the website (they know what else changes stock).

## What this survives

Each sale writes its history row in the same step as the stock change, so under the 400-buyer sale a sale cannot be recorded without its history or the other way round. A direct stock update also produces a history row in the same transaction.