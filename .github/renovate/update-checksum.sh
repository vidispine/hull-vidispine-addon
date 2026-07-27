#!/usr/bin/env bash
#
# Renovate postUpgradeTask hook.
#
# After Renovate bumps a tracked version, it runs this script (see renovate.json ->
# postUpgradeTasks). The script fetches the official release checksum for the new
# version and writes it into the matching `ARG <NAME>_CHECKSUM=` line, so the version
# bump and its checksum land in the SAME pull request.
#
# The point: `docker build` then verifies the download against a checksum that is
# already committed in the repo. It never fetches a checksum live at build time.
#
# Which file is touched: exactly the <packageFile> Renovate passes - the single
# Dockerfile it just bumped. That file must carry the matching `ARG <NAME>_CHECKSUM=`
# line (mandatory wherever the version ARG lives); a missing one is a hard error.
# The target file is required, so a manual run must name a Dockerfile too.
#
# Invocation (from renovate.json):
#   bash .github/renovate/update-checksum.sh <depName> <newVersion> <packageFile>
# e.g.
#   bash .github/renovate/update-checksum.sh oras-project/oras 1.3.4 images/hull-integration/Dockerfile
#
# Must be allowlisted for self-hosted Renovate via `allowedCommands`
# (set as RENOVATE_ALLOWED_COMMANDS in .github/workflows/renovate.yml).

set -euo pipefail

DEP_NAME="${1:?usage: update-checksum.sh <depName> <newVersion> <packageFile>}"
NEW_VERSION="${2:?usage: update-checksum.sh <depName> <newVersion> <packageFile>}"
# The single Dockerfile Renovate updated (its {{{packageFile}}}), always required.
# Manual runs must name the Dockerfile too, so exactly one file is ever touched.
TARGET_DOCKERFILE="${3:?usage: update-checksum.sh <depName> <newVersion> <packageFile>}"

if [ ! -f "${TARGET_DOCKERFILE}" ]; then
  echo "ERROR: target file '${TARGET_DOCKERFILE}' does not exist" >&2
  exit 1
fi

# Read a "<sha256>  <filename>" style checksum list from stdin and print the hash for
# an exact filename match. Tolerates the leading '*' (binary-mode marker) that some
# release checksum files put in front of the filename, and a trailing CR (PowerShell's
# hashes.sha256 uses Windows CRLF line endings, which iconv preserves; without stripping
# it the filename compare would never match and produce "no checksum found").
extract_checksum() {
  local target="$1"
  awk -v f="$target" '{ sub(/\r$/, ""); n=$2; sub(/^\*/, "", n); if (n == f) { print $1; exit } }'
}

# Rewrite the checksum `ARG <arg>=...` to the new value in TARGET_DOCKERFILE. The checksum
# ARG is mandatory wherever the matching version ARG lives (and Renovate only runs this
# for a file it just bumped), so a missing checksum ARG is a hard error, not a skip.
update_arg() {
  local arg="$1" value="$2"
  if ! grep -qE "^ARG ${arg}=" "$TARGET_DOCKERFILE"; then
    echo "ERROR: '${TARGET_DOCKERFILE}' has no 'ARG ${arg}=' line to update" >&2
    exit 1
  fi
  sed -i -E "s|^(ARG ${arg}=).*$|\\1${value}|" "$TARGET_DOCKERFILE"
  echo "  ${TARGET_DOCKERFILE}: ARG ${arg}=${value}"
}

case "$DEP_NAME" in
  PowerShell/PowerShell)
    asset="powershell_${NEW_VERSION}-1.deb_amd64.deb"
    url="https://github.com/PowerShell/PowerShell/releases/download/v${NEW_VERSION}/hashes.sha256"
    echo "Fetching PowerShell ${NEW_VERSION} checksums from ${url} ..."
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL "$url" -o "$tmp"
    # hashes.sha256 is UTF-16; decode to UTF-8 (fall back to stripping NUL bytes).
    if command -v iconv >/dev/null 2>&1; then
      decoded="$(iconv -f UTF-16 -t UTF-8 "$tmp")"
    else
      decoded="$(tr -d '\000' < "$tmp")"
    fi
    echo "Searching checksum for: ${asset} in ..."
    echo "$decoded" | head -n 50
    checksum="$(printf '%s\n' "$decoded" | extract_checksum "$asset")"
    [ -n "$checksum" ] || { echo "ERROR: no checksum found for '${asset}'" >&2; exit 1; }
    update_arg PS_CHECKSUM "$checksum"
    ;;

  oras-project/oras)
    asset="oras_${NEW_VERSION}_linux_amd64.tar.gz"
    url="https://github.com/oras-project/oras/releases/download/v${NEW_VERSION}/oras_${NEW_VERSION}_checksums.txt"
    echo "Fetching ORAS ${NEW_VERSION} checksums from ${url} ..."
    checksum="$(curl -fsSL "$url" | extract_checksum "$asset")"
    [ -n "$checksum" ] || { echo "ERROR: no checksum found for '${asset}'" >&2; exit 1; }
    update_arg ORAS_CHECKSUM "$checksum"
    ;;

  *)
    echo "No checksum handler for '${DEP_NAME}'; nothing to do."
    ;;
esac
