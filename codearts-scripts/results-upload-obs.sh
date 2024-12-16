echo 'hello'

/opt/cached_resources/obsutil/obsutil config -i=${OBS_AK} -k=${OBS_SK} -e=${OBS_ENDPOINT}
/opt/cached_resources/obsutil/obsutil ls obs://infra-codearts-scan -limit=10

/opt/cached_resources/obsutil/obsutil sync /opt/cached_resources/sast/bandit-report obs://infra-codearts-scan/bandit-report

/opt/cached_resources/obsutil/obsutil sync /opt/cached_resources/sast/gosec-report obs://infra-codearts-scan/gosec-report

/opt/cached_resources/obsutil/obsutil sync /opt/cached_resources/sast/spotbugs-report obs://infra-codearts-scan/spotbugs-report

/opt/cached_resources/obsutil/obsutil sync /opt/cached_resources/trivy_db/results obs://infra-codearts-scan/trivy-report

/opt/cached_resources/obsutil/obsutil sync /opt/cached_resources/gitleaks obs://infra-codearts-scan/gitleaks-report