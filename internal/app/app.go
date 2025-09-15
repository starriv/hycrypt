package app

import (
	"context"
	"crypto/rand"
	"fmt"
	"hycrypt/internal/config"
	"hycrypt/internal/constants"
	"hycrypt/internal/crypto"
	"hycrypt/internal/domain"
	interactivecli "hycrypt/internal/interactive-cli"
	"hycrypt/internal/output"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// App 应用程序结构
type App struct {
	config    *config.Config
	processor *crypto.UnifiedProcessor
	outputMgr *output.OutputManagerInterface
}

// Options 运行选项
type Options struct {
	FilePath     string
	TextMode     bool
	OutputDir    string
	OutputFormat string
	InputFormat  string
	Method       string
	Decrypt      bool
	Verbose      bool
}

// New 创建新的应用程序实例
func CreateApp(cfg *config.Config) (*App, error) {
	return WithOutputMode(cfg, output.ModeCLI)
}

// NewWithOutputMode 创建指定输出模式的应用程序实例
func WithOutputMode(cfg *config.Config, mode output.OutputMode) (*App, error) {
	// 确保配置和密钥已初始化
	if err := ensureKeysInitialized(cfg); err != nil {
		return nil, fmt.Errorf("failed to initialize keys: %w", err)
	}

	// 构建处理器配置
	processorConfig := &crypto.ProcessorConfig{}

	// 配置RSA - 仅当指定使用RSA方法时
	if cfg.Encryption.Method == constants.AlgorithmRSA {
		processorConfig.RSAConfig = &crypto.RSAConfig{
			PublicKeyPath:  cfg.GetPublicKeyPath(),
			PrivateKeyPath: cfg.GetPrivateKeyPath(),
			KeySize:        cfg.Encryption.RSAKeySize,
			AESKeySize:     cfg.Encryption.AESKeySize,
		}
	}

	// 配置KMAC - 仅当指定使用KMAC方法时
	if cfg.Encryption.Method == constants.AlgorithmKMAC {
		kmacKey, err := cfg.LoadKMACKey()
		if err != nil {
			return nil, fmt.Errorf("加载 KMAC 密钥失败: %w", err)
		}

		processorConfig.KMACConfig = &crypto.KMACConfig{
			Key:        kmacKey,
			KeySize:    cfg.Encryption.KMACKeySize,
			AESKeySize: cfg.Encryption.AESKeySize,
		}
	}

	processor, err := crypto.NewUnifiedProcessor(processorConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create processor: %w", err)
	}

	// 创建输出管理器
	outputConfig := &output.RendererConfig{
		UseEmoji:     cfg.Output.UseEmoji,
		UseColors:    mode == output.ModeCLI,
		ShowProgress: cfg.Output.ShowProgress,
		Verbose:      cfg.Output.Verbose,
	}

	var outputMgr *output.OutputManagerInterface
	if mode == output.ModeUI {
		outputMgr = output.BufferedOutputManager(mode, outputConfig)
	} else {
		outputMgr = output.OutputManager(mode, outputConfig)
	}

	return &App{
		config:    cfg,
		processor: processor,
		outputMgr: outputMgr,
	}, nil
}

// RunCLI 运行命令行模式
func (a *App) RunCLI(ctx context.Context, opts *Options) error {
	// 验证输入参数
	if err := a.validateCLIOptions(opts); err != nil {
		return err
	}

	// 对于解密操作，先尝试自动检测算法
	if opts.Decrypt && opts.Method == "" && !opts.TextMode {
		detected := a.detectMethodFromFile(opts.FilePath)
		if opts.Verbose {
			fmt.Printf("🔍 自动检测算法: %s\n", detected)
		}
		opts.Method = detected
	}

	// 如果仍未指定方法，使用配置中的默认方法
	if opts.Method == "" {
		opts.Method = a.config.Encryption.Method
	}

	// 构建加密选项
	cryptoOpts := domain.CryptoOptions{
		Method:       opts.Method,
		OutputFormat: parseOutputFormat(opts.OutputFormat),
		InputFormat:  parseInputFormat(opts.InputFormat),
		Verbose:      opts.Verbose,
	}

	// 确定输出目录
	outputDir := opts.OutputDir
	if outputDir == "" {
		// 根据隐私输出设置决定输出位置
		if a.config.Output.PrivateOutput {
			// 隐私输出开启：使用全局配置目录
			if opts.Decrypt {
				outputDir = a.config.GetDecryptedDirPath()
			} else {
				outputDir = a.config.GetEncryptedDirPath()
			}
		} else {
			// 隐私输出关闭：使用输入文件同目录
			if !opts.TextMode && opts.FilePath != "" {
				outputDir = filepath.Dir(opts.FilePath)
				if opts.Verbose {
					fmt.Printf("🔍 隐私输出关闭，使用输入文件同目录: %s\n", outputDir)
				}
			} else {
				// 文本模式或没有文件路径时，回退到配置目录
				if opts.Decrypt {
					outputDir = a.config.GetDecryptedDirPath()
				} else {
					outputDir = a.config.GetEncryptedDirPath()
				}
			}
		}
	}

	// 处理文本输入
	if opts.TextMode {
		return a.processTextInput(ctx, outputDir, opts.Decrypt, cryptoOpts)
	}

	// 处理文件输入
	return a.processFileInput(ctx, opts.FilePath, outputDir, opts.Decrypt, cryptoOpts)
}

// RunInteractive 运行交互模式
func (a *App) RunInteractive(ctx context.Context) error {
	return interactivecli.RunInteractiveUI(a.config)
}

func (a *App) validateCLIOptions(opts *Options) error {
	if !opts.TextMode && opts.FilePath == "" {
		return fmt.Errorf("must specify -f file path or -t text mode")
	}

	if opts.TextMode && opts.FilePath != "" {
		return fmt.Errorf("-f and -t options cannot be used together")
	}

	if opts.TextMode && opts.Decrypt && opts.InputFormat != "hex" {
		return fmt.Errorf("text mode decryption requires hex input format")
	}

	if opts.OutputFormat == "hex" && (!opts.TextMode || opts.Decrypt) {
		return fmt.Errorf("hex output format only supports text encryption mode")
	}

	if opts.InputFormat == "hex" && (!opts.TextMode || !opts.Decrypt) {
		return fmt.Errorf("hex input format only supports text decryption mode")
	}

	return nil
}

func (a *App) processTextInput(ctx context.Context, outputDir string, isDecrypt bool, opts domain.CryptoOptions) error {
	startTime := time.Now()
	// 读取标准输入
	var input string

	// 检查管道输入
	if stat, _ := os.Stdin.Stat(); (stat.Mode() & os.ModeCharDevice) == 0 {
		// 从管道读取
		data, err := os.ReadFile("/dev/stdin")
		if err != nil {
			return fmt.Errorf("failed to read from pipe: %w", err)
		}
		input = string(data)
	} else {
		// 交互式输入
		fmt.Print("请输入要处理的文本 (按 Ctrl+D 结束输入):\n")
		data, err := os.ReadFile("/dev/stdin")
		if err != nil {
			return fmt.Errorf("failed to read input: %w", err)
		}
		input = string(data)
	}

	if strings.TrimSpace(input) == "" {
		return fmt.Errorf("input is empty")
	}

	// 创建临时文件进行处理
	tempFile, err := a.createTempFile(input)
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tempFile)

	// 处理特殊的十六进制输出/解密
	if !isDecrypt && opts.OutputFormat == domain.OutputHex {
		// 文本加密，十六进制输出
		return a.processTextHexOutput(ctx, input, opts, startTime)
	} else if isDecrypt && opts.InputFormat == domain.InputHex {
		// 十六进制解密
		// 十六进制解密功能暂时通过 UI 层处理
		result := output.ErrorResultWithMessage("Hex decryption should be handled through UI layer")
		a.outputMgr.PrintResult(result)
		return fmt.Errorf("hex decryption should be handled through UI layer")
	}

	// 普通文件处理
	_, err = a.processor.ProcessFile(ctx, tempFile, outputDir, !isDecrypt, opts)
	if err != nil {
		result := output.ErrorResult(err)
		a.outputMgr.PrintResult(result)
		return err
	}

	// 构建统一结果
	processTime := time.Since(startTime)

	var result *output.OperationResult
	if isDecrypt {
		result = output.SmartDecryptionResult(tempFile, outputDir, strings.ToUpper(opts.Method), int64(len(input)), processTime)
	} else {
		result = output.SmartEncryptionResult(tempFile, outputDir, opts.Method, int64(len(input)), processTime)
	}

	a.outputMgr.PrintResult(result)
	return nil
}

func (a *App) processFileInput(ctx context.Context, filePath, outputDir string, isDecrypt bool, opts domain.CryptoOptions) error {
	startTime := time.Now()

	// 检查文件是否存在
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		result := output.ErrorResult(fmt.Errorf("file not found: %s", filePath))
		a.outputMgr.PrintResult(result)
		return err
	}

	// 处理文件
	_, err = a.processor.ProcessFile(ctx, filePath, outputDir, !isDecrypt, opts)
	if err != nil {
		result := output.ErrorResult(err)
		a.outputMgr.PrintResult(result)
		return err
	}

	// 构建统一结果
	processTime := time.Since(startTime)

	var result *output.OperationResult
	if isDecrypt {
		detectedAlgorithm := strings.ToUpper(opts.Method)
		result = output.SmartDecryptionResult(filePath, outputDir, detectedAlgorithm, fileInfo.Size(), processTime)
	} else {
		result = output.SmartEncryptionResult(filePath, outputDir, opts.Method, fileInfo.Size(), processTime)
	}

	a.outputMgr.PrintResult(result)
	return nil
}

func (a *App) createTempFile(content string) (string, error) {
	tempDir := os.TempDir()
	tempFile := filepath.Join(tempDir, fmt.Sprintf("hycrypt-text-%d.tmp", os.Getpid()))

	file, err := os.OpenFile(tempFile, os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0600)
	if err != nil {
		return "", err
	}
	defer file.Close()

	_, err = file.WriteString(content)
	return tempFile, err
}

func (a *App) detectMethodFromFile(filePath string) string {
	// 首先尝试使用配置中的现代算法检测器
	detected := a.config.DetectAlgorithmFromPath(filePath)
	if detected != "" && a.config.IsAlgorithmSupported(detected) {
		return detected
	}

	// 回退到简单的文件名检测
	fileName := filepath.Base(filePath)

	if strings.Contains(fileName, "-rsa.") || strings.Contains(fileName, ".rsa.") {
		return constants.AlgorithmRSA
	}
	if strings.Contains(fileName, "-kmac.") || strings.Contains(fileName, ".kmac.") {
		return constants.AlgorithmKMAC
	}

	return a.config.Encryption.Method // 默认使用配置中的方法
}

// processTextHexOutput 处理文本加密的十六进制输出
func (a *App) processTextHexOutput(ctx context.Context, text string, opts domain.CryptoOptions, startTime time.Time) error {
	// 这里需要直接调用加密服务进行文本加密
	// 暂时返回未实现错误
	result := output.ErrorResultWithMessage("Text hex output not implemented yet")
	a.outputMgr.PrintResult(result)
	return fmt.Errorf("text hex output not implemented yet")
}

func parseOutputFormat(format string) domain.OutputFormat {
	switch format {
	case "hex":
		return domain.OutputHex
	default:
		return domain.OutputFile
	}
}

func parseInputFormat(format string) domain.InputFormat {
	switch format {
	case "hex":
		return domain.InputHex
	case "text":
		return domain.InputText
	default:
		return domain.InputFile
	}
}

// ensureKeysInitialized 确保所需的密钥已初始化
func ensureKeysInitialized(cfg *config.Config) error {
	// 根据当前方法检查并初始化相应的密钥
	switch cfg.Encryption.Method {
	case constants.AlgorithmRSA:
		// 检查RSA密钥是否存在
		publicKeyPath := cfg.GetPublicKeyPath()
		privateKeyPath := cfg.GetPrivateKeyPath()

		_, pubErr := os.Stat(publicKeyPath)
		_, privErr := os.Stat(privateKeyPath)

		if os.IsNotExist(pubErr) || os.IsNotExist(privErr) {
			// RSA密钥不存在，调用全局配置初始化来生成
			fmt.Println("🔧 检测到RSA密钥缺失, 正在初始化...")
			if err := config.InitializeGlobalConfig(); err != nil {
				return fmt.Errorf("failed to initialize RSA keys: %w", err)
			}
		}

	case constants.AlgorithmKMAC:
		// 检查KMAC密钥是否存在
		if !cfg.CheckKMACKeyExists() {
			// KMAC密钥不存在，生成新的密钥
			fmt.Println("🔧 检测到KMAC密钥缺失, 正在生成...")
			keyBytes := make([]byte, cfg.Encryption.KMACKeySize)
			if _, err := rand.Read(keyBytes); err != nil {
				return fmt.Errorf("failed to generate KMAC key: %w", err)
			}

			if err := cfg.SaveKMACKey(keyBytes); err != nil {
				return fmt.Errorf("failed to save KMAC key: %w", err)
			}

			fmt.Printf("✅ KMAC 密钥已生成并保存到: %s\n", cfg.GetKMACKeyPath())
		}
	}

	return nil
}
