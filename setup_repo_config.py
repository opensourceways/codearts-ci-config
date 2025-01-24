import os
import shutil

import yaml
import subprocess

import requests
from base64 import b64encode
from nacl import encoding, public

# 配置
GITHUB_TOKEN = ""
CODEARTS_PASSWORD = ""
CODEARTS_URL = ""
LOCAL_GITHUB_FOLDER = "../github_workflow/.github"
PROJECT_NAME = ["message-transfer", "message-push", "message-collect", "BigFiles", "certification-server",
                "message-manager", "EasySoftwareService", "EasySoftwareInput", "easysoftware-autoupgrade", "go-gitcode",
                "om-webserver", "datastat-server", "EasySearch", "EasySearch-Import", "om-kafka", "om-collection",
                "xihe-server", "discourse-translator", "discourse_docker", "easypackages", "infraAIService",
                "copr_docker", "app-cla-server", "DataMagic"]
TODO_PROJECT_NAME = ["oneid-website", "oneid-server", "easyeditor-server", "xihe-message-server",
                     "xihe-inference-evaluate", "xihe-cronjob", "xihe-audit-sync-sdk", "xihe-sdk", "xihe-sync-repo",
                     "xihe-grpc-protocol", "xihe-extra-services", "xihe-statistics", "xihe-training-center"]
SINGLE_PROJECT_NAME = ["om-webserver"]

PROJECT = PROJECT_NAME
ruleset_name = 'gate_check'


def get_public_key(owner, repo):
    url = f"https://api.github.com/repos/{owner}/{repo}/actions/secrets/public-key"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    response = requests.get(url, headers=headers)
    response.raise_for_status()  # 如果请求失败，抛出异常
    return response.json()


def encrypt_secret(public_key: str, secret_value: str) -> str:
    """Encrypt a Unicode string using the public key."""
    public_key = public.PublicKey(public_key.encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return b64encode(encrypted).decode("utf-8")


def create_secret(owner, repo, secret_name, encrypted_value, key_id):
    url = f"https://api.github.com/repos/{owner}/{repo}/actions/secrets/{secret_name}"
    data = {
        "encrypted_value": encrypted_value,
        "key_id": key_id
    }
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    response = requests.put(url, headers=headers, json=data)
    response.raise_for_status()  # 如果请求失败，抛出异常


def create_multiple_secrets(owner, repo, secrets):
    public_key_data = get_public_key(owner, repo)
    public_key = public_key_data['key']
    key_id = public_key_data['key_id']

    for secret_name, secret_value in secrets.items():
        encrypted_value = encrypt_secret(public_key, secret_value)
        create_secret(owner, repo, secret_name, encrypted_value, key_id)

    print("创建 Secrets 成功.")


def get_secrets(owner, repo):
    # GitHub API URL
    url = f'https://api.github.com/repos/{owner}/{repo}/actions/secrets'

    # 请求头
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }

    # 获取仓库的 secrets
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        secrets = response.json()
        print("Secrets in the repository:")
        for secret in secrets.get('secrets', []):
            print(f"- {secret['name']}")
    else:
        print(f"Failed to retrieve secrets: {response.status_code} - {response.text}")


# 克隆仓库
def clone_repo(owner, repo):
    subprocess.run(["git", "clone", f"https://github.com/{owner}/{repo}.git"])


def prepare_merge(owner, repo, branch):
    os.chdir(repo)
    if branch == "~DEFAULT_BRANCH":
        branch = get_default_branch(owner, repo)
    subprocess.run(["git", "checkout", branch])

    # 获取当前工作目录下的 .github 路径
    local_path = os.path.join(os.getcwd(), LOCAL_GITHUB_FOLDER)
    if not os.path.exists(local_path):
        print(f"Error: The local folder '{local_path}' does not exist.")
        return

    # 定义目标路径
    target_path = os.path.join(repo, LOCAL_GITHUB_FOLDER)

    if os.path.exists(target_path):
        # 如果目标路径存在，进行合并
        for item in os.listdir(local_path):
            source = os.path.join(local_path, item)
            destination = os.path.join(target_path, item)

            if os.path.exists(destination):
                if os.path.isdir(destination):
                    # 如果是子文件夹，递归合并内容
                    merge_directories(source, destination)
                else:
                    print(f"Warning: '{item}' already exists in the target folder. Skipping.")
            else:
                # 直接复制文件或文件夹
                shutil.copytree(source, destination)
    else:
        # 目标文件夹不存在，直接复制
        shutil.copytree(local_path, target_path)


def merge_directories(source_dir, target_dir):
    for item in os.listdir(source_dir):
        source_item = os.path.join(source_dir, item)
        target_item = os.path.join(target_dir, item)

        if os.path.isdir(source_item):
            if not os.path.exists(target_item):
                shutil.copytree(source_item, target_item)
            else:
                merge_directories(source_item, target_item)
        else:
            # 复制文件
            shutil.copy2(source_item, target_item)


# 提交更改
def git_commit_and_push(owner, repo):
    # 设置 Git 远程 URL
    remote_url = f"https://github.com/{owner}/{repo}.git"  # 替换为你的仓库地址
    subprocess.run(["git", "remote", "set-url", "origin", remote_url])
    # 添加更改
    subprocess.run(["git", "add", "."])
    # 提交更改
    subprocess.run(["git", "commit", "-m", "Add .github folder structure"])

    # 使用访问令牌进行推送
    push_command = [
        "git", "push", "https://{}:x-oauth-basic@github.com/{}/{}.git".format(GITHUB_TOKEN, owner, repo)
    ]

    result = subprocess.run(push_command)
    os.chdir("..")
    if result.returncode == 0:
        return True
    else:
        return False


def download_yaml_file():
    # 构建 GitHub 原始文件的 URL
    url = f"https://raw.githubusercontent.com/opensourceways/codearts-ci-config/main/pipeline-config.yml"

    # 下载文件
    response = requests.get(url)

    # 检查请求是否成功
    if response.status_code == 200:
        # 如果没有指定本地文件路径，使用文件名

        # 将内容写入本地文件，覆盖已存在的文件
        with open("pipeline-config.yml", 'wb') as file:
            file.write(response.content)
    else:
        print(f"Failed to download file: {response.status_code} - {response.text}")


def load_yaml():
    """从指定路径加载 YAML 文件并返回数据"""
    with open("pipeline-config.yml", 'r') as file:
        return yaml.safe_load(file)


def get_attr(topic, data):
    attributes = data.get(topic)
    if attributes and all(attributes.get(k) for k in ['git_url', 'pipeline_url', 'endpoint_id']):
        return attributes

    return None


def set_branch_ruleset(owner, repo, branches, needCheckLabel):
    # 设置请求头
    headers = {
        'Accept': 'application/vnd.github+json',
        'Authorization': f'Bearer {GITHUB_TOKEN}'
    }
    # 请求体
    requiredStausChecks = [{
        "context": "check-branch-naming",
        "integration_id": 15368,
    }]
    if needCheckLabel:
        requiredStausChecks.append({
            "context": "check-label",
            "integration_id": 15368,
        })
    print(requiredStausChecks)
    data = {
        "name": "gate_check",
        "target": "branch",
        "enforcement": "active",
        "bypass_actors": [],
        "conditions": {
            "ref_name": {
                "include": branches,
                "exclude": []
            }
        },
        "rules": [
            {
                "type": "non_fast_forward",
            },
            {
                "type": "required_status_checks",
                "parameters": {
                    "do_not_enforce_on_create": True,
                    "required_status_checks": requiredStausChecks,
                    "strict_required_status_checks_policy": False
                }
            },
            {
                "type": "pull_request",
                "parameters": {
                    "dismiss_stale_reviews_on_push": False,
                    "require_code_owner_review": False,
                    "require_last_push_approval": False,
                    "required_approving_review_count": 1,
                    "required_review_thread_resolution": False
                },
            }
        ]
    }
    url = f'https://api.github.com/repos/{owner}/{repo}/rulesets'
    # 发送请求
    response = requests.post(
        url,
        headers=headers,
        json=data
    )

    # 输出响应结果
    if response.status_code == 201:
        print(f"规则集创建成功! -- {repo}")
    else:
        print(f"创建失败：{response.status_code} - {response.json()} -- {repo}")


def del_branch_ruleset(owner, repo):
    # 请求头
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github+json'
    }

    url = f'https://api.github.com/repos/{owner}/{repo}/rulesets'
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        rulesets = response.json()

        # 查找指定名称的 ruleset
        for ruleset in rulesets:
            if ruleset.get('name') == ruleset_name:
                ruleset_id = ruleset.get('id')
                url = f'https://api.github.com/repos/{owner}/{repo}/rulesets/{ruleset_id}'
                # 发送 DELETE 请求
                response = requests.delete(url, headers=headers)

                # 输出结果
                if response.status_code == 204:
                    print("Ruleset 删除成功.")
                else:
                    print("删除失败:", response.status_code, response.json())
                break
        else:
            print(f"未找到名称为 '{ruleset_name}' 的 ruleset。")
    else:
        print("获取 rulesets 失败:", response.status_code, response.json())


def get_default_branch(owner, repo):
    # API 端点
    url = f'https://api.github.com/repos/{owner}/{repo}'

    # 请求头
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github+json'
    }

    # 发送 GET 请求以获取仓库信息
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        repo_info = response.json()
        default_branch = repo_info.get('default_branch')
        return default_branch
    else:
        print("获取仓库信息失败:", response.status_code, response.json())
        return ""


def get_protect_branch(owner, repo):
    # 请求 GitHub API
    url = f"https://api.github.com/repos/{owner}/{repo}/branches"
    headers = {"Authorization": f"token {GITHUB_TOKEN}"}
    response = requests.get(url, headers=headers)
    branches = response.json()

    # 筛选 release/ 开头的分支
    release_branches = [branch["name"] for branch in branches if branch["name"].startswith("release/")]
    return release_branches


def main():
    download_yaml_file()
    data = load_yaml()
    for projectName in PROJECT:
        attrs = get_attr(projectName, data)
        if not attrs:
            return
        git_url = attrs['git_url']
        pipeline_url = attrs['pipeline_url']
        endpoint_id = attrs['endpoint_id']
        need_check_label = attrs.get('check_label', True)
        branches = attrs.get('branch', "")
        git_url = git_url.replace('https://github.com/', '').replace('.git', '')
        # 拆分 URL
        parts = git_url.split('/')
        owner, repo = parts
        pipeline_parts = (pipeline_url.replace("https://devcloud.cn-north-4.huaweicloud.com/cicd/", "").
                          replace("?from=in-project&v=1", "").
                          replace("?from=out-project&v=1", "")).split("/")
        project_id, pipeline_id = pipeline_parts[1], pipeline_parts[4]

        secret_dict = {
            "CODEARTS_ENDPOINT_ID": f"{endpoint_id}",
            "CODEARTS_PASSWORD": f"{CODEARTS_PASSWORD}",
            "CODEARTS_PIPELINE": f"{CODEARTS_URL}/{project_id}/api/pipelines/{pipeline_id}/run",
            "OWNER_TOKEN": f"{GITHUB_TOKEN}",
        }
        create_multiple_secrets(owner, repo, secret_dict)
        clone_repo(owner, repo)
        del_branch_ruleset(owner, repo)
        branches_list = branches.replace(" ", "").split(",") if branches else []
        branches_list.extend(get_protect_branch(owner, repo))
        for branch in branches_list:
            prepare_merge(owner, repo, branch)
            if not git_commit_and_push(owner, repo):
                return
        branches_list = ["~DEFAULT_BRANCH", "release/*"]
        branches_format = ["refs/heads/%s" % branch if branch != "~DEFAULT_BRANCH" else branch for branch in
                           branches_list]
        set_branch_ruleset(owner, repo, branches_format, need_check_label)


if __name__ == "__main__":
    main()
