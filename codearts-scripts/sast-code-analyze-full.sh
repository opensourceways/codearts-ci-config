#!/bin/bash
set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache
WORKDIR=/opt/cached_resources/sast
CACHE_DIR=/opt/cached_resources
SPOTBUGS_HOME=/opt/cached_resources/sast/spotbugs-4.7.3
export GOROOT=${WORKDIR}/go
export GOPATH=${WORKDIR}/gopath
export JAVA_HOME=$WORKDIR/jdk18
export PATH=$GOPATH/bin:$GOROOT/bin:$JAVA_HOME/bin:$PATH
pip3 install bandit
check_java() {
    if ! command -v /opt/cached_resources/sast/jdk18/bin/java &> /dev/null; then
        exit 1
    fi
}
has_python_files() {
    local dir="$1"
    if find "$dir" -type f -name "*.py" | grep -q .; then
        return 0
    else
        return 1
    fi
}
run_analysis_Go() {
    local cleaned_repo_url="${1:-default_repo}"
    local sanitizedBranch="${2:-default_branch}"
    ls -l ./
    REPORT_DIR="$WORKDIR/gosec-report"
    $WORKDIR/gopath/bin/gosec -fmt=json -out=$REPORT_DIR/${cleaned_repo_url}/results-${sanitizedBranch}-${TIMESTAMP}.json -stdout -verbose=text ./...
}

run_analysis_Java() {
    local cleaned_repo_url="${1:-default_repo}"
    local sanitizedBranch="${2:-default_branch}"

    $WORKDIR/apache-maven-3.9.6/bin/mvn clean compile -Dmaven.test.skip
    ls -l ./
    REPORT_DIR="$WORKDIR/spotbugs-report"

    $WORKDIR/jdk18/bin/java -jar "$SPOTBUGS_HOME/lib/spotbugs.jar" \
        -textui \
        -pluginList "$SPOTBUGS_HOME/plugin/findsecbugs-plugin.jar" \
        -effort:max \
        -include $SPOTBUGS_HOME/plugin/include-filter.xml \
        -xml \
        -output "$REPORT_DIR/${cleaned_repo_url}/findsecbugs-report-${sanitizedBranch}-${TIMESTAMP}.xml" \
        "./target/classes"
}

run_analysis_Python (){
    local cleaned_repo_url="${1:-default_repo}"
    local sanitizedBranch="${2:-default_branch}"
    REPORT_DIR="$WORKDIR/bandit-report"
    mkdir -p "$REPORT_DIR/${cleaned_repo_url}"
    bandit -r "./" -f json -o "$REPORT_DIR/${cleaned_repo_url}/bandit-report-${sanitizedBranch}-${TIMESTAMP}.json"
}


GITHUB_TOKEN=${GITHUB_TOKEN}
ORG_NAME=${ORG_NAME}
git config --global diff.renameLimit 2000
git config --global credential.helper manager
/opt/cached_resources/git-credential-manager configure
echo -e "protocol=https\\nhost=${CODEPLATFORM}\\nusername=${CODE_USERNAME}\\npassword=${GITHUB_TOKEN}" | /opt/cached_resources/git-credential-manager store
currenttimestamp=$(date +%s)
CLONE_DIR="/opt/cached_resources/gitleaks/repos"

mkdir -p "$CLONE_DIR"

BASE_URL="https://api.github.com/orgs/$ORG_NAME/repos"
PER_PAGE=100
PAGE=1
repos=()

while :; do
  response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "$BASE_URL?per_page=$PER_PAGE&page=$PAGE")
  current_repos=$(echo "$response" | /opt/cached_resources/jq-linux-amd64 -r '.[] | select(.fork == false) | .clone_url')

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
    git remote prune origin
    git -C "$repo_path" pull
  else
    git clone "https://github.com/${ORG_NAME}/${repo_name}.git"  "$repo_path"
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
    if [ -f "./pom.xml" ]; then
        check_java
        run_analysis_Java $cleaned_repo_url $sanitizedBranch
    fi

    if [ -f "./go.mod" ]; then
        run_analysis_Go $cleaned_repo_url $sanitizedBranch
    fi

    if has_python_files "./"; then
        run_analysis_Python $cleaned_repo_url $sanitizedBranch
    fi
  done
done

