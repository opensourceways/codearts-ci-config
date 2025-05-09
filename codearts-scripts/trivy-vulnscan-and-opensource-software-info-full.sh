set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache
CACHE_DIR=/opt/cached_resources
WORKDIR=${CACHE_DIR}/sast
export GOROOT=${WORKDIR}/go
export GOPATH=${WORKDIR}/gopath
export JAVA_HOME=$WORKDIR/jdk18
export NODE_HOME=${CACHE_DIR}/node-v16.17.0-linux-x64
export PATH=$NODE_HOME/bin:$GOPATH/bin:$GOROOT/bin:$JAVA_HOME/bin:$PATH

git config --global diff.renameLimit 2000
git config --global credential.helper manager
${CACHE_DIR}/git-credential-manager configure
currenttimestamp=$(date +%s)
CLONE_DIR="${CACHE_DIR}/gitleaks/repos"

mkdir -p "$CLONE_DIR"

setGit (){
 echo -e "protocol=https\\nhost=${CODEPLATFORM}\\nusername=${CODE_USERNAME}\\npassword=${GITHUB_TOKEN}" | ${CACHE_DIR}/git-credential-manager store
}

BASE_URL="https://api.github.com/orgs/$ORG_NAME/repos"
PER_PAGE=100
PAGE=1
repos=()

while :; do
  response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$BASE_URL?per_page=$PER_PAGE&page=$PAGE")
  current_repos=$(echo "$response" | ${CACHE_DIR}/jq-linux-amd64 -r '.[] | .clone_url')
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
  ${CACHE_DIR}/git-credential-manager erase
  setGit
  repo_name=$(basename -s .git "$repo_url")

  repo_path="$CLONE_DIR/$repo_name"
  repoGitPath="${ORG_NAME}/${repo_name}"

  cd $repo_path
  if [[ -d "$repo_path" && -n "$(ls -A "$repo_path")" ]]; then
    git remote prune origin
    git fetch origin --prune
  else
    git clone "https://github.com/$repoGitPath.git"  "$repo_path"
  fi

  current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
  json_file="${CACHE_DIR}/confirmed/repo_analyze_branches.json"

  branches=$(${CACHE_DIR}/jq-linux-amd64 -r --arg repo "$repoGitPath" '.[] | select(.full_name == $repo) | .merged_refs' "$json_file")

  branches_array=$(echo "$branches" | ${CACHE_DIR}/jq-linux-amd64 -r '.[]')
  if [ -z "$branches_array" ]; then
    branches_array=$current_branch
  fi

  cd $repo_path
  git fetch origin
  git fetch --all
  git branch -r
  for branch in $branches_array; do
    echo "Checking out: $branch"
    git reset --hard
    git checkout "$branch"
    git reset --hard
    git -C "$repo_path" pull --force
    current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    sanitizedBranch=$(echo "$current_branch" | tr '/' '@')
    remote_url=$(git -C "$repo_path" remote -v | grep '(fetch)' | awk '{print $2}')
    cleaned_repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')
    mkdir -p ${CACHE_DIR}/trivy_db/results/${cleaned_repo_url}
    ${CACHE_DIR}/trivy_db/bin/trivy fs --severity HIGH,CRITICAL,MEDIUM,LOW,UNKNOWN  --config ${CACHE_DIR}/trivy_db/trivy.yaml --cache-dir ${CACHE_DIR}/trivy_db  --scanners vuln,secret --format json --output ${CACHE_DIR}/trivy_db/results/${cleaned_repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json $repo_path
  done
done

