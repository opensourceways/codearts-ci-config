#!/bin/bash
set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache

GITHUB_TOKEN=${GITHUB_TOKEN}
ORG_NAME=${ORG_NAME}
git config --global diff.renameLimit 2000
git config --global credential.helper manager
/opt/cached_resources/git-credential-manager configure
echo -e "protocol=https\\nhost=${CODEPLATFORM}\\nusername=${CODE_USERNAME}\\npassword=${GITHUB_TOKEN}" | /opt/cached_resources/git-credential-manager store
currenttimestamp=$(date +%s)
CLONE_DIR="/opt/cached_resources/gitleaks/repos"
GITLEAKS_REPORT_DIR="/opt/cached_resources/gitleaks/reports/${currenttimestamp}"

mkdir -p "$CLONE_DIR"
mkdir -p "$GITLEAKS_REPORT_DIR"

BASE_URL="https://api.github.com/orgs/$ORG_NAME/repos"
PER_PAGE=100
PAGE=1
repos=()

while :; do
  response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$BASE_URL?per_page=$PER_PAGE&page=$PAGE")
  current_repos=$(echo "$response" | grep '"clone_url"' | cut -d'"' -f4)

  if [[ -z "$current_repos" ]]; then
    break
  fi

  repos+=($current_repos)
  PAGE=$((PAGE + 1))
done

if [[ ${#repos[@]} -eq 0 ]]; then
  exit 1
fi

for repo_url in "${repos[@]}"; do
  repo_name=$(basename -s .git "$repo_url")

  repo_path="$CLONE_DIR/$repo_name"
  if [[ -d "$repo_path" ]]; then
    git -C "$repo_path" pull
  else
    git clone "https://github.com/${ORG_NAME}/${repo_name}.git"  "$repo_path"
  fi

  /opt/cached_resources/gitleaks_8.21.2/gitleaks detect --source="$repo_path" --report-path="$GITLEAKS_REPORT_DIR/$repo_name-gitleaks-report.json" --no-banner
done

exit 0

