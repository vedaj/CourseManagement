# CourseManagement

Tools I use to wrangle course logistics and GitHub housekeeping for my students. If you’re in academia and this helps, steal it shamelessly — remix as needed. I built it for my workflow; you’ll probably want to tweak a few knobs. It probably works; if it doesn’t, it’s probably my fault.

---

## `teamCreation.sh`

A fast, portable shell script I use for CS courses at the School of Computing @ Amrita. Feed it a pre‑sorted CSV (`team_name,student_name,github_username`) and it will:

- Create (or reuse) a secret GitHub team in your org,
- Invite each student to the org,
- Add them to the team,
- Create (or reuse) a private repo named after the team (slugged), and
- Grant the team push access to that repo.

Everything goes through `gh api`. The run is idempotent.&#x20;

---

## Prerequisites

- You’re an owner of the target GitHub organization. This script is allergic to half‑permissions.
- Install & auth the GitHub CLI:
  ```bash
  gh auth login
  gh auth status
  ```
- If your org uses SSO, authorize your token for the org with scopes: `admin:org`, `repo`.

---

## CSV format

Header is required and rows must be sorted by `team_name`.

```csv
team_name,student_name,github_username
Avengers,Tony Stark,tony_stark
Avengers, Natasha Romanoff,n_romanoff
Jedi,Luke Skywalker,luke_skywalker
Jedi,Obi-Wan Kenobi,obi_kenobi
```

- `student_name` is for humans; the script only trusts `github_username`.
- If `github_username` is blank, the row is skipped a warning and mild disappointment.

---

## What it creates (per team)

- **Team**: privacy = `secret` (not visible to non‑members).
- **Repository**: private, initialized with a README.
  - Repo name = slugified team name (lowercase, non‑alphanumerics become `-`).
  - Example: “The Galactic Republic” → `the-galactic-republic`.
- **Access**: team gets push permission on its repo.
- **Memberships**: students are invited to the org and added to the team.
  - Students must accept the org invite before they can see or push to private repos.

---

## Quick start

```bash
# Set your org (defaults to 23CSE101-2025-Odd)
export ORG=23CSE101-2025-Odd

# Make executable and run
chmod +x teamCreation.sh
./teamCreation.sh /path/to/roster.csv
```

### Handy env vars

- `ORG` — target organization (default: `23CSE101-2025-Odd`)
- `ONLY_TEAMS` — run for a single team (exact match). Example:
  ```bash
  ONLY_TEAMS="The Galactic Republic" ./teamCreation.sh roster.csv
  ```
- `DRY_RUN=1` — print the `gh api` calls without executing them.
- `TRACE=1` — shell trace for debugging (`set -x`). Bring your own caffeine.

---

## Verify

```bash
# List teams
gh api /orgs/$ORG/teams?per_page=100 -q '.[].name'

# List repos
gh api /orgs/$ORG/repos?per_page=100 -q '.[].name'
```

---

## Notes & caveats

- **Idempotent**: re-running won’t duplicate anything; it reconciles teams, repos, and memberships.&#x20;
- **Invalid usernames**: if a `github_username` doesn’t exist or is misspelled, you’ll get a WARN and the run continues.
- **Branch protection**: not enabled by default. Add a small `gh api` block if you want PRs required, minimum reviewers, or to block force‑push. (Yes, you should.)
- **Cleanup (careful!)**
  ```bash
  # Delete a team
  gh api -X DELETE /orgs/$ORG/teams/<team-slug>

  # Delete a repo
  gh api -X DELETE /repos/$ORG/<repo-name>
  ```

---

## Why sorted CSV?

The script streams the file and “flushes” a team when the team name changes. Sorting keeps each team together so the script stays simple, fast, and disinterested in parsing chaos.

---

## License

Creative Commons Zero v1.0 Universal (CC0-1.0). In short: use it however you like. If you make it better, I will absolutely pretend I had the idea first lol. 

