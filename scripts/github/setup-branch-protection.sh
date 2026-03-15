#!/usr/bin/env bash
set -euo pipefail

echo "--------------------------------------"
echo " OpenClaw Control Plane"
echo " Branch Protection Setup"
echo "--------------------------------------"

# 检查 gh 登录
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI 未登录"
  echo "运行: gh auth login"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

OWNER=$(echo "$REPO" | cut -d/ -f1)
NAME=$(echo "$REPO" | cut -d/ -f2)

echo "Repository: $REPO"
echo

echo "Applying protection to main branch..."

gh api \
  repos/$OWNER/$NAME/branches/main/protection \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

echo "Main branch protected."

echo
echo "Applying minimal protection to dev branch..."

gh api \
  repos/$OWNER/$NAME/branches/dev/protection \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": true,
  "allow_deletions": false
}
EOF

echo "Dev branch configured."

echo
echo "Branch protection complete."

echo
echo "Verification:"
gh api repos/$OWNER/$NAME/branches/main/protection \
  --jq '.required_pull_request_reviews.required_approving_review_count'

echo
echo "Done."
