#!/bin/sh
# fetch.sh — the only network path into a mesa-sandbox image (ADR-0011).
# Usage: fetch.sh <name> <platform> <dest-dir>
#   Looks up <name> for <platform> (or "any") in /resources.lock, downloads the
#   artifact, verifies its sha256, and leaves it at <dest-dir>/<filename>.
#   Refuses unknown names and mismatching digests. POSIX sh + curl + sha256sum.
set -eu
name=$1; platform=$2; dest=$3
lock=${RESOURCES_LOCK:-/resources.lock}
row=$(awk -F'\t' -v n="$name" -v p="$platform" '$1==n && ($2==p || $2=="any") {print; exit}' "$lock")
[ -n "$row" ] || { echo "fetch.sh: no locked artifact for $name on $platform" >&2; exit 2; }
url=$(printf '%s' "$row" | cut -f3); sha=$(printf '%s' "$row" | cut -f4); file=$(printf '%s' "$row" | cut -f5)
mkdir -p "$dest"
out="$dest/$file"
echo "fetch.sh: $name ($platform) <- $url"
curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
echo "$sha  $out" | sha256sum -c - >/dev/null || { echo "fetch.sh: sha256 MISMATCH for $name ($platform)" >&2; rm -f "$out"; exit 3; }
echo "fetch.sh: verified $file ($sha)"
