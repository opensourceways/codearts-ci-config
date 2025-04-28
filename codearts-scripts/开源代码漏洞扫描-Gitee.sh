curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.56.2

which trivy

# 关闭脚本中的自动退出机制 (set +e)
set +e


# 要扫描的路径或镜像名称
SCAN_TARGET="."
MAX_RETRIES=10  # 最大重试次数
RETRY_COUNT=0   # 当前重试次数
DEFAULT_RETRY_TIME=1  # 每次重试等待的默认时间（秒）

# 尝试下载漏洞数据库并执行扫描
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Starting Trivy scan, attempt #$((RETRY_COUNT + 1))..."

  # 执行 Trivy 并捕获退出状态码
  trivy fs --severity HIGH,CRITICAL --format json --output result.json $SCAN_TARGET

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

# 使用 grep 查找高危 (HIGH) 或致命 (CRITICAL) 漏洞
HIGH_CRITICAL_COUNT=$(grep -E '"Severity": "(HIGH|CRITICAL)"' result.json | wc -l)

# 检查漏洞数量
if [ "$HIGH_CRITICAL_COUNT" -eq 0 ]; then
    echo "No high or critical vulnerabilities found in the scanned target."
    exit 0
else
    echo "$HIGH_CRITICAL_COUNT High or critical vulnerabilities found: "
    grep -E '"Severity": "(HIGH|CRITICAL)"' -B 30 -A 30 result.json  # 显示漏洞详情
    cat result.json
    exit 1  # 返回非零值表示找到高危或致命漏洞
fi