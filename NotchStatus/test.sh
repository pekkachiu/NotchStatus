#!/bin/bash
# CLT 內建 Swift Testing，但 swift test 找不到它的路徑，需手動指定
set -euo pipefail
cd "$(dirname "$0")"

DEV=/Library/Developer/CommandLineTools/Library/Developer
FRAMEWORKS="$DEV/Frameworks"
LIBS="$DEV/usr/lib"

swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBS" \
    "$@"
