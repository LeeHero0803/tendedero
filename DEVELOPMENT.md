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

## Spaces hover recovery (2026-10-29)

Code inspection found three distinct factors. First, NSWindow canJoinAllSpaces was already set, so adding it again is not a fix. Second, the logical isRevealed/isPresent flags could survive Space transitions; present() and setRevealed(true) previously returned early and tick() never reached hover activation while isRevealed stayed true, even if WindowServer no longer displayed the panel. Third, hover activation only updated geometry when the NSScreen object changed, although a different Space/full-screen state on the same physical display can have a different visible frame. These are code-level failure paths, not a reproduction of the user's exact desktop state. Full-screen rejection with showOverFullScreen disabled is intentional, not this bug.

Changes: handle activeSpaceDidChange separately from app activation, reset stale hover/click timers on Space changes, synchronize geometry immediately and after the transition settles, make presentation reassert window ordering, and let tick return an invisible/off-Space panel to the normal hover path. Every hover reveal explicitly places on the triggering screen. Do not relocate/recover an active drag or context menu. Keep the existing canJoinAllSpaces/fullScreenAuxiliary collection behavior. Stage Manager is disabled in the user setup and is outside this fix. No application activation, focus stealing, moveToActiveSpace or fullscreen preference changes.

Manual validation matrix (not run in Linux):
- Two ordinary desktop Spaces: hidden/revealed line before switching; enter left corner after switching; repeat switches in both directions and rapidly.
- Leave the pointer in the corner while switching; click Apple menu then switch desktops and retry; confirm a fresh 0.25 s dwell works and menu clicks still dismiss.
- Secondary display with independent Spaces and auto-hiding menu bar: trigger on each display and verify positioning below the current menu bar.
- Full-screen app: off means intentionally blocked; enable Over full screen apps and verify it opens without changing Space or focus. Exit fullscreen and retry on an ordinary desktop.
- Repeat application switches, drag a card while switching, and open a card menu. Pending delayed reconciliation must not move the drag source or close the menu.

Validation completed here: git diff --check and bash -n scripts/test-clipboard.sh scripts/build-app.sh. No Swift compiler or macOS WindowServer is available in the editing environment; runtime recovery and full-screen behavior require Mac confirmation.

## Stronger note rules (2026-10-29)

Raised rule opacity from 0.09 to 0.18 in dark mode and 0.08 to 0.16 in light mode, and stroke width from max(0.5, scale) to max(1, 2 * scale). Text, paper colors, alignment and transfer contents are unchanged. Static diff checks passed; check short/multiline cards in both themes at all three sizes on Mac for readability and visible rules.

## Distinct metal clip silhouettes (2026-10-29)

Replaced the text/file variants' subtle engravings with native SwiftUI paths: notes have a tapered binder clip body and two spring-wire handles in warm titanium; file references have an arched bulldog/mountain clip plate, circular eye and rolled jaw in cool steel. Images retain the original neutral silver pin. All variants keep a 26-point height inside a 34-point noninteractive frame, preserving cardOffsetBelowTop, hit rectangles and flight attachment geometry. No bitmap assets or dependencies are added.

Static diff and shell checks passed. macOS compilation and visual checks remain pending: inspect all three silhouettes on light/dark desktops and at each card size, hover/copy/drag cards, and check that clips overlap the card edge without obscuring text or changing rope alignment. These are native vector designs; they have not been rendered in AppKit/SwiftUI in the Linux editing environment.

## Shared typography and extension labels (2026-10-29)

CardTypography provides monospacedSystemFont with system script fallback, character wrapping, disabled hyphenation/default line-break strategies, and a persisted small/medium/large/extraLarge scale (22/24/28/32 in a 320-wide thumbnail). Default note glyphs previously corresponded to about 22.15 in that coordinate system; medium now uses 24. Note canvas fonts scale by width so their displayed size matches file labels. Explicit source newlines remain intact. The existing content truncation is only for previews.

File titles omit their final extension and wrap within two lines. An uppercase capsule label below holds the extension; extensionless files and ordinary directories have no tag, and dotted directory names are preserved. Packages can retain their extension tag. Both title and artwork remain vertically centered together; increasing text size reduces the artwork slot before reducing text space. The extension badge is smaller supporting text in the same font family.

A separate Card text size menu immediately reloads thumbnails (including cached file previews) and stores the choice without changing card geometry or image content. Tests/CardTypography/main.swift checks the shared scaled font, an English line that must fill partway into the next word, and extension/dotted-folder labeling. It runs from scripts/test-clipboard.sh. Static diff and shell syntax checks passed; the Swift/AppKit tests and light/dark, mixed CJK/Latin/emoji, long-title and all-size visual checks have not run in this Linux environment.
