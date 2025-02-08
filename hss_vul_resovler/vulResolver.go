/*
 *  Copyright (c) Huawei Technologies Co., Ltd. 2017-2023. All rights reserved.
 */

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"huaweicloud.com/apig/go/signer/core"
	"huaweicloud.com/apig/go/signer/handler"
	"io"
	"math"
	"net/http"
	"os"
)

var hssAssetList = []HssAsset{{
	hwsAccount: "freesky-edward",
	region:     "cn-north-4",
	projectId:  "25f40abeecb84d3e90731de258ca71ec",
}, {}, {}}

type HssAsset struct {
	hwsAccount string
	region     string
	projectId  string
	AK         string
	SK         string
}

func main() {
	for _, hssAsset := range hssAssetList {
		if hssAsset.region == "" || hssAsset.projectId == "" {
			continue
		}
		resolveRiskTypesData(hssAsset)
		resolveWeakPasswordUserData(hssAsset)
		resolvePasswordBaselineData(hssAsset)
		resolveEventData(hssAsset)
		resolveHostData(hssAsset)
		resolveVulData(hssAsset)
	}
}

func resolveRiskTypesData(hssAsset HssAsset) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/baseline/risk-configs?offset=%d&limit=%d&enterprise_project_id=all_granted_eps", "")
	for _, hssData := range hssList {
		resolveRiskConfigData(hssAsset, hssData["check_type"].(string))
	}
}

func resolveRiskConfigHostData(hssAsset HssAsset, riskType string) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/baseline/risk-config/"+riskType+"/check-rules?result_type=unhandled&standard=hw_standard&check_cce=true&enterprise_project_id=all_granted_eps&offset=%d&limit=%d", "")
	handler.DeleteRecordsByWhere("hss_risk_config_detail_host", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s' and check_type='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region, riskType))
	handler.InsertJsonRecords2SqlLiteDb("hss_risk_config_detail_host", hssList, "hwsAccount", "projectId", "region", "check_type", "host_id")
}

func resolveRiskConfigData(hssAsset HssAsset, riskType string) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/baseline/risk-config/"+riskType+"/check-rules?result_type=unhandled&standard=hw_standard&check_cce=true&enterprise_project_id=all_granted_eps&offset=%d&limit=%d", "")
	handler.DeleteRecordsByWhere("hss_risk_config_detail", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s' and check_type='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region, riskType))
	handler.InsertJsonRecords2SqlLiteDb("hss_risk_config_detail", hssList, "hwsAccount", "projectId", "region", "check_type", "check_rule_id")
}

func resolveWeakPasswordUserData(hssAsset HssAsset) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/baseline/weak-password-users?enterprise_project_id=all_granted_eps&offset=%d&limit=%d", "")
	handler.DeleteRecordsByWhere("hss_weak_password_user", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region))
	handler.InsertJsonRecords2SqlLiteDb("hss_weak_password_user", hssList, "hwsAccount", "projectId", "region", "host_id")
}

func resolvePasswordBaselineData(hssAsset HssAsset) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/baseline/password-complexity?result_type=unhandled&enterprise_project_id=all_granted_eps&offset=%d&limit=%d", "")
	handler.DeleteRecordsByWhere("hss_password_config_baseline", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region))
	handler.InsertJsonRecords2SqlLiteDb("hss_password_config_baseline", hssList, "hwsAccount", "projectId", "region", "host_id")
}

func resolveEventData(hssAsset HssAsset) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/event/events?offset=%d&limit=%d&handle_status=unhandled&category=host&enterprise_project_id=all_granted_eps", "")
	handler.DeleteRecordsByWhere("hss_event", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region))
	handler.InsertJsonRecords2SqlLiteDb("hss_event", hssList, "hwsAccount", "projectId", "region", "event_id")
}

func getHssData(hssAsset HssAsset, url, vulType string) []map[string]interface{} {
	var limit = 10
	var offset = 0
	var total = math.MaxInt
	hssList := make([]map[string]interface{}, 0)
	fmt.Println(hssList)
	for total > offset {
		var hssData []byte
		if vulType != "" {
			hssData = fetchData(hssAsset, fmt.Sprintf(url, hssAsset.region, hssAsset.projectId, offset, limit, vulType))
		} else {
			hssData = fetchData(hssAsset, fmt.Sprintf(url, hssAsset.region, hssAsset.projectId, offset, limit))
		}
		hssMap := make(map[string]interface{})
		err := json.Unmarshal(hssData, &hssMap)
		if err != nil {
			return nil
		}
		total = int(hssMap["total_num"].(float64))
		elems := hssMap["data_list"].([]interface{})
		for _, elem := range elems {
			if v, ok := elem.(map[string]interface{}); ok {
				hssList = append(hssList, v)
				fmt.Println(v)
			} else {
				fmt.Println(11)
			}
		}
		offset += limit
	}
	fmt.Println(len(hssList))
	for _, host := range hssList {
		host["hwsAccount"] = hssAsset.hwsAccount
		host["projectId"] = hssAsset.projectId
		host["region"] = hssAsset.region
	}
	return hssList
}

func resolveHostData(hssAsset HssAsset) {
	hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/host-management/hosts?offset=%d&limit=%d&refresh=false&enterprise_project_id=all_granted_eps", "")
	handler.DeleteRecordsByWhere("hss_host", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region))
	handler.InsertJsonRecords2SqlLiteDb("hss_host", hssList, "hwsAccount", "projectId", "region", "host_id")
}

func resolveVulData(hssAsset HssAsset) {
	vulTypes := []string{"linux_vul", "windows_vul", "web_cms", "app_vul", "urgent_vul"}
	for _, vulType := range vulTypes {
		hssList := getHssData(hssAsset, "https://hss.%s.myhuaweicloud.com/v5/%s/vulnerability/vulnerabilities?handle_status=unhandled&repair_priority=Critical,High,Medium,Low&offset=%d&limit=%d&type=%s&enterprise_project_id=all_granted_eps", vulType)
		handler.DeleteRecordsByWhere("hss_vuls", fmt.Sprintf("hwsAccount='%s' and projectId='%s' and region='%s' and type='%s'", hssAsset.hwsAccount, hssAsset.projectId, hssAsset.region, vulType))
		handler.InsertJsonRecords2SqlLiteDb("hss_vuls", hssList, "hwsAccount", "projectId", "region", "type", "vul_id")
	}
}

func fetchData(hssAsset HssAsset, url string) []byte {
	// 认证用的ak和sk硬编码到代码中或者明文存储都有很大的安全风险，建议在配置文件或者环境变量中密文存放，使用时解密，确保安全；
	// 本示例以ak和sk保存在环境变量中为例，运行本示例前请先在本地环境中设置环境变量HUAWEICLOUD_SDK_AK和HUAWEICLOUD_SDK_SK。
	var s = core.Signer{
		Key:    os.Getenv(hssAsset.hwsAccount + "_" + hssAsset.region + "_AK"),
		Secret: os.Getenv(hssAsset.hwsAccount + "_" + hssAsset.region + "_SK"),
	}
	r, err := http.NewRequest("GET", url, io.NopCloser(bytes.NewBuffer([]byte("foo=bar"))))
	if err != nil {
		fmt.Println(err)
		return nil
	}

	r.Header.Add("content-type", "application/json; charset=utf-8")
	r.Header.Add("x-stage", "RELEASE")
	r.Header.Add("region", hssAsset.region)
	s.Sign(r)
	client := http.DefaultClient
	resp, err := client.Do(r)
	if err != nil {
		fmt.Println(err)
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println(err)
	}

	return body
}
