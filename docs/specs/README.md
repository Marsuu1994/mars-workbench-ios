# Specs

One spec per screen: what the app does, written as flows a person can follow. A spec says what the app does now; why it was built that way lives in the spike it came from, and how lives in the code.

This file is the one home of the rules for writing a spec.

## Shape

A spec starts with one paragraph saying what the screen is for, then:

- **Copy**: every user-facing string the screen shows, so a wording change is a spec change.
- **Flows**: one `##` section per flow, each with:
  - **Trigger**: what the user does, or what happens, that starts it;
  - **Steps**: numbered, in the order they happen, each a whole sentence saying who does what;
  - **Rules**: what always holds, and the edge cases.
- **Not in this version**: what someone might expect and the app doesn't do, so its absence reads as a decision.

## Writing it

- **Whole sentences**, as AGENTS.md › Documentation Style says: say who does what and when; give a term its meaning the first time it appears.
- **What the user sees and what the phone keeps**, not which type does it. A type or file name appears only where it is the clearest way to point at something (the outbox's folders).
- **A rule that comes from the server names it**: the entry's length is mars-workbench's `DUMP_ENTRY_MAX_LENGTH`, the batch limit its `DUMP_BATCH_LIMIT`.
- **Tests don't name spec items yet.** The specs are flows without IDs; `DumpCore`'s tests are named after what they prove. If the specs grow IDs later, they follow mars-workbench's spec v2 (its `design/specs/README.md`).
- **A new or changed behaviour updates the spec in the same PR** (AGENTS.md › Version Control).
