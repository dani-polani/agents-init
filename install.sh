#!/bin/sh
set -eu

repository_url="https://raw.githubusercontent.com/dani-polani/agents-init/main"
temporary_directory=$(mktemp -d)

cleanup() {
  rm -rf "$temporary_directory"
}

trap cleanup EXIT HUP INT TERM

download() {
  file_name=$1
  destination="$temporary_directory/$file_name"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "$repository_url/$file_name" --output "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document="$destination" "$repository_url/$file_name"
  else
    echo "Error: curl or wget is required." >&2
    exit 1
  fi
}

download AGENTS.md
download CLAUDE.md

mv "$temporary_directory/AGENTS.md" ./AGENTS.md
mv "$temporary_directory/CLAUDE.md" ./CLAUDE.md

echo "Updated AGENTS.md and CLAUDE.md in $(pwd)."
