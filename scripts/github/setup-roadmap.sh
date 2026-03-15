#!/usr/bin/env bash
set -euo pipefail

echo "--------------------------------------"
echo " OpenClaw AI OS Roadmap Setup"
echo "--------------------------------------"

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh 未登录"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER=$(echo "$REPO" | cut -d/ -f1)
NAME=$(echo "$REPO" | cut -d/ -f2)

echo "Repository: $REPO"
echo

########################################
echo "Creating labels..."

create_label () {
  gh label create "$1" \
    --color "$2" \
    --description "$3" \
    --repo "$REPO" \
    2>/dev/null || true
}

create_label roadmap f29513 "Roadmap item"
create_label infra 5319e7 "Infrastructure"
create_label agent 1d76db "Agent system"
create_label memory 0e8a16 "Memory system"
create_label tooling a2eeef "Tooling"
create_label evaluation d4c5f9 "Evaluation"
create_label bug d73a4a "Bug"
create_label enhancement a2eeef "Enhancement"

echo "Labels ready."

########################################
echo
echo "Creating milestones..."

create_milestone () {
  gh api repos/$OWNER/$NAME/milestones \
    -f title="$1" \
    -f description="$2" \
    -f state="open" \
    2>/dev/null || true
}

create_milestone "Phase 1 - Core AI Infrastructure" \
"LiteLLM + OpenClaw runtime foundation"

create_milestone "Phase 2 - Memory System" \
"Mem0 + governance layer"

create_milestone "Phase 3 - Tool System" \
"MCP + automation tools"

create_milestone "Phase 4 - Multi-Agent Organization" \
"Agent collaboration and governance"

echo "Milestones ready."

########################################
echo
echo "Creating roadmap issues..."

create_issue () {
  gh issue create \
    --title "$1" \
    --body "$2" \
    --label roadmap \
    --milestone "$3" \
    --repo "$REPO" \
    2>/dev/null || true
}

create_issue \
"Deploy LiteLLM Gateway (Mac)" \
"Deploy local LiteLLM gateway for model routing." \
"Phase 1 - Core AI Infrastructure"

create_issue \
"Deploy LiteLLM Gateway (GCP)" \
"Deploy cloud LiteLLM gateway for global routing." \
"Phase 1 - Core AI Infrastructure"

create_issue \
"Integrate OpenClaw with LiteLLM" \
"Route all model calls through LiteLLM." \
"Phase 1 - Core AI Infrastructure"

create_issue \
"Implement memory layer (mem0)" \
"Deploy long-term semantic memory." \
"Phase 2 - Memory System"

create_issue \
"Implement MCP tool server" \
"Expose tool APIs for agents." \
"Phase 3 - Tool System"

create_issue \
"Enable multi-agent orchestration" \
"Chief + worker agent collaboration." \
"Phase 4 - Multi-Agent Organization"

echo "Issues ready."

########################################
echo
echo "Creating GitHub Project..."

OWNER_ID=$(gh api graphql -f query='
query {
  viewer {
    id
  }
}
' --jq '.data.viewer.id')

PROJECT_TITLE="AI OS Roadmap"

gh api graphql -f query="
mutation {
  createProjectV2(input:{
    ownerId:\"$OWNER_ID\",
    title:\"$PROJECT_TITLE\"
  }) {
    projectV2 {
      id
      title
    }
  }
}
" 2>/dev/null || true

echo "Project created (or already exists)."

echo
echo "Roadmap initialization complete."
