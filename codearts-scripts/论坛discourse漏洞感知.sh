#!/bin/bash
set +e
# GitHub Security Advisories API URL
GITHUB_API_URL="https://api.github.com/repos/discourse/discourse/security-advisories?sort=updated_at&direction=desc&per_page=20"

# 本地存储上次最新漏洞时间的文件
mkdir -p /opt/cached_resources/discource
LAST_VULNERABILITY_TIME_FILE="/opt/cached_resources/discource/last_vulnerability_time.txt"

# 获取数据
response=$(curl -s "$GITHUB_API_URL")

# 检查响应是否有效
if [[ -z "$response" || "$response" == *"Not Found"* ]]; then
    echo "Error: Failed to fetch security advisories or invalid data."
    exit 1
fi

# 提取最新漏洞的时间
current_latest_time=$(echo "$response" | /opt/cached_resources/jq-linux-amd64 -r '.[0].updated_at')

# 如果没有找到漏洞
if [ "$current_latest_time" == "null" ]; then
    echo "No vulnerabilities found."
    exit 0
fi

# 转换时间为 UNIX 时间戳进行比较
current_latest_timestamp=$(date -d "$current_latest_time" +%s)

# 如果本地文件不存在，表示第一次运行，初始化文件
if [ ! -f "$LAST_VULNERABILITY_TIME_FILE" ]; then
    echo "$current_latest_timestamp" > "$LAST_VULNERABILITY_TIME_FILE"
    exit 0  # 第一次运行，没有历史记录，退出并返回0
fi
# 转换时间为 UNIX 时间戳进行比较
current_latest_timestamp=$(date -d "$current_latest_time" +%s)

# 如果本地文件不存在，表示第一次运行，初始化文件
if [ ! -f "$LAST_VULNERABILITY_TIME_FILE" ]; then
    echo "$current_latest_timestamp" > "$LAST_VULNERABILITY_TIME_FILE"
    exit 0  # 第一次运行，没有历史记录，退出并返回0
fi

# 从本地文件读取上次的最新漏洞时间（UNIX 时间戳）
last_known_timestamp=$(cat "$LAST_VULNERABILITY_TIME_FILE")

# 初始化一个标志，用于判断是否有新漏洞
new_vulnerabilities_found=false
# 初始化一个空的 JSON 数组来保存新漏洞
new_vulnerabilities=""
# 遍历漏洞数据
for advisory in $(echo "$response" | /opt/cached_resources/jq-linux-amd64 -r '.[] | @base64'); do
    # 解码并提取每个漏洞的时间、ID、URL和严重度
    _jq() {
        echo ${advisory} | base64 --decode | /opt/cached_resources/jq-linux-amd64 -r ${1}
    }

    # 获取每个漏洞的更新时间
    advisory_time=$(_jq '.updated_at')

    # 转换为 UNIX 时间戳
    advisory_timestamp=$(date -d "$advisory_time" +%s)

    # 检查该漏洞是否在上次记录的时间之后发布
    if [ "$advisory_timestamp" -gt "$last_known_timestamp" ]; then
       # 保存新漏洞的详细信息到 JSON 数组
       new_vulnerabilities="${new_vulnerabilities}{\"ghsa_id\": \"$(_jq '.ghsa_id')\", \"html_url\": \"$(_jq '.html_url')\", \"severity\": \"$(_jq '.severity')\", \"updated_at\": \"$advisory_time\"},\n"
          # 设置标志表示发现新漏洞
        new_vulnerabilities_found=true
    else
        # 如果当前漏洞的时间不大于上次记录的时间，则跳出循环
        break
    fi
done

# 如果有新漏洞，更新本地记录的时间为当前最新时间
if [ "$new_vulnerabilities_found" = true ]; then
    echo "$new_vulnerabilities"
    echo "New vulnerabilities found:"
    echo "$current_latest_timestamp" > "$LAST_VULNERABILITY_TIME_FILE"
    exit 1  # 返回 1，表示有新漏洞
else
    echo "No new vulnerabilities found."
    exit 0  # 返回 0，表示没有新漏洞
fi