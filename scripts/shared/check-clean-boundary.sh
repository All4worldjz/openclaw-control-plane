#!/usr/bin/env bash
set -euo pipefail

echo "Scanning for files that should not be committed..."
FOUND=0

patterns='*.pem *.key *.p12 *.crt .env .env.local .env.prod .env.lab MEMORY.md memory.md *.sqlite *.sqlite3 *.db'

for p in $patterns; do
  if find . -type f -name "$p" | grep -q .; then
    echo "Found forbidden/sensitive pattern: $p"
    find . -type f -name "$p"
    FOUND=1
  fi
done

if [ "$FOUND" -ne 0 ]; then
  echo "Boundary check FAILED."
  exit 1
fi

echo "Boundary check passed."
