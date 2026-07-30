#!/bin/sh
set -eu

repository_url="https://raw.githubusercontent.com/dani-polani/agents-init/main"
temporary_directory=$(mktemp -d)

cleanup() {
  rm -rf "$temporary_directory"
}

trap cleanup EXIT HUP INT TERM

download() {
  source_path=$1
  destination="$temporary_directory/$(basename "$source_path")"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "$repository_url/$source_path" --output "$destination"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document="$destination" "$repository_url/$source_path"
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

obsidian_workflow_file=".agents/tools/obsidian-tasks.md"

update_project_tasks_section() {
  project_name=$(sed -n 's/^\*\*Project name:\*\* `\(.*\)`$/\1/p' PROJECT.md | head -n 1)

  if [ -z "$project_name" ]; then
    echo "Error: PROJECT.md has a '## Tasks' section but no '**Project name:**' line. Run the init-obsidian-tasks skill." >&2
    exit 1
  fi

  download skills/init-obsidian-tasks/assets/PROJECT.md

  awk -v name="$project_name" '
    function render(line,   out, position) {
      out = ""
      while ((position = index(line, "<PROJECT>")) > 0) {
        out = out substr(line, 1, position - 1) name
        line = substr(line, position + length("<PROJECT>"))
      }
      return out line
    }
    /^## Tasks$/ { in_section = 1 }
    in_section { print render($0) }
  ' "$temporary_directory/PROJECT.md" > "$temporary_directory/tasks-section"

  : > "$temporary_directory/before-tasks"
  : > "$temporary_directory/after-tasks"

  awk -v before="$temporary_directory/before-tasks" -v after="$temporary_directory/after-tasks" '
    /^## Tasks$/ && !seen { seen = 1; in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    !seen { print > before }
    seen && !in_section { print > after }
  ' PROJECT.md

  {
    cat "$temporary_directory/before-tasks"
    cat "$temporary_directory/tasks-section"
    if [ -s "$temporary_directory/after-tasks" ]; then
      printf '\n'
      cat "$temporary_directory/after-tasks"
    fi
  } > "$temporary_directory/rendered-project"

  mv "$temporary_directory/rendered-project" ./PROJECT.md
  echo "Updated the '## Tasks' section of PROJECT.md (project name: $project_name)."
}

if [ -f "$obsidian_workflow_file" ]; then
  download skills/init-obsidian-tasks/assets/obsidian-tasks.md
  mv "$temporary_directory/obsidian-tasks.md" "$obsidian_workflow_file"
  echo "Updated $obsidian_workflow_file."

  if [ -f PROJECT.md ] && grep -q '^## Tasks$' PROJECT.md; then
    update_project_tasks_section
  fi
fi

update_command="curl -fsSL $repository_url/install.sh | sh"

if [ -f Makefile ] && grep -q '^agentsmd:' Makefile; then
  echo "Makefile already has an agentsmd target."
else
  {
    printf '\n.PHONY: agentsmd\n'
    printf 'agentsmd:\n'
    printf '\t%s\n' "$update_command"
  } >> Makefile
  echo "Added agentsmd target to Makefile."
fi
