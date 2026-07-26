#!/usr/bin/env bash
#
# Install what the unit suite needs, on either platform.
#
set -euo pipefail

case "$(uname -s)" in
    Linux)
        sudo apt-get update
        sudo apt-get install -y jq lsof
        ;;
    Darwin)
        jq --version   # jq and lsof ship with the macOS runner image
        # mount-shared.sh uses hfsutils on macOS (no kernel HFS write
        # support). Without it the shared-disk path dies on a missing
        # command before reaching its own checks.
        brew install hfsutils
        ;;
    *)
        echo "unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac
