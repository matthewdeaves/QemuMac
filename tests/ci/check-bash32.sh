#!/usr/bin/env bash
#
# Parse every script under bash 3.2, the version macOS ships. The macOS jobs
# exercise it implicitly; this pins the exact version so a bash 4+ construct
# fails loudly rather than only on someone else's machine.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

command -v docker >/dev/null || { echo "docker not available"; exit 1; }

list=$(./tests/ci/shell-files.sh | tr '\n' ' ')
docker run --rm -v "$PWD:/repo" -w /repo bash:3.2 \
    sh -c "for f in ${list}; do bash -n \"\$f\" || exit 1; done"
echo "bash 3.2: all scripts parse"
