# Universal clipboard branch

Base: Anubhav-Rai/tendedero `feature/copied-text`, commit 1a861ea9304cc0bae89c7d9a0ec5162ab8616dda.

Changes:
- Text notes expose only plain text when copied or dragged. Whitespace and Unicode are preserved. Missing notes fail rather than falling back to uploading a .txt file.
- Enable **Hang copied files** in the menu bar. Finder files and folders (including multi-selection) hang individually as references with filename/icon cards. Dragging copies the original; clicking copies its file URL. Removing/evicting a reference does not delete the original. Explicit “Move to Trash” still does.
- Real .txt files remain files; reference identity survives relaunch. Existing note history is retained. Moved/deleted source files are pruned; this is not an archival backup.
- Note and file cards follow the system appearance, including already-hanging cards and drag previews. Own clipboard writes are ignored by the watcher.

On macOS, quit the installed app first, then run:

```sh
scripts/test-clipboard.sh
scripts/build-app.sh
open build/Tendedero.app
```

Manual checks:
1. Enable copied text/files. Copy multiline Unicode text, click and paste it, then drag into TextEdit and a browser input. Confirm text is inserted and no .txt attachment appears. Some web editors may reject text drops.
2. Copy a PDF, a .txt file, a folder and multiple files in Finder. Check individual cards, copy/paste, drag to another folder (original stays), Open, Quick Look, and relaunch persistence.
3. Switch light/dark while notes are hanging; verify card backgrounds, text contrast and drag previews. Remove file cards and exceed line capacity; originals must remain.

Validation in the editing environment: diff/ shell syntax checks only. Linux has no Swift compiler or macOS SDK; macOS tests, app build and UI verification have not been run.

## Card presentation update

- Image clips retain the original narrow silhouette. Text clips are slightly wider with two small grooves; file clips have a wider body and a small inset mark. All retain the brushed silver finish and original height.
- Notes use low-contrast ruled lines in both appearances. The measured text block is vertically centered; long notes stay within the padded area and truncate.
- File artwork and filename are centered as one group. Quick Look thumbnails are requested asynchronously for files, including supported images, videos and documents; folders/unsupported formats retain their system icons. Previews stay in memory and are reused on theme changes. Removed cards cancel pending requests; stale callbacks are ignored.

Additional macOS checks: inspect a short note, multiline note and overflowing note in both themes; copy PNG/MOV/PDF/DOCX and a folder; switch themes while previews load; remove a loading card; verify the filename remains visible and previews do not stretch. These UI checks have not been executed in the Linux editing environment.

## Duplicate notes after selecting text (2026-10-25)

The text watcher previously treated every changeCount increment as a fresh copy and always wrote a new note. Selection/translation helpers can temporarily use the clipboard and then restore the previous text without the app's origin marker. This explains a possible trigger; the particular third-party writer has not been traced on the user's Mac.

Before saving a text payload, the watcher now asks the line whether a live text note already contains those exact UTF-8 bytes. Falling cards and file references are excluded. Comparison uses full file contents and checks byte size first, so previews, whitespace trimming and Unicode normalization cannot collapse distinct payloads. Notes restored at launch and externally edited files are covered; removing a card or deleting its backing file allows a fresh capture. The pasteboard count is rechecked after lookup to avoid saving stale content. Existing duplicate cards are left for manual removal.

The real watcher is exercised by Tests/ClipboardWatcher/main.swift using a private pasteboard and temporary inbox. scripts/test-clipboard.sh now covers repeated restores, private temporary selection, A/B/A history, whitespace differences, app-origin/private filtering, removing/editing/deleting notes and watcher recreation. Manual reproduction: copy A, select unrelated text without Copy several times, then copy B and restore A; no second A should appear while A remains hanging. Remove A and copy it again; it should hang once.

Validation for this change: git diff --check and bash -n passed. This Linux workspace has no Swift compiler/macOS SDK; the Swift regression executable and macOS reproduction remain unrun.

## Top-left hover activation (2026-10-25)

The menu's Bring the line down submenu now contains Hover trigger area with mutually exclusive Entire menu bar and Top-left corner only choices. The persisted boolean defaults to the previous full-width behavior. In corner mode the activation rectangle is the leftmost 48 points of each screen's existing menu-bar band; it uses screen-relative coordinates, including negative display origins and the auto-hidden menu bar fallback. Only hidden-to-visible hover activation changes. Expanded-card interaction, keyboard/manual opening, new-item peeks and full-width menu-click dismissal retain their existing behavior. Click suppression resets when leaving the selected hover region.

Validation: diff and Shell syntax checks only; macOS UI checks remain required. On Mac, select corner mode, hover over the center/right menu bar (must not open), enter the left 48 points for 0.25 s (must open), move to the cards (must stay open), click a menu then leave/re-enter the corner, restart to verify persistence, and repeat on a secondary display. Disable new-item peeks when testing hover in isolation.
