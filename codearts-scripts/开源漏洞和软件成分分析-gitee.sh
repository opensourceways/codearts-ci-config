set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache
CACHE_DIR=/opt/cached_resources

git config --global diff.renameLimit 2000
git config --global credential.helper manager
${CACHE_DIR}/git-credential-manager configure
currenttimestamp=$(date +%s)
CLONE_DIR="${CACHE_DIR}/gitleaks/repos"

mkdir -p "$CLONE_DIR"

setGit (){
 echo -e "protocol=https\\nhost=${CODEPLATFORM}\\nusername=${CODE_USERNAME}\\npassword=${GIT_TOKEN}" | ${CACHE_DIR}/git-credential-manager store
}
repos=("https://gitee.com/mindspore/mindspore-portal.git" "https://gitee.com/mindspore/website-docs.git" "https://gitee.com/mindspore/xihe-docs.git" "https://gitee.com/mindspore/xihe-website.git" "https://gitee.com/modelers/merlin-blogs.git" "https://gitee.com/modelers/merlin-docs.git" "https://gitee.com/modelers/merlin-website.git" "https://gitee.com/openeuler/cve-manager.git" "https://gitee.com/openeuler/docs.git" "https://gitee.com/openeuler/docs-accompany-reading.git" "https://gitee.com/openeuler/easy-software.git" "https://gitee.com/openeuler/easysoftware-command.git" "https://gitee.com/openeuler/openEuler-portal.git" "https://gitee.com/openeuler/opendesign-datastat.git" "https://gitee.com/openeuler/opendesign-miniprogram.git" "https://gitee.com/openeuler/quick-issue.git" "https://gitee.com/opengauss/blog.git" "https://gitee.com/opengauss/docs.git" "https://gitee.com/opengauss/website.git" "https://gitee.com/openlookeng/website-docs.git" "https://gitee.com/openlookeng/website-v2.git")
if [[ ${#repos[@]} -eq 0 ]]; then
  exit 1
fi

for repo_url in "${repos[@]}"; do
  ${CACHE_DIR}/git-credential-manager erase
  setGit
  repo_name=$(basename -s .git "$repo_url")
  org_name=$(echo $repo_url | awk -F'/' '{print $(NF-1)}')
  CODEPLATFORM=$(echo $repo_url | awk -F'/' '{print $3}')
  repo_path="$CLONE_DIR/$CODEPLATFORM/${org_name}/$repo_name"
  repoGitPath="${org_name}/${repo_name}"

  if [[ -d "$repo_path" ]]; then
    git remote prune origin
    git -C "$repo_path" pull
  else
    git clone $repo_url  "$repo_path"
  fi

  current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
  json_file="${CACHE_DIR}/confirmed/repo_analyze_branches.json"

  branches=$(${CACHE_DIR}/jq-linux-amd64 -r --arg repo "$repoGitPath" '.[] | select(.full_name == $repo) | .merged_refs' "$json_file")

  branches_array=$(echo "$branches" | ${CACHE_DIR}/jq-linux-amd64 -r '.[]')
  if [ -z "$branches_array" ]; then
    branches_array=$current_branch
  fi

  cd $repo_path
  git fetch --all
  git branch -r
  for branch in $branches_array; do
    echo "Checking out: $branch"
    git reset --hard
    git checkout "$branch"
    git -C "$repo_path" pull
    current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    sanitizedBranch=$(echo "$current_branch" | tr '/' '@')
    remote_url=$(git -C "$repo_path" remote -v | grep '(fetch)' | awk '{print $2}')
    cleaned_repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')
    mkdir -p ${CACHE_DIR}/trivy_db/results/${cleaned_repo_url}
    ${CACHE_DIR}/trivy_db/bin/trivy fs --severity HIGH,CRITICAL,MEDIUM,LOW,UNKNOWN  --config ${CACHE_DIR}/trivy_db/trivy.yaml --cache-dir ${CACHE_DIR}/trivy_db  --scanners vuln,secret --format json --output ${CACHE_DIR}/trivy_db/results/${cleaned_repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json $repo_path
  done
done

