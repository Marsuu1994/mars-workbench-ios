# Mars Workbench iOS Agent Guide

The shared rulebook every agent session loads (Claude Code imports it through `CLAUDE.md`; Codex reads it directly). It holds the rules every task needs, plus an index of where the rest live (Workflow › Where the rules live). Many rules are mars-workbench's (`Marsuu1994/mars-workbench`, its `AGENTS.md`), rewritten for Swift; where the two repositories meet, the server is the source of truth.

## Project Overview

The native iOS side of Mars Workbench. Today it is one app, **Dump**: it opens straight into a text field with the keyboard up, saves each entry on the phone first, and sends it to mars-workbench's API in the background once the phone is online. It is for the owner alone: no sign-in, one fixed token built into the app. Later it grows into the native Mars Workbench (`docs/spike/v1-dump-capture.md` › 以后怎么长).

## Tech Stack

- Language: Swift 6 (language mode 6: strict concurrency checking)
- UI: SwiftUI, iOS 17 and later, iPhone only
- Project file: XcodeGen (`project.yml` → `Dump.xcodeproj`, generated and ignored by git)
- Core logic: a Swift package, `DumpCore`, Foundation only, so it builds and tests on Linux too
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`)
- Formatting: `swift format` (`.swift-format`)
- CI: GitHub Actions — `DumpCore` on Linux, the app build on macOS
- Server: mars-workbench's `POST /api/v1/dump-entries` (its `design/reference.md` › Native API)

## Project Structure

Directory responsibilities only — for concrete file and type names, read the code.

```text
project.yml                 # XcodeGen: targets, settings, Info.plist keys
Config/                     # xcconfig: App.xcconfig (every build), Secrets.example.xcconfig (template of the ignored Secrets.xcconfig)
DumpApp/                    # The app target: SwiftUI views and everything that needs an iOS framework (UIKit, BackgroundTasks, Network)
Packages/DumpCore/          # Everything else: entry rules, the outbox on disk, the API client, the send loop — Foundation only
├── Sources/DumpCore/
└── Tests/DumpCoreTests/
docs/
├── specs/                  # One spec per screen: what the app does, as flows — rules in its README
├── spike/                  # Spike docs for open questions — rules in its README
└── tracker.md              # Roadmap — open items only
.github/workflows/ci.yml    # CI
```

## Workflow

### Session start

- Read `docs/specs/<screen>.md` before changing what the app does, and the spike behind it when the spec isn't enough.
- A cloud session runs on Linux, with no Xcode: it can build and test `DumpCore` (`swift test`) and change `project.yml`, but not build the app. The app target is checked by CI's macOS job and on the owner's Mac. Say so in the PR when a change touches `DumpApp/` and CI's macOS job is the only build it had.
- The Swift toolchain on Linux: download the release for the container's Ubuntu from swift.org (`/api/v1/install/releases.json` lists them) and put its `usr/bin` on `PATH`.

### Where the rules live

A rule that only one kind of file needs lives with that file. Read it before you edit:

| Before you edit… | Read first |
| --- | --- |
| a spec (`docs/specs/`) | `docs/specs/README.md` |
| a spike (`docs/spike/`) | `docs/spike/README.md` |
| `docs/tracker.md` | its Conventions section |

### Adding a rule

Every rule has one home, and everything else points to it: code taste and the rules every task needs live in this file, and a rule only one kind of file needs lives where the table above says. A rule a linter or script can check goes into the tool, with at most one line here. A rule that overlaps an existing one rewrites that rule instead of adding a second.

### Spike first for complex tasks

A complex task — several PRs, a new screen, a change to what is stored on the phone or sent to the server, or a choice with real tradeoffs — starts with a spike in `docs/spike/`, not code. Lifecycle and shape: `docs/spike/README.md`. A change that needs the server too starts with the server's side in mars-workbench, which owns the API.

## Documentation Style

- **Living docs are for the owner to re-orient, not the agent's work record.** README › Current State, `docs/tracker.md` and the specs say what the app is now and what's still open. Write at the doc's altitude; length doesn't scale with diff size — a bigger change earns a higher-level summary, not a longer one; rewrite the sentence that is now wrong instead of appending a paragraph. Implementation inventory (file and type names, sub-change lists) lives in the code and the diff; completeness lives in PR descriptions and the git history.
- **Docs and code comments are written for a person.** What a person can follow, an agent can too; the reverse doesn't hold.
  - Whole sentences: say who does what and when, not noun phrases or shorthand; give a term or a status its meaning the first time it appears; spell out a timing or a condition rather than naming it. Bad (a comment): `// retry w/ backoff, reset on ok`. Good: `// After a failure, wait before sending again: one second, doubling each time up to five minutes. A batch that goes through resets the wait.`
  - Lists for long descriptions: when a description runs long and splits along its own structure (parts, steps, cases), make it a list with `name: description` per item, not one long sentence.
- **A doc comment (`///`) on every type and on every function whose name doesn't say all it does**: what it returns or does, and the case a caller wouldn't guess (what nil means, what it throws, what it skips).

## Layers

- **`DumpCore` holds every rule; the app target holds only what needs iOS.** Entry rules, the outbox on disk, the API client, the send loop and its retries live in the package and are tested there. The app target holds the SwiftUI views, the iOS-only edges (`NWPathMonitor`, `BGTaskScheduler`, `UIApplication`, `URLSession`'s wiring, Info.plist values) and the wiring between them. Bad: a view deciding whether an entry is too long. Good: the Dump button disabled by `EntryRules.content(from:)`.
- **The edges are protocols in `DumpCore`, so tests stand in for them.** The server is `DumpSending`, HTTP is `HTTPTransport`, time is a `sleep` closure. A test fakes only these edges; the file system is real, in a temporary directory.
- **The server's rules are the server's.** A rule the app repeats so it never sends something the server refuses (an entry's length, the batch limit) names where it comes from in mars-workbench, and both change together. The server stays the one that enforces it.
- **The phone never loses an entry.** Nothing written down is deleted until the server has accepted it; what the server refuses is moved aside, never deleted. A change to the outbox keeps this, and its tests check it.
- **Views stay thin.** A view reads state and calls one function per action; anything with a rule in it moves to `DumpCore`. State shared across views is one `@Observable` class, passed down with `.environment(…)`; a view's own state is `@State`.

## Coding Conventions

### General

- **DRY — one definition per piece of logic, markup or type.** Views that repeat with only data or color differences become one parameterized view; a constant used in two places is defined once.
- **One type per file**, the file named after the type. Small private helpers of that type may share its file.
- **Name things plainly — clear and boring beats short or clever.** A function says what it returns or does, including what it looks up by; a variable or parameter — closure parameters included — says what it holds. Full words only; `$0` only in a closure of one short expression. Bad: `func proc(_ e: [PendingEntry])`, `ids.map { x in … }`. Good: `func send(_ entries: [PendingEntry])`, `batch.map(\.id)`.
- **No magic literals.** Fixed, non-user-facing literals — identifiers, durations, limits, keys, paddings — go into a named constant (`AppConstants` in the app, a `static let` on the type that owns it in `DumpCore`). Bad: `.padding(12)`, `"composerDraft"` inline. Good: `AppConstants.composerPadding`, `AppConstants.draftKey`.
- **A workaround is fine, but marked.** Code that exists only to get around someone else's bug or quirk — Apple's, a dependency's — opens its comment with `Workaround (<whose>):`, says what goes wrong without it, and links the report when there is one.
- **No force unwrap (`!`) or force try (`try!`) in app code or `DumpCore`'s sources**; tests may force-unwrap a fixture they just built. A value that can be missing is handled where it is read.
- **Errors**: a function that can fail and whose caller can act on it `throws`; one whose caller can't (a best-effort cleanup) uses `try?` with a comment on why ignoring is safe.

### Enums

- **Branching is an exhaustive `switch`.** On our own enums there is no `default`, so a new case fails to compile until it is handled. On Apple's enums that aren't frozen (`ScenePhase`), `@unknown default` is required and does nothing.
- **Maps over an enum are a `switch` in a computed property**, not a dictionary that can miss a case.

### Concurrency

- **Shared mutable state lives in an actor** (`Outbox`), or on the main actor when the UI reads it (`@MainActor @Observable`). No locks, no `@unchecked Sendable` except around an Apple type that is thread-safe but not marked so, with a comment saying which.
- **UI is updated on the main actor.** Code off the main actor that changes what a view shows hops with `await MainActor.run { … }`.

### SwiftUI

- **Keep `body` an outline.** Conditional or long pieces become computed properties (`keyboardBar`) or their own view (`StatusHint`); `body` reads as the screen's structure.
- **A closure passed to a modifier that is empty or one line is written on the modifier.** Longer ones become a named method.
- **System styles over fixed ones**: `.font(.footnote)`, `.foregroundStyle(.secondary)`, so Dynamic Type and dark mode work without code. A fixed color only where it means something (red for an invalid token).
- **Copy**: short, plain English, in `Text("…")` so it can be localized later. Every user-facing string is listed in its screen's spec.
- **Every view has a `#Preview`** with the state it needs.

## Code Style

- `swift format` owns formatting (`.swift-format`); don't hand-tune spacing against it. CI runs `swift format lint --strict`.
- Access control: `DumpCore`'s API is `public` only where the app uses it; everything else is internal, and tests reach it with `@testable import`.

## Tests

- **`DumpCore` is tested; the app target is checked by building it and by the owner.** Swift Testing, one suite per type, next to nothing else: `Packages/DumpCore/Tests/DumpCoreTests/`.
- **Assert the outcome, not how the code reaches it**: what is in the outbox's folders, what the status says, what was sent — not which private function ran.
- **See it fail**: a bug fix starts with a test that fails; a test for behaviour that already exists is checked by breaking the code once, seeing the test turn red, and putting the code back.
- **Fakes only at the edges** (Layers): `FakeSender`, `FakeTransport`, a `sleep` that returns at once. The file system is real, in a fresh temporary directory per test.
- **The end-to-end suite** (`EndToEndTests`) runs the real client and outbox against a running mars-workbench. It is skipped unless `DUMP_E2E_BASE_URL` is set; run it against `npm run dev` on mars-workbench's local stack when a change touches the client, the wire format or the send loop (Commands).

## Project file

- **`project.yml` is the project.** `Dump.xcodeproj` and `DumpApp/Info.plist` are generated by `xcodegen generate` and ignored by git: a change made in Xcode's project editor is lost at the next generate. Add a file by creating it under `DumpApp/` (XcodeGen picks it up); change a setting, a capability or an Info.plist key in `project.yml`.
- **Secrets stay out of git.** The token and the signing team live in `Config/Secrets.xcconfig`, which git ignores; `Config/Secrets.example.xcconfig` is its template and holds no real value. A value in an xcconfig file is cut at `//`, so a URL is written `https:/$()/host`, and the token is hex.

## Version Control

- **Remote sessions** (cloud containers such as Claude Code on the web): commit and push with `git push -u origin <branch>` without asking.
- **Local sessions** (on the owner's Mac): never commit, push or take another outward-facing VCS action without explicit permission — make and stage the changes, summarize them, and wait for approval.
- **A PR opens only when the owner asks for one.** Once a remote session's PR is open, it subscribes to its activity and sees it through until it merges or closes: red CI and review comments are the session's to fix. Once a PR is open, every push that adds commits rewrites its description to say what the PR is now.
- Never commit or push to `main`; changes land through pull requests.
- **Branch names say what the PR does**: `claude/<feature>-<change>`, kebab-case, a few words. A remote session whose assigned branch is a random name creates a descriptive branch instead.
- **Before every push**:
  1. `docs/tracker.md`: delete finished items.
  2. README › Current State: rewrite the parts the change touches.
  3. The spec of every screen whose behaviour changed.
  4. AGENTS.md, or a README it indexes: only when a rule or a directory's responsibility changed.
  5. Run `swift format --in-place --recursive Packages DumpApp`, then `swift format lint --strict --recursive Packages DumpApp` and `swift test --package-path Packages/DumpCore`. On a Mac, also `xcodegen generate` and a build of the app (⌘B, or the `xcodebuild` line in Commands).

## Commands

```bash
xcodegen generate                                            # Dump.xcodeproj + DumpApp/Info.plist from project.yml (Mac)
open Dump.xcodeproj                                          # then ⌘R to run in the Simulator or on the phone
swift test --package-path Packages/DumpCore                  # DumpCore's tests (Mac or Linux)
swift format --in-place --recursive Packages DumpApp         # format
swift format lint --strict --recursive Packages DumpApp      # what CI checks
xcodebuild build -project Dump.xcodeproj -scheme Dump -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO  # the app build CI runs (Mac)
DUMP_E2E_BASE_URL=http://localhost:3000 DUMP_E2E_TOKEN=local-dev-token swift test --package-path Packages/DumpCore --filter EndToEnd  # against mars-workbench's npm run dev
```
