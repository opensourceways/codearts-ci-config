package handler

import (
	"encoding/json"
	"fmt"
	"github.com/xuri/excelize/v2"
	"log"
)

func CreateExcel(excelName string, bytes []byte) {
	// 定义一个通用结构
	var records []map[string]interface{}

	// 解析 JSON
	err := json.Unmarshal(bytes, &records)
	if err != nil {
		log.Println("Error decoding JSON:", err)
		return
	}

	// 创建 Excel 文件
	f := excelize.NewFile()
	sheetName := "Sheet1"
	_, _ = f.NewSheet(sheetName)

	// 写入表头
	if len(records) > 0 {
		headers := make([]string, 0, len(records[0]))
		col := 1
		for header := range records[0] {
			headers = append(headers, header)
			cell, _ := excelize.CoordinatesToCellName(col, 1)
			f.SetCellValue(sheetName, cell, header)
			col++
		}

		// 写入数据
		for row, record := range records {
			col := 1
			for _, header := range headers {
				cell, _ := excelize.CoordinatesToCellName(col, row+2) // 数据从第二行开始
				switch v := record[header].(type) {
				case map[string]interface{}:
					jsonData, err := json.Marshal(record[header])
					if err != nil {
						log.Println("Error marshalling map to JSON:", err, v)
						continue
					}
					// 将 JSON 字符串写入 Excel
					f.SetCellValue(sheetName, cell, string(jsonData))
				default:
					f.SetCellValue(sheetName, cell, record[header])
				}
				col++
			}
		}
	}

	// 保存文件
	output := excelName
	if err := f.SaveAs(output); err != nil {
		log.Println("Error saving Excel file:", err)
		return
	}

	log.Println("Excel file created successfully:", output)
}

func ReadExcel(filePath string, sheetName string) ([]map[string]interface{}, error) {
	// 打开文件
	f, err := excelize.OpenFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open Excel file: %w", err)
	}
	defer f.Close()

	// 获取第一个工作表名称
	if sheetName == "" {
		sheetName = f.GetSheetName(1)
	}

	// 获取所有行
	rows, err := f.GetRows(sheetName)
	if err != nil {
		return nil, fmt.Errorf("failed to get rows: %w", err)
	}

	if len(rows) < 1 {
		return nil, fmt.Errorf("Excel sheet is empty")
	}

	// 第一行为表头
	headers := rows[0]

	// 转换为 []map[string]interface{}
	var result []map[string]interface{}
	for _, row := range rows[1:] { // 从第二行开始读取数据
		rowMap := make(map[string]interface{})
		for j, cell := range row {
			if j < len(headers) { // 确保不会越界
				rowMap[headers[j]] = cell
			}
		}
		result = append(result, rowMap)

		// 如果某行少于表头列数，补充为空值
		for j := len(row); j < len(headers); j++ {
			rowMap[headers[j]] = nil
		}
	}

	return result, nil
}
