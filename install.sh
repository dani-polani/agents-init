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
download COPYRIGHT.md

mv "$temporary_directory/AGENTS.md" ./AGENTS.md
mv "$temporary_directory/CLAUDE.md" ./CLAUDE.md
mv "$temporary_directory/COPYRIGHT.md" ./COPYRIGHT.md

echo "Updated AGENTS.md, CLAUDE.md and COPYRIGHT.md in $(pwd)."

update_command="curl -fsSL $repository_url/install.sh | sh"

if [ -f Makefile ] && grep -q '^update-agentsmd:' Makefile; then
  echo "Makefile already has an update-agentsmd target."
else
  {
    printf '\n.PHONY: update-agentsmd\n'
    printf 'update-agentsmd:\n'
    printf '\t%s\n' "$update_command"
  } >> Makefile
  echo "Added update-agentsmd target to Makefile."
fi
