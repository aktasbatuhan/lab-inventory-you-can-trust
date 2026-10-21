# Principles

These are the rules the whole design follows. When two good ideas conflict, the one higher on this list wins.

## 1. Every value can be computed

The system stores two things only: facts (something happened, at a time, recorded by someone) and rules (how long a buffer lasts in the fridge, how much liquid a tube traps at the bottom). Every number anyone sees, whether that's how much is left, how much is usable, where a plate is, when something expires, how many times a tube was thawed, or what was wasted, is worked out from those facts and rules when someone asks.

So nobody types "200 µL left" into a field. They record "took 50 µL out", and the 200 is the sum. Nobody types an expiry date either. The system knows when the buffer was made, where it has been kept, and what the rule for that place is, and it works the date out.

This has three consequences we rely on everywhere:
- Every number can show how it was worked out. "Why does this say 140 µL?" always has an answer made of individual facts.
- Fixing a fact or a rule fixes every number that depends on it, with nothing to update by hand.
- When a number truly can't be worked out (we never measured the concentration, say), the answer is "unknown, because...", never a guess and never zero.

## 2. Facts are never edited or deleted

A mistake is fixed by recording a correction that points at the wrong fact. The wrong fact stays, marked as corrected. That's how we can answer "what did the record say before?" and "what did we believe last Tuesday?".

Every fact carries two times: when it happened in the lab, and when it was written into the system. They are often different, and both matter.

## 3. Assume the expected thing happened, make the exception loud

Where a protocol says what normally happens (a BLI plate is thrown away after its run, a robot transfers what its worklist says), the system records that as the default. Anyone who does something different has to say so. This means the common case needs no extra work, and an exception can't slip by quietly. Not reporting it leaves a visible mismatch that someone will have to explain.

Defaults are recorded as facts of their own, marked as coming from a rule, so they can be corrected like anything else.

## 4. Record first, flag after

The lab doesn't stop because the inventory disagrees with it. If someone takes more than the system thinks a tube holds, the liquid has already moved. Refusing to record it would just make the records wrong in a different way. So we record what happened, flag the mismatch, and keep anything flagged out of the "usable" numbers until a person sorts it out.

## 5. Know the difference between "exists" and "usable"

Something can be in the freezer and still be no good: expired, failed QC, on hold, stuck below what a pipette can reach, or with a question mark over it. "Usable" is always worked out, and it always comes with the list of reasons when the answer is no.
