#!/usr/bin/env bash
# Portable, streaming provisioner: creates secret teams, org memberships, team memberships,
# private repos, and grants team push. No 'read -d' tricks, no jq, no arrays required.
set -e
[[ "${TRACE:-0}" == "1" ]] && set -x

ORG="19CSE352-2025-Even"
ACCEPT="Accept: application/vnd.github+json"
CONTENT="Content-Type: application/json"
DRY_RUN="${DRY_RUN:-0}"
ONLY_TEAMS="${ONLY_TEAMS:-}"   # set to a team name to limit scope

req() { command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'"; exit 1; }; }
req gh

echo "== Auth & role =="
ME="$(gh api user -q .login)"
ROLE="$(gh api "/orgs/${ORG}/memberships/${ME}" -q .role 2>/dev/null || echo "none")"
echo "You: @$ME | Role in $ORG: $ROLE"
[ "$ROLE" = "admin" ] || { echo "ERROR: You must be an org owner (role=admin)"; exit 1; }
echo "DRY_RUN=${DRY_RUN}"
echo

# -------- Helpers --------
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
  # Try to create; if it exists, fetch slug by name.
  local slug
  slug="$(gh api -X POST "/orgs/${ORG}/teams" -H "$ACCEPT" -f name="$name" -f privacy="secret" -q .slug 2>/dev/null || true)"
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
  local team_name="$1"
  shift
  local members=("$@")

  if [ -n "$ONLY_TEAMS" ] && [ "$team_name" != "$ONLY_TEAMS" ]; then
    echo "Skipping team '$team_name' (ONLY_TEAMS set)"
    return 0
  fi

  echo "=== Team: $team_name ==="
  local slug; slug="$(get_team_slug_by_name "$team_name")"
  if [ -z "$slug" ]; then
    slug="$(create_team_and_get_slug "$team_name")" || return 1
  else
    echo "Team exists: slug=$slug"
  fi

  local repo; repo="$(slug_repo "$team_name")"
  create_repo_if_missing "$repo"

  local u
  for u in "${members[@]}"; do
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

# -------- Team block (plain heredoc; no -d tricks) --------
TEAMS=$(cat <<'TEAMS_EOF'
# Class 1-A
Lisha1405
Manz6
Sreelakshmy-S
samyuktha2005
NandiniPadigala

# Straw Hat Pirates
jaidev-12
aneesh1410
avk3011
nandanrajesh
hxrik

# Team 7
Hemanthkumar-20
KrishnaChaitanya-BHAMIDI
PrasadSimhadri
SAKETH116
zeusXtruealpha

# Karasuno Team
ragulkarthick832
skr006
athreya7109
Pradeepkumar2005
kabilanmohan

# Demon Slayer Corps
mukesh1352
rev-sin
SDKeshavan
Siddharth-10-12
Nandhakumar17102004

# Shohoku Squad
CraftsmanSJ
Daniyalahmad07
av7267
Harihar1269
sumanthkumar13

# Fairy Tail Guild
saikarthik8067
sasank06
nishu3904
Udaykirannagam
Guthulagunavardhan

# Survey Corps
gayathrii2
Thanusha-Reddy
Pavithraa77
trishika-2004
Indirasribhashyam

# Gotei 13
Abishekmoorthy
kanishprabakaran
dharunm236
sibivarshan
Saikrishna216

# Ouran Host Club
SurenAdhi
yuvarajayyanar
Praysunraja
vigneshrajak
Darthyeager6703

# Blue Lock Strikers
adithya712
SanyamB0912
dhaminii
mahesh-cuber24
varun2117

# Z Warriors
pavanvishwanatham
harish070705
adi30042005
Amrish993
piratehunter17

# Nekoma Crew
ChennuruSriLahari
Gudena178
mohan3690-coder
karthik0284-K

# Konoha Genin
Revanth704
SaiPranavSoma
Srinedh
dhanvir1331
TEAMS_EOF
)

# -------- Streaming parse & provision --------
current_team=""
current_members=()

# Read TEAMS line by line in a portable way
printf '%s\n' "$TEAMS" | while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    # flush previous
    if [ -n "$current_team" ]; then
      process_team "$current_team" "${current_members[@]}"
      current_members=()
    fi
    current_team="$(echo "$line" | sed -E 's/^#//; s/^[[:space:]]+//; s/[[:space:]]+$//')"
    echo "Found team header: $current_team"
    continue
  fi
  trimmed="$(echo "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$trimmed" ] && continue
  current_members+=("$trimmed")
done

# flush last team
if [ -n "$current_team" ]; then
  process_team "$current_team" "${current_members[@]}"
fi

echo "All done."
