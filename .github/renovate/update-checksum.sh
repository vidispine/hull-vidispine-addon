#!/usr/bin/env bash
#
# Renovate postUpgradeTask hook.
#
# After Renovate bumps a tracked version, it runs this script (see renovate.json ->
# postUpgradeTasks). The script fetches the official release checksum for the new
# version and writes it into the matching `ARG <NAME>_CHECKSUM=` line of every
# Dockerfile, so the version bump and its checksum land in the SAME pull request.
#
# The point: `docker build` then verifies the download against a checksum that is
# already committed in the repo. It never fetches a checksum live at build time.
#
# Invocation (from renovate.json):
#   bash .github/renovate/update-checksum.sh <depName> <newVersion>
# e.g.
#   bash .github/renovate/update-checksum.sh oras-project/oras 1.3.4
#
# Must be allowlisted for self-hosted Renovate via `allowedCommands`
# (set as RENOVATE_ALLOWED_COMMANDS in .github/workflows/renovate.yml).

set -euo pipefail

DEP_NAME="${1:?usage: update-checksum.sh <depName> <newVersion>}"
NEW_VERSION="${2:?usage: update-checksum.sh <depName> <newVersion>}"

# All Dockerfiles that carry the *_CHECKSUM ARGs (Dockerfile and Dockerfile-noroot).
mapfile -t DOCKERFILES < <(find images -type f -name 'Dockerfile*' | sort)
if [ "${#DOCKERFILES[@]}" -eq 0 ]; then
  echo "ERROR: no Dockerfiles found under images/" >&2
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

# Rewrite `ARG <name>=...` to the new value in every Dockerfile.
update_arg() {
  local arg="$1" value="$2" file
  for file in "${DOCKERFILES[@]}"; do
    if ! grep -qE "^ARG ${arg}=" "$file"; then
      echo "ERROR: '${file}' has no 'ARG ${arg}=' line to update" >&2
      exit 1
    fi
    sed -i -E "s|^(ARG ${arg}=).*$|\\1${value}|" "$file"
    echo "  ${file}: ARG ${arg}=${value}"
  done
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
