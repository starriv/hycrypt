package interactivecli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"hycrypt/internal/constants"
)

// EncryptProcessor 加密处理器
type EncryptProcessor struct{}

// NewEncryptProcessor 创建加密处理器
func NewEncryptProcessor() *EncryptProcessor {
	return &EncryptProcessor{}
}

// ProcessEncryption 处理加密操作
func (p *EncryptProcessor) ProcessEncryption(m Model) operationResult {
	startTime := time.Now()

	// 更新配置中的加密方法
	originalMethod := m.config.Encryption.Method
	m.config.Encryption.Method = m.algorithm
	defer func() {
		m.config.Encryption.Method = originalMethod
	}()

	cryptoService, err := CryptoService(m.config)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("初始化加密服务失败: %v", err))
	}

	outputDir := p.resolveOutputDirectory(m)

	var targetPath string
	var originalFileSize int64

	// 处理文本加密的十六进制输出
	if m.inputType == "text" && m.outputFormat == "hex" {
		return p.processTextEncryptionHex(m, startTime)
	}

	// 准备目标路径
	if m.inputType == "text" {
		textContent := m.textArea.Value()
		tempFile, err := createSecureTempFile(textContent)
		if err != nil {
			return newOperationResult(false, fmt.Sprintf("创建临时文件失败: %v", err))
		}
		targetPath = tempFile
		originalFileSize = int64(len(textContent))
		defer os.Remove(tempFile)
	} else {
		targetPath = strings.TrimSpace(m.pathInput.Value())
		if info, err := os.Stat(targetPath); err == nil {
			originalFileSize = info.Size()
		}
	}

	// 执行加密操作
	actualOutputPath, err := cryptoService.EncryptPath(targetPath, outputDir)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("加密失败: %v", err))
	}

	// 从实际输出路径获取文件名（包含可能的重复后缀）
	actualEncryptedFile := filepath.Base(actualOutputPath)

	resultInfo := EncryptionResult{
		FileName:       actualEncryptedFile, // 使用实际的加密文件名
		FileSize:       originalFileSize,
		Algorithm:      strings.ToUpper(m.algorithm),
		EncryptionTime: time.Since(startTime).String(),
		OutputPath:     outputDir,
	}

	return newOperationResultWithInfo(true, "加密完成", resultInfo)
}

// resolveOutputDirectory 解析输出目录
func (p *EncryptProcessor) resolveOutputDirectory(m Model) string {
	outputDir := m.outputInput.Value()
	if outputDir == "" {
		// 用户未指定目录，根据隐私输出设置决定输出位置
		if m.config.Output.PrivateOutput {
			// 隐私输出开启：使用全局配置目录
			outputDir = m.config.GetEncryptedDirPath()
		} else {
			// 隐私输出关闭：使用输入文件同目录
			inputPath := strings.TrimSpace(m.pathInput.Value())
			if inputPath != "" {
				outputDir = filepath.Dir(inputPath)
			} else {
				// 如果没有输入路径，回退到配置目录
				outputDir = m.config.GetEncryptedDirPath()
			}
		}
	} else {
		// 用户指定了目录，处理相对路径
		if !filepath.IsAbs(outputDir) {
			// 相对路径基于程序运行目录
			cwd, err := os.Getwd()
			if err == nil {
				if outputDir == "./" || outputDir == "." {
					// 特殊处理："./" 表示在当前目录下使用配置的目录名
					configDirName := m.config.Directories.EncryptedDir
					outputDir = filepath.Join(cwd, configDirName)
				} else {
					outputDir = filepath.Join(cwd, outputDir)
				}
			}
		}
	}
	return outputDir
}

// processTextEncryptionHex 处理文本加密的十六进制输出 - 现在直接输出到终端
func (p *EncryptProcessor) processTextEncryptionHex(m Model, startTime time.Time) operationResult {
	textContent := m.textArea.Value()

	if strings.TrimSpace(textContent) == "" {
		return newOperationResult(false, "输入为空")
	}

	// 更新配置中的算法为用户选择的算法
	originalMethod := m.config.Encryption.Method
	m.config.Encryption.Method = m.algorithm
	defer func() {
		m.config.Encryption.Method = originalMethod
	}()

	// 创建加密服务
	cryptoService, err := CryptoService(m.config)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("初始化加密服务失败: %v", err))
	}

	// 直接加密文本内容
	var encryptedData []byte
	plaintext := []byte(textContent)

	// 根据不同的加密方法进行加密
	switch m.config.Encryption.Method {
	case constants.AlgorithmRSA:
		encryptedData, err = encryptTextWithRSA(cryptoService, plaintext)
	case constants.AlgorithmKMAC:
		encryptedData, err = encryptTextWithKMAC(cryptoService, plaintext)
	default:
		return newOperationResult(false, fmt.Sprintf("不支持的加密方法: %s", m.config.Encryption.Method))
	}

	if err != nil {
		return newOperationResult(false, fmt.Sprintf("加密失败: %v", err))
	}

	// 计算处理时间
	processingTime := time.Since(startTime)

	// 将加密数据转换为十六进制字符串
	hexOutput := fmt.Sprintf("%x", encryptedData)

	// 返回触发十六进制输出的特殊结果
	return operationResult{
		success: true,
		message: "HEX_OUTPUT_TRIGGER",
		resultInfo: EncryptionResult{
			FileName:       "HEX_OUTPUT",
			FileSize:       0,
			Algorithm:      strings.ToUpper(m.config.Encryption.Method),
			EncryptionTime: processingTime.String(),
			OutputPath:     fmt.Sprintf("%s|%s|%s", hexOutput, textContent, strings.ToUpper(m.config.Encryption.Method)),
		},
	}
}
