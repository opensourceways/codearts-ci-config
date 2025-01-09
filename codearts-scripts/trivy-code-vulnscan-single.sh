# 关闭脚本中的自动退出机制 (set +e)
set +e

# 要扫描的路径或镜像名称
SCAN_TARGET="."
MAX_RETRIES=10  # 最大重试次数
RETRY_COUNT=0   # 当前重试次数
DEFAULT_RETRY_TIME=1  # 每次重试等待的默认时间（秒）
# 使用 sed 替换 '/' 为 '@'
sanitizedBranch=$(echo "$codeBranch" | tr '/' '@')

# 获取 fetch 的仓库地址
remote_url=$(git remote -v | grep '(fetch)' | awk '{print $2}')

# 去除 .git、ssh@、https://、http://
repoName=$(echo "$remote_url" | sed 's|https://github.com/||' | sed 's|.git$||')
cleaned_repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')

# 将清理后的结果赋值给变量
echo "Cleaned URL: $cleaned_repo_url"

# 尝试下载漏洞数据库并执行扫描
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Starting Trivy scan, attempt #$((RETRY_COUNT + 1))..."
  mkdir -p /opt/cached_resources/trivy_db/results/${cleaned_repo_url}/
  /opt/cached_resources/trivy_db/bin/trivy fs --severity HIGH,CRITICAL,MEDIUM,LOW,UNKNOWN  --config /opt/cached_resources/trivy_db/trivy.yaml --cache-dir /opt/cached_resources/trivy_db  --scanners vuln,secret --format json --output /opt/cached_resources/trivy_db/results/${cleaned_repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json $SCAN_TARGET

  # 判断 trivy 执行是否成功
  if [ $? -eq 0 ]; then
      echo "Trivy scan completed successfully."
      break
  fi
  # 增加重试次数
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Trivy scan failed. Retrying scan ($RETRY_COUNT/$MAX_RETRIES)..."

  # 如果执行失败，可以选择等待一段时间再重试
  sleep $DEFAULT_RETRY_TIME

done

# 检查是否达到最大重试次数
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Trivy scan failed after $MAX_RETRIES attempts."
    exit 1
fi

# 检查漏洞数量
cat << 'EOF' > check_vulnerabilities.py
import json
import sys

# 检查是否提供了文件路径作为命令行参数
if len(sys.argv) < 4:
    print("Usage: python check_vulnerabilities.py <json_file_path>")
    sys.exit(1)

# 从命令行获取 JSON 文件路径
json_file_path = sys.argv[1]
json_putOnRecord_file_path = sys.argv[2]
repoName = sys.argv[3]

# 加载 JSON 文件，指定编码为 utf-8
try:
    with open(json_file_path, encoding='utf-8') as f:
        data = json.load(f)
except UnicodeDecodeError:
    print(f"Error: Failed to decode the file '{json_file_path}'. Please check the file encoding.")
    sys.exit(1)
try:
    with open(json_putOnRecord_file_path, encoding='utf-8') as f:
        putOnRecordData = json.load(f)
except UnicodeDecodeError:
    print(f"Error: Failed to decode the file '{json_file_path}'. Please check the file encoding.")
    sys.exit(1)

cnt = 0
putOnRecordCnt = 0


def findPutOnRecord(vulnerabilityId, repoName, pkgName):
    for putOnRecordDataItem in putOnRecordData:
        if putOnRecordDataItem["VulnerabilityID"] == vulnerabilityId and putOnRecordDataItem[
            "full_name"] == repoName and putOnRecordDataItem["PkgName"] == pkgName:
            return True
    return False


# 遍历数据并筛选出直接依赖且有漏洞的包
for result in data['Results']:
    if 'Packages' not in result:
        continue  # 如果没有 Packages 字段，则跳过这个条目
    for package in result['Packages']:
        if package.get('Relationship') == 'direct' and 'Vulnerabilities' in result:
            package_name = package['Name']
            vulnerabilities = result['Vulnerabilities']
            for vulnerability in vulnerabilities:
                if vulnerability['PkgName'] == package_name:
                    # 输出有漏洞的直接依赖包
                    if not findPutOnRecord(vulnerability["VulnerabilityID"], repoName, package_name):
                        cnt += 1
                        print(f"Direct Dependency: {package['ID']} Vulnerabilities: ", end="")
                        print(json.dumps(vulnerability, indent=4))
                    else:
                        print(f"PutOnRecord Direct Dependency: {package['ID']} Vulnerabilities: ", end="")
                        print(json.dumps(vulnerability, indent=4))
                        putOnRecordCnt += 1
                    print()  # 换

print(f"{putOnRecordCnt} 已备案 vulnerabilities found.")
if cnt > 0:
    print(f"{cnt} vulnerabilities found.")
    sys.exit(cnt)
else:
    print(f"No vulnerabilities found.")
    sys.exit(0)
EOF

python3 check_vulnerabilities.py /opt/cached_resources/trivy_db/results/${cleaned_repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json /opt/cached_resources/confirmed/repo_putOnRecord_dependencies.json $repoName
