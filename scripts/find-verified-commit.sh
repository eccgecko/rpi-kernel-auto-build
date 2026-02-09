#!/usr/bin/env bash
#
# find-verified-commit.sh
#
# Finds the latest commit on raspberrypi/linux rpi-6.18.y that has passed
# all CI check-runs. Outputs the full SHA on success, exits 1 if none found.
#
set -euo pipefail

REPO="raspberrypi/linux"
BRANCH="rpi-6.18.y"
COMMITS_TO_CHECK="${1:-20}"

# Fetch recent commits on the branch
commits=$(gh api "repos/${REPO}/commits?sha=${BRANCH}&per_page=${COMMITS_TO_CHECK}" \
    --jq '.[].sha')

for sha in $commits; do
    # Get all check-runs for this commit
    check_runs=$(gh api "repos/${REPO}/commits/${sha}/check-runs" \
        --jq '{total: .total_count, completed: [.check_runs[] | select(.status == "completed" and .conclusion == "success")] | length}')

    total=$(echo "$check_runs" | jq -r '.total')
    completed=$(echo "$check_runs" | jq -r '.completed')

    # Must have at least one check-run, and all must be successful
    if [[ "$total" -gt 0 && "$total" -eq "$completed" ]]; then
        echo "$sha"
        exit 0
    fi
done

echo "No verified commit found in the last ${COMMITS_TO_CHECK} commits" >&2
exit 1
