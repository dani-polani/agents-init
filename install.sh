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

linear_workflow_file=".agents/tools/linear-tasks.md"
obsidian_workflow_file=".agents/tools/obsidian-tasks.md"

project_name=""
project_id=""
project_label=""
team_key=""
workspace_id=""

read_project_field() {
  sed -n "s/^\*\*$1:\*\* \`\(.*\)\`\$/\1/p" PROJECT.md | head -n 1
}

require_project_field() {
  value=$(read_project_field "$1")

  if [ -z "$value" ]; then
    echo "Error: PROJECT.md has a '## Tasks' section but no '**$1:**' line. Run the $2 skill." >&2
    exit 1
  fi

  printf '%s' "$value"
}

render_tasks_section() {
  awk -v name="$project_name" -v identifier="$project_id" -v label="$project_label" -v team="$team_key" -v workspace="$workspace_id" '
    function replace(line, from, to,   out, position) {
      out = ""
      while ((position = index(line, from)) > 0) {
        out = out substr(line, 1, position - 1) to
        line = substr(line, position + length(from))
      }
      return out line
    }
    function render(line) {
      line = replace(line, "<PROJECT_ID>", identifier)
      line = replace(line, "<PROJECT_LABEL>", label)
      line = replace(line, "<WORKSPACE>", workspace)
      line = replace(line, "<TEAM>", team)
      line = replace(line, "<PROJECT>", name)
      return line
    }
    /^## Tasks$/ { in_section = 1 }
    in_section { print render($0) }
  ' "$1" > "$temporary_directory/tasks-section"

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
}

has_tasks_section() {
  [ -f PROJECT.md ] && grep -q '^## Tasks$' PROJECT.md
}

if [ -f "$linear_workflow_file" ]; then
  if [ -f "$obsidian_workflow_file" ]; then
    echo "Warning: both linear-tasks.md and obsidian-tasks.md are present; refreshing the Linear workflow only." >&2
  fi

  download skills/init-linear-tasks/assets/linear-tasks.md
  mv "$temporary_directory/linear-tasks.md" "$linear_workflow_file"
  echo "Updated $linear_workflow_file."

  if has_tasks_section; then
    project_name=$(require_project_field "Linear project" init-linear-tasks)
    project_id=$(require_project_field "Project id" init-linear-tasks)
    project_label=$(require_project_field "Project label" init-linear-tasks)
    team_key=$(require_project_field "Default team" init-linear-tasks)
    workspace_id=$(require_project_field "Workspace id" init-linear-tasks)

    download skills/init-linear-tasks/assets/PROJECT.md
    render_tasks_section "$temporary_directory/PROJECT.md"
    echo "Updated the '## Tasks' section of PROJECT.md (Linear project: $project_name)."
  fi
elif [ -f "$obsidian_workflow_file" ]; then
  download skills/init-obsidian-tasks/assets/obsidian-tasks.md
  mv "$temporary_directory/obsidian-tasks.md" "$obsidian_workflow_file"
  echo "Updated $obsidian_workflow_file."

  if has_tasks_section; then
    project_name=$(require_project_field "Project name" init-obsidian-tasks)

    download skills/init-obsidian-tasks/assets/PROJECT.md
    render_tasks_section "$temporary_directory/PROJECT.md"
    echo "Updated the '## Tasks' section of PROJECT.md (project name: $project_name)."
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
