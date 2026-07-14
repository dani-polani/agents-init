#!/usr/bin/env bash
# Install as ~/.local/bin/micro (ahead of /usr/bin on PATH).
# micro truecolor is off by default; without this, hex / *-tc themes
# collapse into muddy 256-color approximations.
export MICRO_TRUECOLOR="${MICRO_TRUECOLOR:-1}"
export TCELL_TRUECOLOR="${TCELL_TRUECOLOR:-1}"
exec /usr/bin/micro "$@"
