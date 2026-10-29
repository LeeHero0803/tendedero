#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
swiftc Sources/Tendedero/ClipboardTransfer.swift Tests/ClipboardTransfer/main.swift -o "$test_dir/clipboard-tests"
"$test_dir/clipboard-tests"

swiftc Sources/Tendedero/TextNoteDeduplication.swift Sources/Tendedero/ClipboardWatcher.swift Tests/ClipboardWatcher/main.swift -o "$test_dir/watcher-tests"
"$test_dir/watcher-tests"

swiftc Sources/Tendedero/CardTypography.swift Tests/CardTypography/main.swift -o "$test_dir/typography-tests"
"$test_dir/typography-tests"
