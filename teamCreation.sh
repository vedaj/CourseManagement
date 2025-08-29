#!/usr/bin/env bash
# Creates secret teams, invites members, adds to teams, creates private repos per team,
# and grants team push — from a CSV: team_name,student_name,github_username
# Portable on macOS default bash (no jq; no process substitution dependencies).

set -e
[[ "${TRACE:-0}" == "1" ]] && set -x

ORG="${ORG:-23CSE101-2025-Odd}"
ACCEPT="Accept: application/vnd.github+json"
CONTENT="Content-Type: application/json"
DRY_RUN="${DRY_RUN:-0}"
ONLY_TEAMS="${ONLY_TEAMS:-}"

CSV="${1:-}"

req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'"; exit 1; }; }
die() { echo "ERROR: $*" >&2; exit 1; }

req gh
[ -n "$CSV" ] || die "Usage: $0 /path/to/roster.csv"
[ -f "$CSV" ] || die "CSV not found: $CSV"

echo "== Auth & role =="
ME="$(gh api user -q .login)"
ROLE="$(gh api "/orgs/${ORG}/memberships/${ME}" -q .role 2>/dev/null || echo "none")"
echo "You: @$ME | Org: $ORG | Role: $ROLE"
[ "$ROLE" = "admin" ] || die "You must be an org owner (role=admin)"
echo "DRY_RUN=${DRY_RUN}"
echo

# -------- Helpers --------
trim() {  # trim leading/trailing spaces
  echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}
unquote() { # strip surrounding double quotes if present
  echo "$1" | sed -E 's/^"(.*)"$/\1/'
}
api() {
  local method="$1"; shift
  local path="$1"; shift
  echo "→ gh api -X $method $path $*"
  [ "$DRY_RUN" = "1" ] && return 0
  gh api -X "$method" "$path" "$@"
}
slug_repo() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
get_team_slug_by_name() {
  local name="$1"
  gh api "/orgs/${ORG}/teams?per_page=100" -H "$ACCEPT" \
    -q ".[] | select(.name==\"$name\") | .slug" 2>/dev/null || true
}
create_team_and_get_slug() {
  local name="$1"
  local slug
  slug="$(gh api -X POST "/orgs/${ORG}/teams" -H "$ACCEPT" \
           -f name="$name" -f privacy="secret" -q .slug 2>/dev/null || true)"
  if [ -z "$slug" ]; then
    slug="$(get_team_slug_by_name "$name")"
    [ -n "$slug" ] || { echo "ERROR: cannot create or find team '$name'"; return 1; }
    echo "Team exists: slug=$slug"
  else
    echo "Team created: slug=$slug"
  fi
  printf '%s\n' "$slug"
}
repo_exists() { gh api "/repos/${ORG}/$1" >/dev/null 2>&1; }
create_repo_if_missing() {
  local repo="$1"
  if repo_exists "$repo"; then
    echo "Repo exists: ${ORG}/${repo}"
  else
    echo "Creating repo: ${ORG}/${repo}"
    api POST "/orgs/${ORG}/repos" -H "$ACCEPT" -H "$CONTENT" \
      --input - <<< "{\"name\":\"${repo}\",\"private\":true,\"auto_init\":true}" >/dev/null
  fi
}
ensure_org_member() {
  local user="$1"
  echo "  org -> @$user"
  api PUT "/orgs/${ORG}/memberships/${user}" -H "$ACCEPT" -H "$CONTENT" \
    --input - <<< '{"role":"member"}' >/dev/null
}
add_user_to_team() {
  local team_slug="$1" user="$2"
  echo "  team $team_slug -> @$user"
  api PUT "/orgs/${ORG}/teams/${team_slug}/memberships/${user}" -H "$ACCEPT" -H "$CONTENT" \
    --input - <<< '{"role":"member"}' >/dev/null
}
grant_team_push_on_repo() {
  local team_slug="$1" repo="$2"
  echo "Grant push: team $team_slug on ${ORG}/${repo}"
  api PUT "/orgs/${ORG}/teams/${team_slug}/repos/${ORG}/${repo}" -H "$ACCEPT" -H "$CONTENT" \
    --input - <<< '{"permission":"push"}' >/dev/null
}

process_team() {
  local team_name="$1"; shift
  [ -n "$team_name" ] || return 0
  if [ -n "$ONLY_TEAMS" ] && [ "$team_name" != "$ONLY_TEAMS" ]; then
    echo "Skipping team '$team_name' (ONLY_TEAMS set)"; return 0
  fi
  echo "=== Team: $team_name ==="
  local slug repo u
  slug="$(get_team_slug_by_name "$team_name")"
  if [ -z "$slug" ]; then
    slug="$(create_team_and_get_slug "$team_name")" || { echo "WARN: skipping team '$team_name'"; return 0; }
  else
    echo "Team exists: slug=$slug"
  fi
  repo="$(slug_repo "$team_name")"
  create_repo_if_missing "$repo"
  for u in "$@"; do
    [ -z "$u" ] && continue
    if ensure_org_member "$u" 2>/dev/null; then
      add_user_to_team "$slug" "$u" 2>/dev/null || echo "  WARN: could not add @$u to team"
    else
      echo "  WARN: could not invite/add @$u to org"
    fi
  done
  grant_team_push_on_repo "$slug" "$repo"
  echo
}

echo "== Reading CSV: $CSV =="
# Read header
header="$(head -n 1 "$CSV" | tr -d '\r')"
case "$header" in
  team_name,student_name,github_username) ;;
  *) die "CSV header must be: team_name,student_name,github_username (got: '$header')" ;;
esac

current_team=""
current_users=()

# Stream over CSV (skip header)
tail -n +2 "$CSV" | while IFS= read -r raw || [ -n "$raw" ]; do
  line="$(echo "$raw" | tr -d '\r')"
  [ -z "$line" ] && continue

  # Split into three columns; ignore extra columns if any
  IFS=',' read -r col_team col_student col_user _rest <<< "$line"

  # Trim & unquote
  team_name="$(unquote "$(trim "$col_team")")"
  # student_name may be unused here, but read for completeness
  # shellcheck disable=SC2034
  student_name="$(unquote "$(trim "$col_student")")"
  github_user="$(unquote "$(trim "$col_user")")"

  # Skip rows missing essentials
  [ -z "$team_name" ] && continue
  [ -z "$github_user" ] && { echo "WARN: missing github_username for team '$team_name' (student: $student_name) — skipping row"; continue; }

  if [ "$team_name" != "$current_team" ]; then
    # flush previous team block
    if [ -n "$current_team" ]; then
      process_team "$current_team" "${current_users[@]}"
      current_users=()
    fi
    current_team="$team_name"
    echo "Found team: $current_team"
  fi

  current_users+=("$github_user")
done

# flush last team
if [ -n "$current_team" ]; then
  process_team "$current_team" "${current_users[@]}"
fi

echo "All done."
