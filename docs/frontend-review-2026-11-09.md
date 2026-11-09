# Web frontend review — 9 November 2026

Target: https://shell.strandberg.dev. Deployed from local commit `4f7b544`.
The served `main.dart.js` SHA-256 matched the local release build:
`f7eecfcb4943534d541d7319cda353bc3d277b613e8a048efa86b5e873139d34`.

## Method and limits

An agent drove Chromium with Playwright through the deployed UI. Server lifecycle tests passed at 1280×900 and 390×844, including editing Startup command with tmux enabled, saving, reloading, editing, and deleting the dummy server. The extended control review used the mobile viewport. Each run used fresh browser storage, dummy credentials, and the reserved address `192.0.2.1`. All WebSockets were intercepted and blocked; no connection was attempted.

“Tested” below means exercised through the UI, not verified against an SSH server. Settings required accessible click actions because Flutter's semantics overlay intercepted normal Playwright pointer clicks. This is an automation/accessibility limitation, not proof that ordinary touch interaction is broken. Screenshots, semantic snapshots, and traces are under `build/frontend-review/`; lifecycle traces are under `build/web-smoke-desktop/` and `build/web-smoke-mobile/`. Browser emulation does not verify Android keyboard or haptic behavior.

## Findings

1. **Validation feedback stays stale.** After correcting a missing Host/Username/Password or an invalid Port, the old error remains until Save is pressed again. Revalidate changed fields after the first submission.
2. **Hidden key copy is misleading.** Hiding a newly typed, invalid, unsaved key displays “Private key saved.” Use “Private key hidden”; reserve “saved” for persisted data.
3. **Settings accessibility needs labels.** Show key row and Haptics expose unnamed switches. Text size exposes an unnamed slider with an unhelpful numeric value in the semantic snapshot. Add explicit labels and announce point sizes; expose selected theme state too.
4. **Shortcut copy is inconsistent with the simplified app.** “Terminal Keys & Shortcuts,” “Key Bar Layout,” “STICKY MODIFIERS,” and “SHORTCUT KEYS & MACROS” mix styles and jargon. Prefer “Keys,” “Key row,” “Modifiers,” and “Shortcuts.”
5. **Theme names truncate on phones.** ShellLite Obsidian and Catppuccin Mocha are shortened visually at 390 pixels. Allow two lines or use shorter display names.
6. **Macro inputs lose accessible names.** Key Label, Sequence / Text, and Description use hints instead of input labels. After applying a preset, the semantic tree exposes three unnamed textboxes. Add permanent labels.
7. **Shortcut feedback outlives the screen.** Rapidly adding keys queues one-second snackbars; old “Added … to key bar” messages remain visible after navigating to Privacy. Replace the current message or clear the queue when leaving.
8. **Clear password appears late.** Typing into a fresh Password field does not reveal Clear password. Toggling Show password triggers a rebuild and makes it appear. Rebuild the suffix controls when the controller changes.

## Home and saved servers

| Control | Comment |
| --- | --- |
| Settings | Tested opening settings. |
| Add server (empty state) | Tested; opens New server. |
| Add server (count/10) | Tested opening New server and returning with Back. Count updates after save/delete. |
| Server card | Displays the dummy name, host, user, port, and Disconnected. Deliberately not pressed: it connects. |
| Server options | Tested; opens Edit/Delete menu. |
| Edit | Tested; saved name, tmux setting/session, and Startup command survive reload. |
| Delete (menu) | Tested; opens confirmation naming the correct dummy server. |
| Cancel (delete dialog) | Tested; keeps the server. |
| Delete (confirmation) | Tested; removes the server, including after reload. |

## New/edit server: every input

| Input | Comment |
| --- | --- |
| Host | Tested typing a reserved IP; required validation works. Old validation text remains until Save. |
| Username | Tested typing dummy user; required validation works, with the same stale-feedback issue. |
| Password | Tested dummy entry, masking, and visibility. Empty value is rejected for a new profile. |
| Private key | Tested dummy invalid text and missing-key validation; no real key used. Needs a permanent field label, rather than only a paste hint. |
| Key Passphrase (Optional/Required) | Tested dummy text, visibility, and clear action. Encrypted-key parsing was not verified in this browser review. |
| Name (optional) | Tested entry and persistence. The previously overlapping label is now spaced below More options. |
| Port | Tested rejecting `0`, then accepting and displaying `2222`. Error remains until Save after correction. |
| Session Name | Tested entry and persistence with tmux on. Optional/default explanation is long on phones. |
| Startup command | Tested typing `pwd` with tmux on and persisting after reload. Helper explains that it is saved for connections without tmux. Actual execution was intentionally not tested. |

## New/edit server: every button and switch

| Control | Comment |
| --- | --- |
| Back | Tested returning to the list. Unsaved-change confirmation was not tested. |
| Save | Tested empty-form errors, invalid-port rejection, creation, and editing. Does not connect. |
| Password (authentication selector) | Tested switching back from SSH key. |
| SSH key (authentication selector) | Tested displaying key/passphrase inputs. |
| Show password | Tested revealing dummy password. |
| Hide password | Tested returning to masked entry. |
| Clear password | Verified empty value after clearing. Does not appear immediately after typing; appears after toggling Show password. See finding 8. |
| Hide key | Tested; hides entry, but incorrectly says “Private key saved” before saving. |
| Show key | Tested restoring key input. |
| Clear (private key) | Tested clearing key entry; resets key validation. “Clear key” would be clearer. |
| Show passphrase | Tested revealing dummy passphrase. |
| Hide passphrase | Tested restoring masking. |
| Clear passphrase | Verified empty value after clearing. Persistence was not separately verified. |
| More options | Tested expand/collapse. Invalid submission expands advanced fields automatically. |
| Persistent Session (tmux) | Tested enabled state and persistence. Does not disable Startup command anymore. Runtime tmux behavior excluded. |

## Settings

| Control | Comment |
| --- | --- |
| Reset | Tested returning text size to 13.5 pt and default settings in isolated storage. Its scope could be clearer (“Reset settings”). |
| ShellLite Obsidian | Exercised theme selection. Name truncates on phone. |
| Catppuccin Mocha | Exercised theme selection. Name truncates on phone. |
| Dracula | Exercised theme selection. |
| Nord | Exercised theme selection. |
| Tokyo Night | Exercised theme selection. |
| Solarized Dark | Exercised theme selection. |
| Decrease font size | Exercised decreasing text size. |
| Increase font size | Exercised increasing text size. |
| Text size slider | Keyboard adjustment changed displayed size to 14.0 pt. Needs an accessible name/value. |
| Keys | Tested opening shortcut configuration. |
| Show key row | Tested toggle both ways. Needs accessible label; terminal effect excluded. |
| Haptics | Tested toggle both ways. Needs accessible label; physical vibration unverified in web emulation. |
| Privacy | Opens the local policy screen; no browser launch needed. |
| Sheet dismiss gesture/backdrop | Present; gesture behavior was not explicitly tested. An accessible Close button would improve discoverability. |

## Key configuration

The controls below configure the local key row. Their descriptions explain what a key generally does in a terminal; no terminal commands were executed during this review.

| Control | Comment |
| --- | --- |
| Back | Tested returning from key configuration. |
| Key Bar Layout tab | Tested default layout view. Rename to “Key row” for consistency. |
| Function (F1–F12) tab | Tested listing all 12 function-key buttons. |
| Navigation tab | Tested listing navigation buttons. |
| Control Keys tab | Tested listing control shortcuts. |
| Add Custom Key | Tested opening the dialog and adding a dummy macro. |
| Reset Defaults | Tested opening reset confirmation. |
| Cancel (reset dialog) | Tested preserving layout. |
| Reset Layout | Tested restoring defaults. Confirmation mentions ^C/^D even though the default visible row is Esc, Tab, and arrows; align the description. |
| Ctrl Sticky Modifier switch | Tested toggling both ways; actual latch/lock behavior requires the terminal. |
| Alt / Meta Sticky Modifier switch | Tested toggling both ways; actual prefix behavior requires the terminal. |
| Esc visibility switch | Tested toggling both ways. |
| Tab visibility switch | Tested toggling both ways. |
| ↑ visibility switch | Tested toggling both ways. |
| ↓ visibility switch | Tested toggling both ways. |
| ← visibility switch | Tested toggling both ways. |
| → visibility switch | Tested toggling both ways. |
| Custom-key visibility switch | Present for the created macro; default-row switches were tested as representatives. |
| Delete custom key | Tested removing the dummy macro. Immediate action; no confirmation. |
| Key drag handles | Present; drag reorder was not exercised. Custom move-up/down semantics exist in source but were not tested here. |

### Function-key buttons

Each button was exercised as a local shortcut configuration action. Application-specific effects were not tested.

| Button | Comment |
| --- | --- |
| F1 | Help/menu shortcut. |
| F2 | User-menu shortcut. |
| F3 | View-file shortcut. |
| F4 | Edit-file shortcut. |
| F5 | Copy/refresh shortcut. |
| F6 | Move/rename shortcut; “Ren” is unnecessarily abbreviated. |
| F7 | Make-directory/search shortcut. |
| F8 | Delete-file shortcut. |
| F9 | Pull-down-menu shortcut. |
| F10 | Quit/exit shortcut. |
| F11 | Full-screen/function shortcut. |
| F12 | Function 12 shortcut. |

### Navigation buttons

| Button | Comment |
| --- | --- |
| Home | Exercised local configuration; cursor-to-start shortcut. |
| End | Exercised local configuration; cursor-to-end shortcut. |
| PgUp | Exercised local configuration; page-up shortcut. |
| PgDn | Exercised local configuration; page-down shortcut. |
| Insert | Exercised local configuration; insert-mode shortcut. |
| Delete | Exercised local configuration; forward-delete shortcut. |
| Tab | Exercised local configuration; toggles existing default key visibility. |
| ⇧Tab | Exercised local configuration; reverse-tab shortcut. |
| Esc | Exercised local configuration; toggles existing default key visibility. |

### Control-key buttons

| Button | Comment |
| --- | --- |
| ^A | Exercised local configuration; start of line. |
| ^E | Exercised local configuration; end of line. |
| ^U | Exercised local configuration; clear before cursor. |
| ^K | Exercised local configuration; clear after cursor. |
| ^W | Exercised local configuration; delete previous word. |
| ^R | Exercised local configuration; reverse history search. |
| ^L | Exercised local configuration; clear screen. |
| ^Z | Exercised local configuration; suspend process. |
| ^C | Exercised local configuration; interrupt process. |
| ^D | Exercised local configuration; EOF/exit shell. |
| ^O | Exercised local configuration; nano save. |
| ^X | Exercised local configuration; nano exit. |
| ^G | Exercised local configuration; nano help. |
| ^T | Exercised local configuration; transpose characters. |
| ^S | Exercised local configuration; search/freeze. |
| ^B | Exercised local configuration; cursor backward/tmux prefix. |
| ^F | Exercised local configuration; cursor forward. |
| ^P | Exercised local configuration; previous command. |
| ^N | Exercised local configuration; next command. |
| ^\ | Exercised local configuration; quit process. |

## Add Custom Key dialog

| Input | Comment |
| --- | --- |
| Key Label | Tested entering “Review”; blank value is rejected. Needs an actual accessible label: its hint disappears after prefilling. |
| Sequence / Text | Tested entering a dummy `pwd\n` macro; blank value is rejected. Needs a persistent accessible label. Nothing is executed when saved. |
| Description (Optional) | Tested entering “Review macro.” Needs a persistent accessible label. |

| Button | Comment |
| --- | --- |
| F1 preset | Exercised populating a Help/Menu key. |
| F2 preset | Exercised populating a User menu key. |
| F5 preset | Exercised populating a Copy/Refresh key. |
| F10 preset | Exercised populating a Quit/Exit key. |
| F12 preset | Exercised populating a Function 12 key. |
| Home preset | Exercised populating a cursor-to-start key. |
| End preset | Exercised populating a cursor-to-end key. |
| PgUp preset | Exercised populating a page-up key. |
| PgDn preset | Exercised populating a page-down key. |
| Del preset | Exercised populating a forward-delete key; align “Del” with “Delete” elsewhere. |
| \e (Esc) | Exercised inserting an escape code. |
| \t (Tab) | Exercised inserting a tab code. |
| \n (Enter) | Exercised inserting a newline code. |
| ^C (SIGINT) | Exercised inserting interrupt code; plain “Interrupt” would be easier. |
| ^D (EOF) | Exercised inserting EOF code; explain “End of input.” |
| ^Z (SIGTSTP) | Exercised inserting suspend code; plain “Suspend” would be easier. |
| ^R (Reverse) | Exercised inserting history search; “Search history” is clearer. |
| Cancel | Tested dismissing the dialog and returning to the key layout. |
| Add Key | Tested rejecting empty fields and adding the filled dummy macro. |

## Privacy

| Control | Comment |
| --- | --- |
| Privacy (settings entry) | Tested opening the in-app policy page. |
| Policy URL button | Tested; clipboard contained exactly `https://strandberg.dev/privacy/shelllite/`. Does not launch a browser. |
| Back | Tested returning to the server list. |

## Excluded connection-dependent controls

Server-card connect, SSH authentication, host-key trust dialogs, live terminal selection/copy/link taps, reconnect/disconnect, terminal key execution, upload file picking/destination/replacement/progress/cancel, and remote tmux/startup execution were not tested. The review makes no claims about those controls. They need a controlled test endpoint or a separate mocked session.
