package crypto

import (
	"context"
	"fmt"
	"hycrypt/internal/constants"
	"hycrypt/internal/datasink"
	"hycrypt/internal/datasource"
	"hycrypt/internal/domain"
	"hycrypt/internal/errors"
	"hycrypt/internal/naming"
	"hycrypt/internal/utils"
	"os"
	"path/filepath"
	"time"
)

// ProcessorConfig 处理器配置
type ProcessorConfig struct {
	RSAConfig  *RSAConfig
	KMACConfig *KMACConfig
}

// RSAConfig RSA配置
type RSAConfig struct {
	PublicKeyPath  string
	PrivateKeyPath string
	KeySize        int
	AESKeySize     int
}

// KMACConfig KMAC配置
type KMACConfig struct {
	Key        []byte
	KeySize    int
	AESKeySize int
}

// UnifiedProcessor 统一加密处理器
type UnifiedProcessor struct {
	rsaService  *RSAServiceInterface
	kmacService *KMACServiceInterface
	config      *ProcessorConfig
	strategy    domain.FileNameStrategy
}

func NewUnifiedProcessor(config *ProcessorConfig) (*UnifiedProcessor, error) {
	processor := &UnifiedProcessor{
		config:   config,
		strategy: naming.DefaultStrategy(".hycrypt"),
	}

	// 初始化 RSA 服务（如果配置存在）
	if config.RSAConfig != nil {
		rsaService, err := RSAService(config.RSAConfig)
		if err != nil {
			return nil, errors.InvalidConfig("failed to initialize RSA service", err)
		}
		processor.rsaService = rsaService
	}

	// 初始化 KMAC 服务（如果配置存在）
	if config.KMACConfig != nil {
		kmacService, err := KMACService(config.KMACConfig)
		if err != nil {
			return nil, errors.InvalidConfig("failed to initialize KMAC service", err)
		}
		processor.kmacService = kmacService
	}

	return processor, nil
}

func (p *UnifiedProcessor) Encrypt(ctx context.Context, source domain.DataSource, sink domain.DataSink, opts domain.CryptoOptions) (*domain.CryptoResult, error) {
	startTime := time.Now()

	// 选择加密服务
	cryptoService, err := p.getCryptoService(opts.Method)
	if err != nil {
		return nil, err
	}

	// 读取数据
	reader, err := source.Read(ctx)
	if err != nil {
		return nil, errors.EncryptionFailed(opts.Method, err)
	}
	defer reader.Close()

	// 执行加密
	result, err := cryptoService.EncryptData(ctx, reader)
	if err != nil {
		return nil, errors.EncryptionFailed(opts.Method, err)
	}

	// 写入结果
	if err := sink.Write(ctx, result); err != nil {
		return nil, errors.EncryptionFailed(opts.Method, err)
	}

	return &domain.CryptoResult{
		Success:       true,
		OutputPath:    sink.Path(),
		ProcessedSize: source.Size(),
		Method:        opts.Method,
		ProcessTime:   time.Since(startTime).Milliseconds(),
	}, nil
}

func (p *UnifiedProcessor) Decrypt(ctx context.Context, source domain.DataSource, sink domain.DataSink, opts domain.CryptoOptions) (*domain.CryptoResult, error) {
	startTime := time.Now()

	// 自动检测加密方法（如果未指定）
	method := opts.Method
	if method == "" {
		method = p.detectEncryptionMethod(source.Name())
		if method == "" {
			return nil, errors.DecryptionFailed("unknown", fmt.Errorf("cannot detect encryption method"))
		}
	}

	// 选择解密服务
	cryptoService, err := p.getCryptoService(method)
	if err != nil {
		return nil, err
	}

	// 读取数据
	reader, err := source.Read(ctx)
	if err != nil {
		return nil, errors.DecryptionFailed(method, err)
	}
	defer reader.Close()

	// 执行解密
	result, err := cryptoService.DecryptData(ctx, reader)
	if err != nil {
		return nil, errors.DecryptionFailed(method, err)
	}

	// 写入结果
	if err := sink.Write(ctx, result); err != nil {
		return nil, errors.DecryptionFailed(method, err)
	}

	// 检查是否为目录压缩包，如果是则自动解压
	encryptedFileName := filepath.Base(source.Name())
	_, _, _, isDirectory := p.strategy.ParseEncryptedName(encryptedFileName)

	outputPath := sink.Path()
	if isDirectory {
		// 解压zip文件到目录
		outputPath, err = p.handleDirectoryDecryption(sink.Path())
		if err != nil {
			return nil, errors.DecryptionFailed(method, fmt.Errorf("failed to extract directory: %w", err))
		}
	}

	return &domain.CryptoResult{
		Success:       true,
		OutputPath:    outputPath,
		ProcessedSize: source.Size(),
		Method:        method,
		ProcessTime:   time.Since(startTime).Milliseconds(),
	}, nil
}

func (p *UnifiedProcessor) ValidateConfig() error {
	if p.rsaService == nil && p.kmacService == nil {
		return errors.InvalidConfig("no crypto service available", nil)
	}
	return nil
}

func (p *UnifiedProcessor) getCryptoService(method string) (CryptoService, error) {
	switch method {
	case constants.AlgorithmRSA:
		if p.rsaService == nil {
			return nil, errors.InvalidConfig("RSA service not available", nil)
		}
		return p.rsaService, nil
	case constants.AlgorithmKMAC:
		if p.kmacService == nil {
			return nil, errors.InvalidConfig("KMAC service not available", nil)
		}
		return p.kmacService, nil
	default:
		return nil, errors.InvalidConfig(fmt.Sprintf("unsupported method: %s", method), nil)
	}
}

func (p *UnifiedProcessor) detectEncryptionMethod(fileName string) string {
	if !p.strategy.IsEncryptedFile(fileName) {
		return ""
	}

	_, method, _, _ := p.strategy.ParseEncryptedName(fileName)
	return method
}

// ProcessFile 便捷方法：处理文件
func (p *UnifiedProcessor) ProcessFile(ctx context.Context, inputPath, outputDir string, isEncrypt bool, opts domain.CryptoOptions) (*domain.CryptoResult, error) {
	// 创建数据源
	var source domain.DataSource
	var err error

	if isEncrypt {
		source, err = datasource.CreateSource(inputPath, opts.InputFormat)
	} else {
		source, err = datasource.FileSource(inputPath)
	}

	if err != nil {
		return nil, err
	}

	// 生成输出文件名
	var fileName string
	if isEncrypt {
		// 根据数据源类型选择适当的命名策略
		if source.Type() == "directory" {
			// 使用目录命名策略，只使用目录的基本名称
			baseName := filepath.Base(source.Name())
			dirStrategy := naming.CreateDirectoryStrategy(".hycrypt")
			fileName = dirStrategy.GenerateEncryptedName(baseName, opts.Method)
		} else {
			// 对于普通文件，只使用文件名部分，不使用完整路径
			baseName := filepath.Base(source.Name())
			fileName = p.strategy.GenerateEncryptedName(baseName, opts.Method)
		}
	} else {
		// 解密时只使用文件名部分，不使用完整路径
		encryptedFileName := filepath.Base(source.Name())
		originalName, _, _, isDirectory := p.strategy.ParseEncryptedName(encryptedFileName)

		if isDirectory {
			// 对于目录，解密后应该是一个目录名
			fileName = originalName
		} else {
			fileName = originalName
		}
	}

	// 构建完整输出路径
	outputPath := filepath.Join(outputDir, fileName)

	// 创建数据输出
	sink, err := datasink.CreateSink(outputPath, opts.OutputFormat)
	if err != nil {
		return nil, err
	}
	defer sink.Close()

	// 执行处理
	if isEncrypt {
		return p.Encrypt(ctx, source, sink, opts)
	} else {
		return p.Decrypt(ctx, source, sink, opts)
	}
}

// handleDirectoryDecryption 处理目录解密（解压zip文件）
func (p *UnifiedProcessor) handleDirectoryDecryption(zipFilePath string) (string, error) {
	// 确定目标目录路径
	dir := filepath.Dir(zipFilePath)
	baseName := filepath.Base(zipFilePath)

	// zipFilePath 实际就是解密后的zip文件，我们需要将其解压
	targetDir := filepath.Join(dir, baseName+"_extracted")

	// 解压zip文件到临时目录
	if err := utils.UnzipFile(zipFilePath, targetDir); err != nil {
		return "", fmt.Errorf("failed to unzip directory: %w", err)
	}

	// 删除原zip文件
	os.Remove(zipFilePath)

	// 将解压后的内容移动到正确的目录名
	finalDir := filepath.Join(dir, baseName)
	if err := os.Rename(targetDir, finalDir); err != nil {
		return "", fmt.Errorf("failed to rename extracted directory: %w", err)
	}

	return finalDir, nil
}
