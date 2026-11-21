# Spikes

Point-in-time proposals for open questions. A complex task — several PRs, a new screen, a change to what is stored on the phone or sent to the server, or a choice with real tradeoffs — or a design or tooling question with no owner decision yet starts here, not with code. Spikes are not living docs: once decided they are frozen, and once implemented they move to `archived/`.

These rules are mars-workbench's (its `design/spike/README.md`), kept the same so a spike reads the same in both repositories. A spike about a change the server needs too is written in mars-workbench, which owns the API, and its iOS part is copied here, as `v1-dump-capture.md` was.

## Lifecycle

1. **Spike** — write a self-contained doc here, headed `Status: awaiting owner review` and linked from the tracker item it answers. An exploration parked until its work is picked up is headed `Status: draft` instead; it moves to awaiting owner review when that work starts.
2. **Review** — go back and forth with the owner on the spike's PR, editing the spike in place each round.
3. **Decided** — once every open question is answered, record the answers in a Decision section and mark `Status: decided`. From here the spike is frozen; later decisions land in the tracker and the PRs that make them.
4. **Implement** — build what it decided, and update the living docs (the specs, README › Current State) so they stand on their own without the spike.
5. **Archive** — in the PR that finishes step 4, `git mv` the spike to `archived/` and fix every link to it.

## Shape

- **Self-contained**: the trigger (what prompted it), options with honest pros and cons, and a concrete implementation plan per option. Number the open questions so the owner can answer them one by one, and mark the recommended answer.
- **Written in Chinese with English terms.** The narrative is Chinese; product nouns, states, code identifiers and Apple's API names stay in English (entry, outbox, `Outbox`, `URLSession`, `@FocusState`), so every term matches the code and the specs one-to-one. Say so in a one-line language note under the header. Bad: "发件箱在后台重试" (translated terms). Good: "`Outbox` 在后台重试".
- **Facts that move are dated**: a price, an Apple or GitHub limit, a version is written as of the spike's date, with where to check it.
