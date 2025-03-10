package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"resolver/handler"
	"strings"
)

var k8sClusterName = "openEuler_hk"

var xVaultToken = os.Getenv("xVaultToken")

func main() {
	url := "http://127.0.0.1:12345/v1/internal/metadata/"
	secretGroupList := getSecretGroupList(url, "")
	processSecretGroups(url, secretGroupList, "")
}

func processSecretGroups(baseURL string, parentGroupList []interface{}, parentGroup string) {
	for _, secretGroup := range parentGroupList {
		groupPath := parentGroup + secretGroup.(string)
		secretList := getSecretGroupList(baseURL, groupPath)

		// 如果secretList为空，说明当前groupPath是一个叶子节点，直接处理secrets
		if len(secretList) == 0 {
			processSecrets(groupPath)
		} else {
			// 否则，递归处理子group
			processSecretGroups(baseURL, secretList, groupPath)
		}
	}
}

func processSecrets(groupPath string) {
	records := make([]map[string]interface{}, 0)
	handler.DeleteRecordsByWhere(k8sClusterName+"_jenkins_vault_secrets", fmt.Sprintf("1=1 and 项目='%s'", groupPath))

	log.Println("处理 ", groupPath)
	split := strings.Split(groupPath, "/")
	secretName := split[len(split)-1]
	result := getSecretCurrentVersion(groupPath)
	for key, value := range result {
		record := make(map[string]interface{})
		record["项目"] = groupPath
		record["服务"] = secretName
		record["key"] = key
		record["value"] = value
		records = append(records, record)
	}
	handler.InsertJsonRecords2SqlLiteDb(k8sClusterName+"_jenkins_vault_secrets", records, "项目", "服务", "key")
}

func getSecretCurrentVersion(path string) map[string]interface{} {
	url := "http://127.0.0.1:12345/v1/internal/data/" + path
	method := "GET"

	client := &http.Client{}
	req, err := http.NewRequest(method, url, nil)

	if err != nil {
		fmt.Println(err)
		return nil
	}
	req.Header.Add("Accept", "*/*")
	req.Header.Add("Accept-Language", "en,zh-CN;q=0.9,zh;q=0.8")
	req.Header.Add("Connection", "keep-alive")
	req.Header.Add("X-Vault-Token", xVaultToken)

	res, err := client.Do(req)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	defer res.Body.Close()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	result := make(map[string]interface{})
	err = json.Unmarshal(body, &result)
	if err != nil {
		return nil
	}
	return result["data"].(map[string]interface{})["data"].(map[string]interface{})
}

func getSecretGroupList(url string, appends string) []interface{} {
	if appends != "" {
		url += appends
	}
	url += "?list=true"
	method := "GET"

	client := &http.Client{}
	req, err := http.NewRequest(method, url, nil)

	if err != nil {
		fmt.Println(err)
		return nil
	}
	req.Header.Add("Accept", "*/*")
	req.Header.Add("Accept-Language", "en,zh-CN;q=0.9,zh;q=0.8")
	req.Header.Add("Connection", "keep-alive")
	req.Header.Add("X-Vault-Token", xVaultToken)
	req.Header.Add("Cookie", "HWWAFSESID=30063103fc2f5546483d; HWWAFSESTIME=1740471420298")

	res, err := client.Do(req)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	defer res.Body.Close()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	result := make(map[string]interface{})
	err = json.Unmarshal(body, &result)
	if err != nil {
		return nil
	}

	if result["data"] == nil {
		return make([]interface{}, 0)
	}
	return result["data"].(map[string]interface{})["keys"].([]interface{})
}
