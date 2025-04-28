import java.io.File
import java.sql.DriverManager.println
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.*

class SSLScanAnalyzer {
    // 配置参数
    private val resultsDir = File("./results")
    private val reportFile = File("full_report_${currentDate()}.txt")
    private val insecureFile = File("insecure_domains_${currentDate()}.txt")
    private val issueTypes = HashMap<String, Int>()
    private var totalCount = 0
    private var insecureCount = 0

    fun runAnalysis() {
        initReportFiles()

        if (!resultsDir.exists()) {
            println("错误: 找不到results目录 ${resultsDir.absolutePath}")
            return
        }

        // 处理每个扫描结果文件
        resultsDir.listFiles { file -> file.name.endsWith("_sslscan.txt") }?.forEach { file ->
            totalCount++
            processFile(file)
        }

        generateSummary()
        println("\n检查完成!\n扫描域名总数: $totalCount\n存在问题的域名: $insecureCount")
        println("完整报告: ${reportFile.absolutePath}\n问题域名: ${insecureFile.absolutePath}")
    }

    private fun currentDate(): String {
        return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
    }

    private fun initReportFiles() {
        reportFile.writeText("SSL/TLS全面安全检测报告\n扫描时间: ${LocalDateTime.now()}\n${"=".repeat(40)}\n")
        insecureFile.writeText("不安全的SSL/TLS配置报告\n生成日期: ${LocalDateTime.now()}\n${"=".repeat(40)}\n\n")
    }

    private fun processFile(file: File) {
        val domain = file.nameWithoutExtension.replace("_sslscan", "")
        val cleanContent = removeAnsiCodes(file.readText())

        reportFile.appendText("\n[域名] $domain\n${"=".repeat(40)}\n")

        var fileHasIssues = false

        // 执行各项检查
        listOf(
            ::checkProtocol,
            ::checkCiphers,
            ::checkCbc,
            ::checkDhe,
            ::checkCertificate,
            ::checkOther
        ).forEach { check ->
            if (check(domain, cleanContent)) {
                fileHasIssues = true
            }
        }

        // 记录有问题的域名
        if (fileHasIssues) {
            insecureCount++
            insecureFile.appendText("$domain\n")
        }
    }

    private fun removeAnsiCodes(text: String): String {
        val ansiEscape = Regex("\u001B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~])")
        return ansiEscape.replace(text, "")
    }

    private fun checkProtocol(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("[协议检查]", "-".repeat(30))
        var hasIssues = false


        // 检查不安全的协议
        listOf("SSLv2", "SSLv3", "TLSv1.0", "TLSv1.1").forEach { protocol ->
            if (content.contains("$protocol     enabled")) {
                reportLines.add("❌ 不安全的协议: $protocol")
                recordIssue("协议:$protocol")
                hasIssues = true
            }
        }

        if (!hasIssues) {
            reportLines.add("✅ 协议配置安全")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun checkCiphers(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("\n[密码套件检查]", "-".repeat(30))
        var hasIssues = false

        // 不安全套件列表
        listOf(
            "DES-CBC", "DES-CBC3", "RC4", "RC2", "IDEA", "SEED",
            "MD5", "SHA1", "EXPORT", "ANON", "NULL", "ADH", "AECDH", "KRB5",
            "PSK", "SRP"
        ).forEach { cipher ->
            if (Regex("$cipher.*").containsMatchIn(content)) {
                reportLines.add("❌ 不安全的密码套件: $cipher")
                recordIssue("密码套件:$cipher")
                hasIssues = true
            }
        }

        if (!hasIssues) {
            reportLines.add("✅ 未发现不安全密码套件")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun checkCbc(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("\n[CBC模式检查]", "-".repeat(30))
        var hasIssues = false

        // CBC模式套件检测
        listOf(
            "AES.*-CBC", "AES.*-CBC-SHA", "AES.*-CBC-SHA256",
            "CAMELLIA.*-CBC", "3DES-.*CBC", "SEED.*-CBC",
            "DES.*-CBC", "IDEA.*-CBC", "RC2.*-CBC"
        ).forEach { pattern ->
            Regex(pattern).findAll(content).forEach { matchResult ->
                val cipher = matchResult.value.substringBefore(" ")
                reportLines.add("⚠️ 高风险CBC模式套件: $cipher")
                recordIssue("CBC模式:$cipher")
                hasIssues = true
            }
        }

        if (!hasIssues) {
            reportLines.add("✅ 未发现高风险CBC套件")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun checkDhe(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("\n[DH参数检查]", "-".repeat(30))
        val hasIssues = content.contains("DHE 1024 bits")

        if (hasIssues) {
            reportLines.add("❌ 弱Diffie-Hellman参数(1024位)")
            recordIssue("DH参数:1024位")
        } else {
            reportLines.add("✅ DH参数安全")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun checkCertificate(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("\n[证书检查]", "-".repeat(30))
        var hasIssues = false

        // 提取RSA密钥长度
        val rsaMatch = Regex("RSA Key Strength:\\s*(\\d+)").find(content)
        rsaMatch?.groupValues?.get(1)?.toIntOrNull()?.let { keySize ->
            if (keySize < 2048) {
                reportLines.add("❌ 弱RSA密钥长度: $keySize 位")
                recordIssue("证书:RSA$keySize 位")
                hasIssues = true
            }
        }

        // 检查证书有效期
        val expiryMatch = Regex("Not valid after:\\s*(.+)").find(content)
        expiryMatch?.groupValues?.get(1)?.let { expiryDate ->
            println(expiryDate)
            // 这里可以添加有效期检查逻辑
        }

        if (!hasIssues) {
            reportLines.add("✅ 证书配置安全")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun checkOther(domain: String, content: String): Boolean {
        val reportLines = mutableListOf("\n[其他安全检查]", "-".repeat(30))
        var hasIssues = false

        // Heartbleed漏洞检查
        if (content.contains("Heartbleed:.*vulnerable")) {
            reportLines.add("❌ 存在Heartbleed漏洞")
            recordIssue("漏洞:Heartbleed")
            hasIssues = true
        }

        // TLS压缩检查
        if (content.contains("TLS Compression:.*enabled")) {
            reportLines.add("❌ 启用了不安全的TLS压缩")
            recordIssue("配置:TLS压缩")
            hasIssues = true
        }

        // 不安全的重新协商
        if (content.contains("TLS renegotiation:.*supported")) {
            reportLines.add("⚠️ 支持不安全的TLS重新协商")
            recordIssue("配置:不安全重新协商")
            hasIssues = true
        }

        if (!hasIssues) {
            reportLines.add("✅ 未发现其他安全问题")
        }

        writeReport(reportLines)
        return hasIssues
    }

    private fun recordIssue(issueType: String) {
        issueTypes[issueType] = issueTypes.getOrDefault(issueType, 0) + 1
    }

    private fun writeReport(lines: List<String>) {
        reportFile.appendText(lines.joinToString("\n") + "\n")
    }

    private fun generateSummary() {
        val summary = mutableListOf(
            "\n======== 扫描总结 ========",
            "扫描域名总数: $totalCount",
            "存在问题的域名: $insecureCount",
            "安全域名: ${totalCount - insecureCount}",
            "\n发现的主要问题类型:"
        )

        // 添加问题类型统计
        issueTypes.toList().sortedBy { (_, count) -> -count }.forEach { (issue, count) ->
            summary.add("$issue: ${count}次")
        }

        summary.addAll(
            listOf(
                "\n详细问题请查看: ${insecureFile.absolutePath}",
                "=".repeat(40)
            )
        )
        reportFile.appendText(summary.joinToString("\n") + "\n")
    }
}

fun main() {
    SSLScanAnalyzer().runAnalysis()
}