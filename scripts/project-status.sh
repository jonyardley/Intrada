#!/usr/bin/env bash
# Move an issue's Status on the project board (view 7), so in-flight work
# actually shows as in-flight instead of sitting in Backlog until it closes.
# Nothing in the claim/ship workflow moved this field automatically (#1660).

set -euo pipefail

project_owner="jonyardley"
project_number=2
project_id="PVT_kwHOAAr6vs4A1_pq"
status_field_id="PVTSSF_lAHOAAr6vs4A1_pqzgrX99A"
repo="jonyardley/intrada"

usage() {
  echo "Usage: $0 <issue-number> <Backlog|Ready|In progress|In review|Done>" >&2
  exit 1
}

[ $# -eq 2 ] || usage
issue_number="$1"
status_name="$2"

case "$status_name" in
Backlog) option_id="f75ad846" ;;
Ready) option_id="61e4505c" ;;
"In progress") option_id="47fc9ee4" ;;
"In review") option_id="df73e18b" ;;
Done) option_id="98236657" ;;
*) usage ;;
esac

command -v gh >/dev/null 2>&1 || {
  echo "gh is required" >&2
  exit 1
}

item_id=$(gh project item-add "$project_number" --owner "$project_owner" \
  --url "https://github.com/$repo/issues/$issue_number" \
  --format json -q .id)

gh project item-edit --id "$item_id" --project-id "$project_id" \
  --field-id "$status_field_id" --single-select-option-id "$option_id" >/dev/null

echo "issue #$issue_number -> $status_name"
