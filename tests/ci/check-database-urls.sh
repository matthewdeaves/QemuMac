#!/usr/bin/env bash
#
# Report whether every URL in the software database is reachable.
#
# Informational by design: these are third-party archives (archive.org
# intermittently answers 500 under load), so an outage on someone else's
# host must not fail the build. Structural validity of the database - every
# entry having a well-formed md5, url, filename and name - is asserted by the
# unit suite, which does not touch the network.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

fails=0
total=0
while IFS= read -r url; do
    [ -z "$url" ] && continue
    total=$((total + 1))
    if curl --head --fail --silent --location --max-time 20 --retry 2 "$url" >/dev/null; then
        echo "ok    $url"
    else
        echo "FAIL  $url"
        fails=$((fails + 1))
    fi
done < <(jq -r '(.cds, .roms) | .[] | .url // empty' iso/software-database.json)

echo "::notice::${fails} of ${total} database URL(s) unreachable"
