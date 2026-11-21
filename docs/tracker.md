# Tracker

Open todos for the iOS app — open items only; completed work is in the git history and PR descriptions, not here.

## Conventions

- **One concise line per item; details go into sub-bullets.** An item says what is open and why, at product altitude — not an inventory of files.
- **Finished work leaves.** Delete an item when it lands; the PR that landed it records it.
- **A multi-PR project is one item with a sub-bullet per step**, the parent naming the goal and linking its spike.

## Dump

### High

- [ ] First install on the owner's iPhone — generate, sign with the free Apple ID, run, and check the spec's flows on the device: the keyboard up at launch, an entry dumped offline arriving once online, the hint (`docs/specs/capture.md`). The focus at launch is the part most likely to need a fix on a real phone (`docs/spike/v1-dump-capture.md` › 一些坑)

### Future

- [ ] Faster ways in: a Lock Screen or Control Center button and a Shortcuts action (App Intents) that open straight into the field, and a share extension that dumps shared text
- [ ] Background `URLSession` for sending — iOS delivers the upload even after the app is suspended; today an app swiped away sends only when opened again (`docs/spike/v1-dump-capture.md` › Q8, option B)
- [ ] TestFlight and automatic installs — needs the paid Apple Developer Program; then Xcode Cloud or GitHub Actions with fastlane uploads every merge (`docs/spike/v1-dump-capture.md` › CI/CD)

## Native Mars Workbench

### Future

- [ ] Sign-in instead of the fixed token — Supabase Google sign-in on the phone, and mars-workbench's native API verifying its access token, as `/api/mcp` does; a spike first, in mars-workbench (its tracker › Native iOS app)
