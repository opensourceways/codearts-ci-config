#!/bin/bash
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

# 设置下载链接和文件名
URL="https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz"
TAR_FILE="gitleaks_8.21.2_linux_x64.tar.gz"
TARGET_DIR="gitleaks"
# 下载压缩包
echo "Downloading $TAR_FILE..."
wget $URL -O $TAR_FILE
# 检查下载是否成功
if [ $? -ne 0 ]; then
 echo "Download failed!"
 exit 1
fi
# 解压缩文件
echo "Extracting $TAR_FILE..."
mkdir -p $TARGET_DIR
tar -xzf $TAR_FILE -C $TARGET_DIR
# 检查解压是否成功
if [ $? -ne 0 ]; then
 echo "Extraction failed!"
 exit 1
fi
echo "Gitleaks extracted to $TARGET_DIR."
# 赋予gitleaks可执行权限
chmod +x $TARGET_DIR/gitleaks
echo "Scanning current directory with Gitleaks..."
mkdir -p  /opt/cached_resources/gitleaks/${cleaned__repo_url}
$TARGET_DIR/gitleaks detect --source=repo --verbose --report-path /opt/cached_resources/gitleaks/${cleaned__repo_url}/result-${sanitizedBranch}-${TIMESTAMP}.json


