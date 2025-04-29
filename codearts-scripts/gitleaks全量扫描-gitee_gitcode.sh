#!/bin/bash
set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache

GIT_TOKEN=${GIT_TOKEN}
git config --global diff.renameLimit 2000
git config --global credential.helper manager
/opt/cached_resources/git-credential-manager configure
setGit (){
    if [ "$CODEPLATFORM" == "gitee.com" ]; then
    echo -e "protocol=https\nhost=${CODEPLATFORM}\nusername=${CODE_USERNAME}\npassword=${GITEE_GIT_TOKEN}" | /opt/cached_resources/git-credential-manager store
else
    echo -e "protocol=https\nhost=${CODEPLATFORM}\nusername=${CODE_USERNAME}\npassword=${GITCODE_GIT_TOKEN}" | /opt/cached_resources/git-credential-manager store
fi
}
currenttimestamp=$(date +%s)
CLONE_DIR="/opt/cached_resources/gitleaks/repos"
GITLEAKS_REPORT_DIR="/opt/cached_resources/gitleaks"

mkdir -p "$CLONE_DIR"
mkdir -p "$GITLEAKS_REPORT_DIR"

repos=("https://gitcode.com/openUBMC/software-center" "https://gitcode.com/openFuyao/openfuyao-website-login" "https://gitcode.com/openFuyao/docs" "https://gitcode.com/openFuyao/openfuyao-website" "https://gitee.com/mindspore/mindspore-portal.git" "https://gitee.com/mindspore/website-docs.git" "https://gitee.com/mindspore/xihe-docs.git" "https://gitee.com/mindspore/xihe-website.git" "https://gitee.com/modelers/merlin-blogs.git" "https://gitee.com/modelers/merlin-docs.git" "https://gitee.com/modelers/merlin-website.git" "https://gitee.com/openeuler/cve-manager.git" "https://gitee.com/openeuler/docs.git" "https://gitee.com/openeuler/docs-accompany-reading.git" "https://gitee.com/openeuler/easy-software.git" "https://gitee.com/openeuler/easysoftware-command.git" "https://gitee.com/openeuler/openEuler-portal.git" "https://gitee.com/openeuler/opendesign-datastat.git" "https://gitee.com/openeuler/opendesign-miniprogram.git" "https://gitee.com/openeuler/quick-issue.git" "https://gitee.com/opengauss/blog.git" "https://gitee.com/opengauss/docs.git" "https://gitee.com/opengauss/website.git" "https://gitee.com/openlookeng/website-docs.git" "https://gitee.com/openlookeng/website-v2.git")
if [[ ${#repos[@]} -eq 0 ]]; then
  exit 1
fi
for repo_url in "${repos[@]}"; do
  repo_name=$(basename -s .git "$repo_url")
  org_name=$(echo $repo_url | awk -F'/' '{print $(NF-1)}')
  CODEPLATFORM=$(echo $repo_url | awk -F'/' '{print $3}')
  setGit
  repo_path="$CLONE_DIR/$CODEPLATFORM/${org_name}/$repo_name"
  mkdir -p "$CLONE_DIR/$CODEPLATFORM/${org_name}/$repo_name"
  repoGitPath="${org_name}/${repo_name}"
  if [[ -d "$repo_path" && -n "$(ls -A "$repo_path")" ]]; then
    git -C "$repo_path" pull
  else
    git clone "https://$CODEPLATFORM/${ORG_NAME}/${repo_name}.git"  "$repo_path"
  fi
  remote_url=$(git -C "$repo_path" remote -v | grep '(fetch)' | awk '{print $2}')
  cleaned_repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')
  current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
  sanitizedBranch=$(echo "$current_branch" | tr '/' '@')
  mkdir -p "$GITLEAKS_REPORT_DIR/${cleaned_repo_url}"
  /opt/cached_resources/gitleaks_8.21.2/gitleaks detect --source="$repo_path" --report-path="$GITLEAKS_REPORT_DIR/${cleaned_repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json" --no-banner
done

exit 0

