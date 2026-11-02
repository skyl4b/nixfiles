# Copy the complete recipe tree into an isolated test checkout
[positional-arguments]
_copy-justfiles destination:
    #!/usr/bin/env bash
    set -euo pipefail
    destination="$1"
    mkdir -p -- "$destination/src/scripts" "$destination/test"
    cp -- "$NIXFILES_CHECKOUT/justfile" "$destination/justfile"
    cp -- "$NIXFILES_CHECKOUT"/src/scripts/*.just "$destination/src/scripts/"
    cp -- "$NIXFILES_CHECKOUT"/test/*.just "$destination/test/"
