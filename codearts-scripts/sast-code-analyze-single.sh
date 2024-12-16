set +e
echo 'hello'
#!/bin/bash

# 配置工作目录和工具版本
WORKDIR=/opt/cached_resources/sast
SPOTBUGS_HOME=/opt/cached_resources/sast/spotbugs-4.7.3
# 使用 sed 替换 '/' 为 '@'
sanitizedBranch=$(echo "$codeBranch" | tr '/' '@')

export GOROOT=${WORKDIR}/go
export GOPATH=${WORKDIR}/gopath
export JAVA_HOME=$WORKDIR/jdk18
export PATH=$JAVA_HOME/bin:$PATH
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin


# 检查 Java 环境
check_java() {
    if ! command -v /opt/cached_resources/sast/jdk18/bin/java &> /dev/null; then
        echo "未安装 Java，请先安装 JDK 8 或 11。"
        exit 1
    fi
}

has_python_files() {
    local dir="$1"
    if find "$dir" -type f -name "*.py" | grep -q .; then
        return 0  # 有 Python 文件
    else
        return 1  # 没有 Python 文件
    fi
}

run_analysis_Go() {
    echo "开始分析目标目录:./"
    ls -l ./
     # 创建报告文件夹
    REPORT_DIR="$WORKDIR/gosec-report"
    mkdir -p "$REPORT_DIR/${cleaned_repo_url}"
    $WORKDIR/gopath/bin/gosec -fmt=json -out=$REPORT_DIR/${cleaned_repo_url}/results-${sanitizedBranch}-${TIMESTAMP}.json -stdout -verbose=text ./...
    echo "分析完成，报告已生成：$REPORT_DIR/${cleaned_repo_url}/results-${sanitizedBranch}-${TIMESTAMP}.json"
    cat $REPORT_DIR/${cleaned_repo_url}/results-${sanitizedBranch}-${TIMESTAMP}.json
}

# 运行 SpotBugs 分析
run_analysis_Java() {

    echo "开始分析目标目录:./"
    ls -l ./

    $WORKDIR/apache-maven-3.9.6/bin/mvn clean compile -Dmaven.test.skip
    ls -l ./
    # 创建报告文件夹
    REPORT_DIR="$WORKDIR/spotbugs-report"
    mkdir -p "$REPORT_DIR/${cleaned_repo_url}"

    # 执行 SpotBugs 扫描
    $WORKDIR/jdk18/bin/java -jar "$SPOTBUGS_HOME/lib/spotbugs.jar" \
        -textui \
        -pluginList "$SPOTBUGS_HOME/plugin/findsecbugs-plugin.jar" \
        -effort:max \
        -include $SPOTBUGS_HOME/plugin/include-filter.xml \
        -xml \
        -output "$REPORT_DIR/${cleaned_repo_url}/findsecbugs-report-${sanitizedBranch}-${TIMESTAMP}.xml" \
        "$TARGET_DIR/target/classes"

    echo "分析完成，报告已生成：$REPORT_DIR/${cleaned_repo_url}/findsecbugs-report-${sanitizedBranch}-${TIMESTAMP}.xml"
    cat $REPORT_DIR/${cleaned_repo_url}/findsecbugs-report-${sanitizedBranch}-${TIMESTAMP}.xml
}

run_analysis_Python (){
    which bandit
    pip3 install bandit
    REPORT_DIR="$WORKDIR/bandit-report"
    mkdir -p "$REPORT_DIR/${cleaned_repo_url}"
    bandit -r "./" -f json -o "$REPORT_DIR/${cleaned_repo_url}/bandit-report-${sanitizedBranch}-${TIMESTAMP}.json"
    echo "bandit 扫描完成"
    cat $REPORT_DIR/${cleaned_repo_url}/bandit-report-${sanitizedBranch}-${TIMESTAMP}.json
}

# 主逻辑
main() {
    # 获取 fetch 的仓库地址
    remote_url=$(git remote -v | grep '(fetch)' | awk '{print $2}')

    # 去除 .git、ssh@、https://、http://
    cleaned_repo_url=$(echo "$remote_url" | sed -E 's#https?://##' | tr '/' '@')

    # 将清理后的结果赋值给变量
    echo "Cleaned URL: $cleaned_repo_url"
        # 分析目标代码（将 ./src 替换为你实际的代码目录）
    TARGET_DIR="."

    # 检查文件是否存在
    if [ -f "$TARGET_DIR/pom.xml" ]; then
        echo "pom.xml 文件存在于目录: $TARGET_DIR"
        check_java
        run_analysis_Java "$TARGET_DIR"
    else
        echo "pom.xml 文件不存在于目录: $TARGET_DIR,不执行find-sec-bugs"
    fi

    # 检查文件是否存在
    if [ -f "$TARGET_DIR/go.mod" ]; then
        echo "go.mod 文件存在于目录: $TARGET_DIR"
        run_analysis_Go "$TARGET_DIR"
    else
        echo "go.mod 文件不存在于目录: $TARGET_DIR,不执行gosec"
    fi

    # 4. 扫描 Python 项目
    echo "检查 Python 项目..."
    if has_python_files "./"; then
        echo "检测到 Python 文件，运行 Bandit 扫描..."
        run_analysis_Python
    else
        echo "未检测到 Python 文件，跳过 Bandit 扫描。"
    fi

}

main
