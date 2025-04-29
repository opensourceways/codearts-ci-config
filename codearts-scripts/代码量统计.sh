set +e
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
export GCM_CREDENTIAL_STORE=cache
CACHE_DIR=/opt/cached_resources

git config --global diff.renameLimit 2000
git config --global credential.helper manager
${CACHE_DIR}/git-credential-manager configure
currenttimestamp=$(date +%s)
CLONE_DIR="${CACHE_DIR}/gitleaks/repos"
scc_repo_json=/opt/cached_resources/confirmed/scc_repos.json

mkdir -p "$CLONE_DIR"
CODEPLATFORM="github.com"
setGit (){
    if [ "$CODEPLATFORM" == "gitee.com" ]; then
        echo -e "protocol=https\nhost=${CODEPLATFORM}\nusername=${CODE_USERNAME}\npassword=${GITEE_TOKEN}" | /opt/cached_resources/git-credential-manager store
    elif [ "$CODEPLATFORM" == "gitcode.com" ]; then
        echo -e "protocol=https\nhost=${CODEPLATFORM}\nusername=${CODE_USERNAME}\npassword=${GITCODE_TOKEN}" | /opt/cached_resources/git-credential-manager store
    else
        echo -e "protocol=https\\nhost=${CODEPLATFORM}\\nusername=${CODE_USERNAME}\\npassword=${GITHUB_TOKEN}" | ${CACHE_DIR}/git-credential-manager store
    fi
}
setGit
result_list="[]"
array_length=$(${CACHE_DIR}/jq-linux-amd64 length ${scc_repo_json})
# 遍历 JSON 数组
for ((i=0; i<array_length; i++)); do
  # 提取每个元素的字段
  branch=$(${CACHE_DIR}/jq-linux-amd64 -r ".[$i].branch" "$scc_repo_json")
  CODEPLATFORM=$(${CACHE_DIR}/jq-linux-amd64 -r ".[$i].codeplatform" "$scc_repo_json")
  reponame=$(${CACHE_DIR}/jq-linux-amd64 -r ".[$i].reponame" "$scc_repo_json")
  org_name=$(echo "$reponame" | cut -d '/' -f 1)
  repo_name=$(echo "$reponame" | cut -d '/' -f 2)
  # 构建 GitHub 仓库 URL
  repo_url="https://$CODEPLATFORM/${reponame}.git"
  ${CACHE_DIR}/git-credential-manager erase
  setGit
  # 克隆仓库并获取代码统计信息
  if [ "$CODEPLATFORM" == "github.com" ]; then
    # 构建 GitHub 仓库 URL
    repo_path="$CLONE_DIR/$repo_name"
    echo "Cloning from GitHub: $repo_url"
  else
    # 对于非 GitHub 平台，使用 repo_path 格式
    repo_path="$CLONE_DIR/$CODEPLATFORM/$org_name/$repo_name"
    echo "Cloning from non-GitHub platform: $repo_path"
  fi
  repoGitPath="${org_name}/${repo_name}"

  if [[ -d "$repo_path" ]]; then
    cd $repo_path
    git remote prune origin
    git -C "$repo_path" pull
  else
    git clone $repo_url  "$repo_path"
  fi
  cd $repo_path
  git reset --hard
  git checkout origin/$branch
  git -C "$repo_path" pull
  # 运行 scc 并获取 JSON 结果
  scc_result=$(${CACHE_DIR}/scc --format txt "$repo_path")
  total_info=$(echo "$scc_result" | grep "Total" | awk '{print $2, $3, $4, $5, $6}')
  files=$(echo "$total_info" | awk '{print $1}')
  total_lines=$(echo "$total_info" | awk '{print $2}')
  blank_lines=$(echo "$total_info" | awk '{print $3}')
  comment_lines=$(echo "$total_info" | awk '{print $4}')
  code_lines=$(echo "$total_info" | awk '{print $5}')


  # 创建新的 JSON 对象并将其添加到结果列表中
  result_list=$(echo "$result_list" | ${CACHE_DIR}/jq-linux-amd64 \
    --arg branch "$branch" \
    --arg codeplatform "$CODEPLATFORM" \
    --arg reponame "$reponame" \
    --arg org_name "$org_name" \
    --arg repo_name "$repo_name" \
    --arg lines "$total_info" \
    --arg total_lines "$total_lines" \
    --arg scc_result "$scc_result" '
    . + [{
      branch: $branch,
      codeplatform: $codeplatform,
      reponame: $reponame,
      total_lines: $total_lines,
      code_stats: {lines: $lines, org_name: $org_name, repo_name: $repo_name},
      detailStat: $scc_result
    }]
  ')
done

# 输出最终生成的 JSON 列表到文件
echo "$result_list" > ${CACHE_DIR}/repo_scc_codestat.json