package handler

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	_ "modernc.org/sqlite" // 空导入驱动
	"reflect"
	"strings"
)

func initDb() *sql.DB {
	// SQLite 数据库连接
	db, err := sql.Open("sqlite", "./codearts_scan.db?_busy_timeout=5000")
	if err != nil {
		log.Fatalf("Failed to connect to SQLite database: %v", err)
	}
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(20)
	return db
}

func QueryDatabase(sql string) ([]map[string]interface{}, error) {
	db := initDb()
	stmt, err := db.Prepare(sql)
	rows, err := stmt.Query()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil, err
	}
	var records = make([]map[string]interface{}, 0)
	// 获取列名
	columns, err := rows.Columns()
	if err != nil {
		fmt.Errorf("failed to get columns: %w", err)
		return nil, err
	}

	for rows.Next() {
		// 创建一个存储每列值的切片
		values := make([]interface{}, len(columns))
		valuePointers := make([]interface{}, len(columns))
		for i := range values {
			valuePointers[i] = &values[i]
		}

		// 扫描当前行
		if err := rows.Scan(valuePointers...); err != nil {
			fmt.Errorf("failed to scan row: %w", err)
			return nil, err
		}

		// 将当前行数据存储为 map
		rowMap := make(map[string]interface{})
		for i, col := range columns {
			rowMap[col] = values[i]
		}
		records = append(records, rowMap)
	}
	log.Println("JSON data has been successfully queried from the SQLite database.", len(records))
	return records, nil
}

func UpdateRecordsByWhere(tableName string, setClause, whereClause string) []map[string]interface{} {
	db := initDb()
	defer db.Close()

	query := fmt.Sprintf("UPDATE %s set %s where %s", tableName, setClause, whereClause)
	stmt, err := db.Prepare(query)
	_, err = stmt.Exec()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil
	}
	var records = make([]map[string]interface{}, 0)

	log.Println("JSON data has been successfully updated from the SQLite database.", len(records))
	return records
}

func UpdateRecordsByWhereAInBArr(tableName string, setClause, whereClause string, whereClauseColumn string, whereClauseIn []string) []map[string]interface{} {
	db := initDb()
	defer db.Close()

	strings.Join(whereClauseIn, ",")
	query := fmt.Sprintf("UPDATE %s set %s where %s and %s in (%s)", tableName, setClause, whereClause, whereClauseColumn, whereClauseIn)
	stmt, err := db.Prepare(query)
	_, err = stmt.Exec()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil
	}
	var records = make([]map[string]interface{}, 0)

	log.Println("JSON data has been successfully updated from the SQLite database.", len(records))
	return records
}

func DeleteRecordsByWhere(tableName string, whereClause string) []map[string]interface{} {
	db := initDb()
	defer db.Close()

	query := fmt.Sprintf("DELETE FROM %s where %s", tableName, whereClause)
	stmt, err := db.Prepare(query)
	rows, err := stmt.Query()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil
	}
	var records = make([]map[string]interface{}, 0)
	// 获取列名
	columns, err := rows.Columns()
	if err != nil {
		fmt.Errorf("failed to get columns: %w", err)
		return nil
	}

	for rows.Next() {
		// 创建一个存储每列值的切片
		values := make([]interface{}, len(columns))
		valuePointers := make([]interface{}, len(columns))
		for i := range values {
			valuePointers[i] = &values[i]
		}

		// 扫描当前行
		if err := rows.Scan(valuePointers...); err != nil {
			fmt.Errorf("failed to scan row: %w", err)
			return nil
		}

		// 将当前行数据存储为 map
		rowMap := make(map[string]interface{})
		for i, col := range columns {
			rowMap[col] = values[i]
		}
		records = append(records, rowMap)
	}
	log.Println("JSON data has been successfully deleted from the SQLite database.", len(records))
	return records
}

func QueryRecordsByWhere(tableName string, whereClause string) []map[string]interface{} {
	db := initDb()
	query := fmt.Sprintf("SELECT * FROM %s where %s", tableName, whereClause)
	stmt, err := db.Prepare(query)
	rows, err := stmt.Query()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil
	}
	var records = make([]map[string]interface{}, 0)
	// 获取列名
	columns, err := rows.Columns()
	if err != nil {
		fmt.Errorf("failed to get columns: %w", err)
		return nil
	}

	for rows.Next() {
		// 创建一个存储每列值的切片
		values := make([]interface{}, len(columns))
		valuePointers := make([]interface{}, len(columns))
		for i := range values {
			valuePointers[i] = &values[i]
		}

		// 扫描当前行
		if err := rows.Scan(valuePointers...); err != nil {
			fmt.Errorf("failed to scan row: %w", err)
			return nil
		}

		// 将当前行数据存储为 map
		rowMap := make(map[string]interface{})
		for i, col := range columns {
			rowMap[col] = values[i]
		}
		records = append(records, rowMap)
	}
	log.Println("JSON data has been successfully queried from the SQLite database.", len(records))
	return records
}

func QueryAllRecords(tableName string) []map[string]interface{} {
	db := initDb()
	query := fmt.Sprintf("SELECT * FROM %s", tableName)
	stmt, err := db.Prepare(query)
	rows, err := stmt.Query()
	if err != nil {
		_ = fmt.Errorf("failed to execute table query: %w", err)
		return nil
	}
	var records = make([]map[string]interface{}, 0)
	// 获取列名
	columns, err := rows.Columns()
	if err != nil {
		fmt.Errorf("failed to get columns: %w", err)
		return nil
	}

	for rows.Next() {
		// 创建一个存储每列值的切片
		values := make([]interface{}, len(columns))
		valuePointers := make([]interface{}, len(columns))
		for i := range values {
			valuePointers[i] = &values[i]
		}

		// 扫描当前行
		if err := rows.Scan(valuePointers...); err != nil {
			fmt.Errorf("failed to scan row: %w", err)
			return nil
		}

		// 将当前行数据存储为 map
		rowMap := make(map[string]interface{})
		for i, col := range columns {
			rowMap[col] = values[i]
		}
		records = append(records, rowMap)
	}
	log.Println("JSON data has been successfully queried from the SQLite database.", len(records))
	return records
}

func InsertJsonData2SqlLiteDb(tableName string, hr_Data []byte, primaryKeyConstraint ...string) {
	db := initDb()
	defer db.Close()

	// 自动创建表
	var records = make([]map[string]interface{}, 0)
	err := json.Unmarshal(hr_Data, &records)
	if err != nil {
		return
	}
	if err := CreateTable(db, tableName, records, primaryKeyConstraint...); err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}

	// 插入数据
	if err := InsertRecords(db, tableName, records); err != nil {
		log.Fatalf("Failed to insert records: %v", err)
	}

	log.Println("JSON data has been successfully inserted into the SQLite database.")
}

func InsertJsonRecords2SqlLiteDb(tableName string, records []map[string]interface{}, primaryKeyConstraint ...string) {
	db := initDb()
	defer db.Close()

	if err := CreateTable(db, tableName, records, primaryKeyConstraint...); err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}

	// 插入数据
	if err := InsertRecords(db, tableName, records); err != nil {
		log.Fatalf("Failed to insert records: %v", err)
	}

	log.Println("JSON data has been successfully inserted into the SQLite database.")
}

// CreateTable 根据 JSON 动态创建表
func CreateTable(db *sql.DB, tableName string, records []map[string]interface{}, primaryKeyConstraint ...string) error {
	if len(records) == 0 {
		log.Println("no records to create table from")
		return nil
	}

	columns := make([]string, 0)
	for key, value := range records[0] {
		sqlType := getSQLType(value)
		columns = append(columns, fmt.Sprintf("%s %s", key, sqlType))
	}

	query := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (%s,\n    PRIMARY KEY (%s))", tableName, strings.Join(columns, ", "), strings.Join(primaryKeyConstraint, ", "))
	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("failed to execute create table query: %w", err)
	}

	return nil
}

// InsertRecords 插入 JSON 数据到表
func InsertRecords(db *sql.DB, tableName string, records []map[string]interface{}) error {
	if len(records) == 0 {
		return nil
	}

	columns := make([]string, 0)
	placeholders := make([]string, 0)
	for key := range records[0] {
		columns = append(columns, fmt.Sprintf("%s", key))
		placeholders = append(placeholders, "?")
	}

	query := fmt.Sprintf("INSERT  OR IGNORE INTO %s (%s) VALUES (%s)", tableName, strings.Join(columns, ", "), strings.Join(placeholders, ", "))
	stmt, err := db.Prepare(query)
	if err != nil {
		return fmt.Errorf("failed to prepare insert statement: %w", err)
	}
	defer stmt.Close()

	for _, record := range records {
		values := make([]interface{}, 0)
		for _, column := range columns {
			recordColum := record[strings.Trim(column, "")]
			if v, ok := recordColum.(map[string]interface{}); ok {
				jsonData, err := json.Marshal(recordColum)
				if err != nil {
					log.Println("Error marshalling map to JSON:", err, v)
					continue
				}
				values = append(values, jsonData)
			} else if v, ok := recordColum.([]interface{}); ok {
				jsonData, err := json.Marshal(recordColum)
				if err != nil {
					log.Println("Error marshalling map to JSON:", err, v)
					continue
				}
				values = append(values, jsonData)
			} else {
				values = append(values, record[strings.Trim(column, "")])
			}
		}
		if _, err := stmt.Exec(values...); err != nil {
			return fmt.Errorf("failed to execute insert statement: %w", err)
		}
	}

	return nil
}

// 根据值推断 SQL 数据类型
func getSQLType(value interface{}) string {
	if value == nil {
		return "TEXT"
	}
	switch reflect.TypeOf(value).Kind() {
	case reflect.String:
		return "TEXT"
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return "INTEGER"
	case reflect.Float32, reflect.Float64:
		return "REAL"
	case reflect.Bool:
		return "INTEGER"
	default:
		return "TEXT"
	}
}
