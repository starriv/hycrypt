package interactivecli

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"hycrypt/internal/config"
	"hycrypt/internal/constants"
	"hycrypt/internal/crypto"
	"hycrypt/internal/domain"
)

// Note: UI types and UIStateManager are defined in state_manager.go

// 工具函数
func cleanHexInput(input string) string {
	// 移除所有空白字符和其他可能的分隔符
	cleaned := regexp.MustCompile(`[\s=]`).ReplaceAllString(input, "")
	return strings.ToLower(cleaned)
}

func createSecureTempFile(content string) (string, error) {
	tmpDir := os.TempDir()
	timestamp := time.Now().UnixNano()
	tmpFile := filepath.Join(tmpDir, fmt.Sprintf("crypto-text-%d.tmp", timestamp))

	err := os.WriteFile(tmpFile, []byte(content), 0600)
	if err != nil {
		return "", err
	}

	return tmpFile, nil
}

// Note: Crypto service functions have been moved to their respective packages

// CryptoServiceInterface interface for UI layer
type CryptoServiceInterface interface {
	EncryptPath(targetPath, outputDir string) (string, error)
	DecryptPath(targetPath, outputDir string) (string, error)
}

// UICryptoService UI加密服务实现
type UICryptoService struct {
	processor *crypto.UnifiedProcessor
	config    *config.Config
}

// CryptoService creates a crypto service using UnifiedProcessor
func CryptoService(cfg interface{}) (CryptoServiceInterface, error) {
	config, ok := cfg.(*config.Config)
	if !ok {
		return nil, fmt.Errorf("invalid config type")
	}

	// 构建处理器配置
	processorConfig := &crypto.ProcessorConfig{}

	// 配置RSA
	if config.Encryption.Method == constants.AlgorithmRSA || config.Keys.PublicKey != "" {
		processorConfig.RSAConfig = &crypto.RSAConfig{
			PublicKeyPath:  config.GetPublicKeyPath(),
			PrivateKeyPath: config.GetPrivateKeyPath(),
			KeySize:        config.Encryption.RSAKeySize,
			AESKeySize:     config.Encryption.AESKeySize,
		}
	}

	// 配置KMAC
	if config.Encryption.Method == constants.AlgorithmKMAC || config.CheckKMACKeyExists() {
		if config.CheckKMACKeyExists() {
			kmacKey, err := config.LoadKMACKey()
			if err != nil {
				return nil, fmt.Errorf("加载 KMAC 密钥失败: %w", err)
			}

			processorConfig.KMACConfig = &crypto.KMACConfig{
				Key:        kmacKey,
				KeySize:    config.Encryption.KMACKeySize,
				AESKeySize: config.Encryption.AESKeySize,
			}
		}
	}

	processor, err := crypto.NewUnifiedProcessor(processorConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create processor: %w", err)
	}

	return &UICryptoService{
		processor: processor,
		config:    config,
	}, nil
}

// EncryptPath 加密路径
func (s *UICryptoService) EncryptPath(targetPath, outputDir string) (string, error) {
	opts := domain.CryptoOptions{
		Method:       s.config.Encryption.Method,
		OutputFormat: domain.OutputFile,
		InputFormat:  domain.InputFile,
		Verbose:      false,
	}

	result, err := s.processor.ProcessFile(context.Background(), targetPath, outputDir, true, opts)
	if err != nil {
		return "", err
	}

	return result.OutputPath, nil
}

// DecryptPath 解密路径
func (s *UICryptoService) DecryptPath(targetPath, outputDir string) (string, error) {
	// 自动检测算法
	method := s.config.DetectAlgorithmFromPath(targetPath)
	if method == "" {
		method = s.config.Encryption.Method
	}

	opts := domain.CryptoOptions{
		Method:       method,
		OutputFormat: domain.OutputFile,
		InputFormat:  domain.InputFile,
		Verbose:      false,
	}

	result, err := s.processor.ProcessFile(context.Background(), targetPath, outputDir, false, opts)
	if err != nil {
		return "", err
	}

	return result.OutputPath, nil
}

// Text encryption/decryption functions
func encryptTextWithRSA(service interface{}, data []byte) ([]byte, error) {
	return encryptTextWithMethod(service, data, constants.AlgorithmRSA)
}

func encryptTextWithKMAC(service interface{}, data []byte) ([]byte, error) {
	return encryptTextWithMethod(service, data, constants.AlgorithmKMAC)
}

func decryptDataWithRSA(service interface{}, data []byte) ([]byte, error) {
	return decryptDataWithMethod(service, data, constants.AlgorithmRSA)
}

func decryptDataWithKMAC(service interface{}, data []byte) ([]byte, error) {
	return decryptDataWithMethod(service, data, constants.AlgorithmKMAC)
}

// encryptTextWithMethod 使用指定方法加密文本
func encryptTextWithMethod(service interface{}, data []byte, method string) ([]byte, error) {
	uiService, ok := service.(*UICryptoService)
	if !ok {
		return nil, fmt.Errorf("invalid service type")
	}

	// 创建临时文件存储文本内容
	tmpFile, err := createSecureTempFile(string(data))
	if err != nil {
		return nil, fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile)

	// 创建临时输出目录
	tmpDir, err := os.MkdirTemp("", "hycrypt-encrypt-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	// 临时更改配置方法
	originalMethod := uiService.config.Encryption.Method
	uiService.config.Encryption.Method = method
	defer func() {
		uiService.config.Encryption.Method = originalMethod
	}()

	// 执行加密
	opts := domain.CryptoOptions{
		Method:       method,
		OutputFormat: domain.OutputFile,
		InputFormat:  domain.InputFile,
		Verbose:      false,
	}

	_, err = uiService.processor.ProcessFile(context.Background(), tmpFile, tmpDir, true, opts)
	if err != nil {
		return nil, fmt.Errorf("encryption failed: %w", err)
	}

	// 读取加密后的文件内容
	encryptedFiles, err := filepath.Glob(filepath.Join(tmpDir, "*"))
	if err != nil || len(encryptedFiles) == 0 {
		return nil, fmt.Errorf("no encrypted file found")
	}

	encryptedData, err := os.ReadFile(encryptedFiles[0])
	if err != nil {
		return nil, fmt.Errorf("failed to read encrypted file: %w", err)
	}

	return encryptedData, nil
}

// decryptDataWithMethod 使用指定方法解密数据
func decryptDataWithMethod(service interface{}, data []byte, method string) ([]byte, error) {
	uiService, ok := service.(*UICryptoService)
	if !ok {
		return nil, fmt.Errorf("invalid service type")
	}

	// 创建临时文件存储加密数据
	tmpDir, err := os.MkdirTemp("", "hycrypt-decrypt-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	// 创建临时加密文件
	tmpEncryptedFile := filepath.Join(tmpDir, "encrypted.hycrypt")
	if err := os.WriteFile(tmpEncryptedFile, data, 0600); err != nil {
		return nil, fmt.Errorf("failed to write encrypted file: %w", err)
	}

	// 创建输出目录
	outputDir := filepath.Join(tmpDir, "output")
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create output dir: %w", err)
	}

	// 临时更改配置方法
	originalMethod := uiService.config.Encryption.Method
	uiService.config.Encryption.Method = method
	defer func() {
		uiService.config.Encryption.Method = originalMethod
	}()

	// 执行解密
	opts := domain.CryptoOptions{
		Method:       method,
		OutputFormat: domain.OutputFile,
		InputFormat:  domain.InputFile,
		Verbose:      false,
	}

	_, err = uiService.processor.ProcessFile(context.Background(), tmpEncryptedFile, outputDir, false, opts)
	if err != nil {
		return nil, fmt.Errorf("decryption failed: %w", err)
	}

	// 读取解密后的文件内容
	decryptedFiles, err := filepath.Glob(filepath.Join(outputDir, "*"))
	if err != nil || len(decryptedFiles) == 0 {
		return nil, fmt.Errorf("no decrypted file found")
	}

	decryptedData, err := os.ReadFile(decryptedFiles[0])
	if err != nil {
		return nil, fmt.Errorf("failed to read decrypted file: %w", err)
	}

	return decryptedData, nil
}
