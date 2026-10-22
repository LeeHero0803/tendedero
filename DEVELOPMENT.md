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
