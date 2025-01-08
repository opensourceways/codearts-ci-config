
#!/bin/bash
set +e
# git clone 仓库
# 获取 fetch 的仓库地址
remote_url=$(git remote -v | grep '(fetch)' | awk '{print $2}')

# 去除 .git、ssh@、https://、http://
cleaned__repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')

# 将清理后的结果赋值给变量
echo "Cleaned URL: $cleaned__repo_url"
# 使用 sed 替换 '/' 为 '@'
sanitizedBranch=$(echo "$codeBranch" | tr '/' '@')

cd ..
rm -rf ${WORKSPACE}/*
cd ${WORKSPACE}



 git clone https://${access_token}@github.com/${owner}/${repo}.git repo

cd repo
# BRANCH_NAME=${codeBranch}
# echo "Switching to branch: $BRANCH_NAME..."
# git checkout $BRANCH_NAME || { echo "Failed to checkout branch: $BRANCH_NAME"; exit 1; }

 git fetch --all
git log --oneline | wc -l

cd ..

echo "Scanning current directory with Gitleaks..."
mkdir -p  /opt/cached_resources/gitleaks/${cleaned__repo_url}
/opt/cached_resources/gitleaks_8.21.2/gitleaks detect --source=repo --verbose --report-path /opt/cached_resources/gitleaks/${cleaned__repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json

cat << 'EOF' > check_gitleaks.py
import json
import sys

# 检查是否提供了文件路径作为命令行参数
if len(sys.argv) < 4:
    print("Usage: python check-gitleaks.py <xx_json_file> <gitleaks_json_file>")
    sys.exit(1)

# 从命令行获取文件路径
fingerprint_file_path = sys.argv[1]
fingerprint_withRepoHint_file_path = sys.argv[2]
gitleaks_file_path = sys.argv[3]
repo_name = sys.argv[4]

#检查是否提供了文件路径作为命令行参数
if len(sys.argv) < 5:
    print("Usage: python check-gitleaks.py <xx_json_file> <gitleaks_json_file>")
    sys.exit(1)

# 加载 JSON 文件
def load_json(file_path):
    """加载 JSON 文件"""
    with open(file_path, 'r', encoding='utf-8') as file:
        return json.load(file)


# 根据 Fingerprint 比较两个 JSON 文件中的数据
def find_matching_fingerprints(fingerprint_data, gitleaks_data, repo_name, cnt):
    """根据 Fingerprint 比较 xx_data 和 gitleaks_data"""
    # 提取 xx.json 中的所有 Fingerprint 字段
    for fingerprint_item in fingerprint_data:
        fingerprint = fingerprint_item['Fingerprint']
        StartColumn = int(fingerprint_item['StartColumn'])
        if repo_name == fingerprint_item['full_name']:
            # 在 gitleaks.json 中查找匹配的 Fingerprint
            for gitleaks_item in gitleaks_data:
                if gitleaks_item['Fingerprint'] == fingerprint and StartColumn == gitleaks_item['StartColumn']:
                    print(f"Solved Gitleaks Found(确认误报、问题已修复（密钥轮转已废弃）): {fingerprint},{StartColumn}")
                    cnt -= 1
    return cnt


# 加载 xx.json 和 gitleaks.json 数据
fingerprint_data = load_json(fingerprint_file_path)
gitleaks_data = load_json(gitleaks_file_path)
gitleaks_WithRepoHintData = load_json(fingerprint_withRepoHint_file_path)
cnt = len(gitleaks_data)

# 查找并打印匹配的 Fingerprint
issuesRemain = find_matching_fingerprints(fingerprint_data, gitleaks_data, repo_name, cnt)
print(
    f"发现{len(gitleaks_data)}个密钥,{len(gitleaks_data) - issuesRemain}个密钥已确认误报或修复，还剩余{issuesRemain}个待解决")


def find_withRepoHint_fingerprints(gitleaks_WithRepoHintData, repo_name):
    filtered_Data = list(filter(lambda hintData: hintData['full_name'] == repo_name, gitleaks_WithRepoHintData))
    print(f"发现{len(filtered_Data)}个密钥在gitRemote已不存在，但可以通过github commitUrl访问，需要删库重建")
    for repoHintData in filtered_Data:
        print(f"密钥和github访问信息：{repoHintData}")
    return len(filtered_Data)


need2DeleteRepoCnt = find_withRepoHint_fingerprints(gitleaks_WithRepoHintData, repo_name)

if need2DeleteRepoCnt == 0 and issuesRemain == 0:
    sys.exit(0)
else:
    sys.exit(1)
EOF

python3 check_gitleaks.py /opt/cached_resources/confirmed/repo_gitleaks_confirmed_fingerprints_startColumn.json  /opt/cached_resources/confirmed/repo_gitleaks_withGitRepoHint_fingerprints_startColumn.json /opt/cached_resources/gitleaks/${cleaned__repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json ${owner}/${repo}
