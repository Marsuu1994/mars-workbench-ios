# Capture

The Dump app's only screen. It exists to make writing a thought down take no time: the app opens straight into a text field with the keyboard up, an entry is saved on the phone the moment you tap Dump, and sending it to Mars Workbench happens out of sight, whenever the phone has a connection. Nothing written down is lost to a bad connection, and nothing is shown back: the entries are read on Mars Workbench's Dump page.

> Decided in `docs/spike/v1-dump-capture.md`. The server side is mars-workbench's `POST /api/v1/dump-entries` (its `design/reference.md` › Native API).

## Copy

| Where | Text |
| --- | --- |
| The title at the top | Dump |
| The button above the keyboard | Dump |
| The hint while entries are waiting | {count} pending |
| The hint when the token is refused or missing | Token invalid (with a warning sign, in red) |

---

## Open

### Trigger

The user opens the app, or comes back to it from another app or the home screen.

### Steps

1. The screen shows the text field, filling the screen, with what was there when the user left (the draft, below).
2. The field takes focus and the keyboard comes up, without a tap.
3. In the background, the app refreshes the hint and sends whatever is waiting (Send).

### Rules

- Opening never waits on the network: the field and the keyboard come first, and nothing on the screen depends on the server.
- The field takes focus again every time the app comes back to the screen.

---

## Write

### Trigger

The user types.

### Steps

1. The text goes into the field. Return makes a new line; it doesn't dump.
2. After every change, the text is kept on the phone as the draft.

### Rules

- The draft survives leaving the app and the app being closed, until it is dumped.
- The Dump button is disabled while the text, without the spaces and new lines around it, is empty or longer than 10,000 characters (counted as the server counts them: mars-workbench's `DUMP_ENTRY_MAX_LENGTH`, in UTF-16 code units).

---

## Dump

### Trigger

The user taps Dump.

### Steps

1. The field clears and the phone gives a light tap. The keyboard stays up, ready for the next entry.
2. The app saves the entry on the phone, waiting to be sent: its text without the spaces and new lines around it, the moment it was written down (to the millisecond), and an id the phone makes for it.
3. The hint counts one more pending entry.
4. The app sends what is waiting (Send).

### Rules

- Saving on the phone needs no network, so dumping works the same offline.
- If the entry can't be saved on the phone (the storage is full), the text comes back into the field, unless the user has started typing the next one.
- Entries waiting to be sent are kept in Application Support, which iOS never clears to free space, one file per entry.

---

## Send

### Trigger

Any of these:

- the user dumps an entry;
- the app comes back to the screen;
- the phone gets a connection: when the app starts with one, and each time it comes back;
- the app leaves the screen: iOS grants it about 30 more seconds to finish sending;
- iOS wakes the app in the background: the app asks for this, no sooner than 15 minutes after leaving the screen, whenever entries are still waiting; iOS decides when, and doesn't for an app the user swiped away;
- a retry's wait is over (below).

### Steps

1. If sending is already under way, nothing more starts: the running send reaches every waiting entry.
2. The app takes the waiting entries, oldest first, up to 50 at a time (mars-workbench's `DUMP_BATCH_LIMIT`), and sends them to the server with the token.
3. What happens next depends on the server's answer:
   - **Accepted**: each accepted entry is deleted from the phone, the hint counts down, and the next 50 go.
   - **Refused (the server answered 400)**: the batch is moved aside on the phone, into the outbox's `rejected` folder. It is kept, not sent again and not counted in the hint. The next batch goes.
   - **Token refused (401)**: sending stops, and the hint shows "Token invalid". It tries again at the next trigger.
   - **No answer, or any other answer** (no network, a timeout, a server error): sending stops and is tried again after a wait.
4. When nothing is left, the hint is empty.

### Rules

- **A retry never stores an entry twice.** Each entry carries the id the phone gave it, and the server stores an id once and accepts it again when it comes back. So an entry whose answer was lost on the way (the request arrived, the answer didn't) is simply sent again.
- **The wait before a retry** is one second after the first failure, doubling after each failure in a row up to five minutes, plus up to half a second at random. A batch that goes through resets it. Any other trigger sends at once, without waiting it out.
- **An entry lands at the moment it was written down**: the server keeps the phone's time, except a time in the future (a phone clock running fast), which it stores as the moment it arrived.
- **Only the server's acceptance removes an entry from the phone.** An answer that accepts none of the batch counts as a failure, so the app can't loop on it.
- **A build without a token** sends nothing and shows "Token invalid" from the start; entries are still saved and wait for a build with one.

---

## Hint

### Trigger

The waiting entries or the token's state change: after every dump, every batch sent and every return to the app.

### Steps

1. If the token was refused, or the build has none, the hint shows "Token invalid".
2. Otherwise, if entries are waiting, it shows how many: "3 pending".
3. Otherwise it is empty.

### Rules

- The hint sits left of the Dump button, in the bar above the keyboard, so it is seen only while writing.
- Refused entries are never counted, and no hint mentions them.

---

## Not in this version

- Reading, editing or deleting entries on the phone: the Dump page on the web shows them.
- Signing in: one fixed token, built into the app, for the owner alone.
- Sharing into Dump from another app, widgets, Lock Screen or Control Center buttons, Siri and Shortcuts.
- Sending refused entries again: they stay in the `rejected` folder on the phone.
