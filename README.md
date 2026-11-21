# Mars Workbench iOS

The native iOS side of [Mars Workbench](https://github.com/Marsuu1994/mars-workbench). Today it is one app, **Dump**: open it and the keyboard is already up; write, tap Dump, and the entry is saved on the phone at once and sent to your Mars Workbench Dump feed in the background, even if you were offline when you wrote it.

## Current State

### Dump

- The app opens straight into a text field with the keyboard up, and comes back to it every time you return to the app.
- Tap **Dump** above the keyboard: the field clears, the phone gives a light tap, and you can write the next one. Return makes a new line.
- What you are typing is kept if you leave the app, until you dump it.
- Every entry is saved on the phone first, so it is never lost to a bad connection. The app sends what is waiting as soon as it has a connection: right after you dump, when you come back to the app, when the network returns, for a few seconds after you leave the app, and at times iOS picks later on.
- Each entry lands in the web feed at the moment you wrote it down, not when it arrived.
- Next to the Dump button, a small hint says how many entries are still waiting, or that the token is invalid. It is empty while everything is sent.
- No history on the phone: read your entries in Mars Workbench's Dump page.

What it does, flow by flow: [docs/specs/capture.md](./docs/specs/capture.md). Why it is built this way: [docs/spike/v1-dump-capture.md](./docs/spike/v1-dump-capture.md), which ends with an iOS dev primer (Xcode, Swift, SwiftUI, storage, networking, offline retries, installing on the phone).

## Set up

You need a Mac. Once per Mac:

1. Install Xcode from the Mac App Store, open it once and let it install its components.
2. Install XcodeGen, which writes the Xcode project from `project.yml`:

   ```bash
   brew install xcodegen
   ```

3. In Xcode › Settings › Accounts, sign in with your Apple ID. A free Apple ID is enough; its signing lasts 7 days (below).

Once per checkout:

4. Create your secrets file and paste mars-workbench's `NATIVE_API_TOKEN` (the one set on Vercel) into it:

   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```

5. Generate the project and open it:

   ```bash
   xcodegen generate
   ```

   ```bash
   open Dump.xcodeproj
   ```

6. Choose your signing team: select the **Dump** target › Signing & Capabilities › Team › your Personal Team. Then copy its id into `Config/Secrets.xcconfig` (`DEVELOPMENT_TEAM`), so the next `xcodegen generate` keeps it:

   ```bash
   grep -m1 DEVELOPMENT_TEAM Dump.xcodeproj/project.pbxproj
   ```

Run `xcodegen generate` again after every pull: the project is generated, not stored in git.

## Install on your iPhone

Once per phone:

1. Connect it to the Mac with a cable and tap **Trust** on the phone.
2. On the phone, turn on Settings › Privacy & Security › Developer Mode (it appears once Xcode has seen the phone) and let it restart.
3. After the first install, the phone can be reached over the same Wi-Fi, without the cable (Xcode › Window › Devices and Simulators).

Every install:

1. In Xcode's toolbar, choose your iPhone as the destination and press ⌘R.
2. The first time, the phone refuses to open an app from an untrusted developer: trust yourself in Settings › General › VPN & Device Management.

With a free Apple ID the app stops opening 7 days after it was installed. Press ⌘R again to reinstall; nothing on the phone is lost, and entries still waiting are sent once it opens.

## Develop

- **In the Simulator against your local Mars Workbench**: run `npm run dev` in mars-workbench, and in `Config/Secrets.xcconfig` uncomment the two local lines (`localhost:3000`, `local-dev-token`). Run `xcodegen generate`, then ⌘R with an iPhone Simulator as the destination.
- **Tests**: `DumpCore` holds every rule and is tested with `swift test --package-path Packages/DumpCore`, on a Mac or Linux. The app itself is checked by CI's macOS build and by using it.
- **Rules for code and docs**: [AGENTS.md](./AGENTS.md).

## How it works

```text
ComposerView ──capture──▶ Outbox (DumpCore) ──save──▶ Application Support/Outbox/pending/<id>.json
                              │
              flush ◀─────────┤  triggers: a capture, the app coming back, the network returning,
                              │  leaving the app (≈30 s), iOS background refresh, a retry's wait
                              ▼
                    DumpAPIClient ──POST /api/v1/dump-entries──▶ mars-workbench
                              │
        200: delete the files │ 400: move to rejected/ │ 401: show "Token invalid" │ else: retry later
```

- **Retries can't duplicate**: each entry carries the id the phone gave it, and the server stores an id once.
- **Retry waits** start at one second and double up to five minutes.
- **Refused entries** (the server answered 400) move to `rejected/` on the phone. They are kept, not counted and not sent again.

## Docs

- [AGENTS.md](./AGENTS.md): the rules for working in this repository (agents and people).
- [docs/specs/](./docs/specs/README.md): what each screen does.
- [docs/spike/](./docs/spike/README.md): proposals for open questions, and the decisions they led to.
- [docs/tracker.md](./docs/tracker.md): what is still open.
