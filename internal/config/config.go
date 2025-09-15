package config

import (
	"encoding/hex"
	"fmt"
	"hycrypt/internal/constants"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

// Config 程序配置结构体
type Config struct {
	Keys        KeyConfig        `yaml:"keys"`
	Directories DirConfig        `yaml:"directories"`
	Encryption  EncryptionConfig `yaml:"encryption"`
	Output      OutputConfig     `yaml:"output"`
}

// KeyConfig 密钥相关配置
type KeyConfig struct {
	KeyDir     string `yaml:"key_dir"`
	PublicKey  string `yaml:"public_key"`
	PrivateKey string `yaml:"private_key"`
	KMACKey    string `yaml:"kmac_key"`
}

// DirConfig 目录相关配置
type DirConfig struct {
	EncryptedDir string `yaml:"encrypted_dir"`
	DecryptedDir string `yaml:"decrypted_dir"`
}

// EncryptionConfig 加密相关配置
type EncryptionConfig struct {
	Method           string   `yaml:"method"`
	SupportedMethods []string `yaml:"supported_methods"`
	RSAKeySize       int      `yaml:"rsa_key_size"`
	AESKeySize       int      `yaml:"aes_key_size"`
	KMACKeySize      int      `yaml:"kmac_key_size"`
	FileExtension    string   `yaml:"file_extension"`
}

// OutputConfig 输出相关配置
type OutputConfig struct {
	Verbose       bool `yaml:"verbose"`
	ShowProgress  bool `yaml:"show_progress"`
	UseEmoji      bool `yaml:"use_emoji"`
	PrivateOutput bool `yaml:"private_output"`
}

// Default 返回默认配置
func Default() *Config {
	return &Config{
		Keys: KeyConfig{
			KeyDir:     "keys", // 与根目录版本保持一致
			PublicKey:  "public.pem",
			PrivateKey: "private.pem",
			KMACKey:    "kmac.key", // 默认 KMAC 密钥文件名
		},
		Directories: DirConfig{
			EncryptedDir: "encrypted",
			DecryptedDir: "decrypted",
		},
		Encryption: EncryptionConfig{
			Method:           constants.AlgorithmRSA,        // 默认使用 RSA
			SupportedMethods: constants.SupportedAlgorithms, // 支持的算法列表
			RSAKeySize:       4096,                          // RSA-4096
			AESKeySize:       32,                            // AES-256
			KMACKeySize:      32,                            // KMAC 密钥 256 位
			FileExtension:    ".hycrypt",
		},
		Output: OutputConfig{
			Verbose:       false,
			ShowProgress:  true,
			UseEmoji:      true,
			PrivateOutput: true, // 默认开启隐私输出模式
		},
	}
}

// Load 从文件加载配置
func Load(configPath string) (*Config, error) {
	// 如果配置文件不存在，返回默认配置
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return Default(), nil
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	config := Default() // 从默认配置开始
	if err := yaml.Unmarshal(data, config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return config, nil
}

// Save 保存配置到文件
func Save(config *Config, configPath string) error {
	// 确保配置文件目录存在
	configDir := filepath.Dir(configPath)
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	data, err := yaml.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// GetPublicKeyPath 获取公钥文件完整路径
func (c *Config) GetPublicKeyPath() string {
	return filepath.Join(c.GetKeyDirPath(), c.Keys.PublicKey)
}

// GetPrivateKeyPath 获取私钥文件完整路径
func (c *Config) GetPrivateKeyPath() string {
	return filepath.Join(c.GetKeyDirPath(), c.Keys.PrivateKey)
}

// GetKMACKeyPath 获取 KMAC 密钥文件完整路径
func (c *Config) GetKMACKeyPath() string {
	return filepath.Join(c.GetKeyDirPath(), c.Keys.KMACKey)
}

// Validate 验证配置的有效性
func (c *Config) Validate() error {
	if c.Keys.KeyDir == "" {
		return fmt.Errorf("key directory cannot be empty")
	}

	// 验证支持的算法列表
	if len(c.Encryption.SupportedMethods) == 0 {
		return fmt.Errorf("supported methods list cannot be empty")
	}

	// 验证当前方法在支持列表中
	methodSupported := false
	for _, method := range c.Encryption.SupportedMethods {
		if method == c.Encryption.Method {
			methodSupported = true
			break
		}
	}
	if !methodSupported {
		return fmt.Errorf("encryption method '%s' is not in supported methods list: %v",
			c.Encryption.Method, c.Encryption.SupportedMethods)
	}

	// 根据加密方法验证相关配置
	if c.Encryption.Method == constants.AlgorithmRSA {
		if c.Keys.PublicKey == "" {
			return fmt.Errorf("public key filename cannot be empty in RSA mode")
		}
		if c.Keys.PrivateKey == "" {
			return fmt.Errorf("private key filename cannot be empty in RSA mode")
		}
		if c.Encryption.RSAKeySize != 2048 && c.Encryption.RSAKeySize != 3072 && c.Encryption.RSAKeySize != 4096 {
			return fmt.Errorf("RSA key size must be 2048, 3072 or 4096 bits")
		}
	} else if c.Encryption.Method == constants.AlgorithmKMAC {
		if c.Keys.KMACKey == "" {
			return fmt.Errorf("KMAC key filename cannot be empty in KMAC mode")
		}
		// 检查 KMAC 密钥文件是否存在
		kmacKeyPath := c.GetKMACKeyPath()
		if _, err := os.Stat(kmacKeyPath); os.IsNotExist(err) {
			return fmt.Errorf("KMAC key file not found: %s", kmacKeyPath)
		}
		if c.Encryption.KMACKeySize != 16 && c.Encryption.KMACKeySize != 32 && c.Encryption.KMACKeySize != 64 {
			return fmt.Errorf("KMAC key size must be 16, 32 or 64 bytes")
		}
	}

	if c.Directories.EncryptedDir == "" {
		return fmt.Errorf("encrypted directory cannot be empty")
	}

	if c.Directories.DecryptedDir == "" {
		return fmt.Errorf("decrypted directory cannot be empty")
	}

	if c.Encryption.AESKeySize != 16 && c.Encryption.AESKeySize != 24 && c.Encryption.AESKeySize != 32 {
		return fmt.Errorf("AES key size must be 16, 24 or 32 bytes")
	}

	if c.Encryption.FileExtension == "" {
		return fmt.Errorf("file extension cannot be empty")
	}

	return nil
}

// ApplyOverrides 应用命令行覆盖
type CLIOptions interface {
	GetKeyDir() string
	GetMethod() string
	GetVerbose() bool
}

func (c *Config) ApplyOverrides(opts CLIOptions) {
	if keyDir := opts.GetKeyDir(); keyDir != "" {
		c.Keys.KeyDir = keyDir
	}
	if method := opts.GetMethod(); method != "" {
		c.Encryption.Method = method
	}
	if opts.GetVerbose() {
		c.Output.Verbose = true
	}
}

// AlgorithmDetector 算法检测器接口
type AlgorithmDetector interface {
	// DetectFromPath 从文件路径检测算法
	DetectFromPath(filePath string) string
	// GetSupportedAlgorithms 获取支持的算法列表
	GetSupportedAlgorithms() []string
	// IsSupported 检查算法是否受支持
	IsSupported(algorithm string) bool
}

// StandardAlgorithmDetector 标准算法检测器实现
type StandardAlgorithmDetector struct {
	supportedAlgorithms []string
	fileExtension       string
}

// CreateStandardDetector 创建标准算法检测器
func CreateStandardDetector(supportedAlgorithms []string, fileExtension string) *StandardAlgorithmDetector {
	return &StandardAlgorithmDetector{
		supportedAlgorithms: supportedAlgorithms,
		fileExtension:       fileExtension,
	}
}

// DetectFromPath 从文件路径检测算法
func (d *StandardAlgorithmDetector) DetectFromPath(filePath string) string {
	fileName := filepath.Base(filePath)

	// 构建支持的算法列表的正则表达式，使用简单的 | 分隔符
	algorithmPattern := d.supportedAlgorithms[0]
	for i := 1; i < len(d.supportedAlgorithms); i++ {
		algorithmPattern += "|" + d.supportedAlgorithms[i]
	}

	// 先尝试匹配 .zip.encrypted 格式（目录）
	zipPattern := fmt.Sprintf(`.*-[a-z0-9]{6}-[0-9]{8}-(%s)\.zip%s$`,
		algorithmPattern, regexp.QuoteMeta(d.fileExtension))
	re := regexp.MustCompile(zipPattern)
	matches := re.FindStringSubmatch(fileName)

	if len(matches) >= 2 && matches[1] != "" && d.IsSupported(matches[1]) {
		return matches[1]
	}

	// 再尝试匹配普通 .encrypted 格式（文件）
	filePattern := fmt.Sprintf(`.*-[a-z0-9]{6}-[0-9]{8}-(%s)%s$`,
		algorithmPattern, regexp.QuoteMeta(d.fileExtension))
	re = regexp.MustCompile(filePattern)
	matches = re.FindStringSubmatch(fileName)

	if len(matches) >= 2 && matches[1] != "" && d.IsSupported(matches[1]) {
		return matches[1]
	}

	return ""
}

// GetSupportedAlgorithms 获取支持的算法列表
func (d *StandardAlgorithmDetector) GetSupportedAlgorithms() []string {
	return append([]string{}, d.supportedAlgorithms...) // 返回副本
}

// IsSupported 检查算法是否受支持
func (d *StandardAlgorithmDetector) IsSupported(algorithm string) bool {
	for _, supported := range d.supportedAlgorithms {
		if supported == algorithm {
			return true
		}
	}
	return false
}

// 配置扩展方法 - 算法检测器
type configWithDetector struct {
	*Config
	algorithmDetector AlgorithmDetector
}

// GetAlgorithmDetector 获取配置的算法检测器
func (c *Config) GetAlgorithmDetector() AlgorithmDetector {
	// 创建一个包装器来支持算法检测器
	wrapper := &configWithDetector{Config: c}
	if wrapper.algorithmDetector == nil {
		// 延迟初始化算法检测器
		wrapper.algorithmDetector = CreateStandardDetector(
			c.Encryption.SupportedMethods,
			c.Encryption.FileExtension,
		)
	}
	return wrapper.algorithmDetector
}

// DetectAlgorithmFromPath 使用配置的算法检测器检测算法
func (c *Config) DetectAlgorithmFromPath(filePath string) string {
	return c.GetAlgorithmDetector().DetectFromPath(filePath)
}

// IsAlgorithmSupported 检查算法是否受支持
func (c *Config) IsAlgorithmSupported(algorithm string) bool {
	return c.GetAlgorithmDetector().IsSupported(algorithm)
}

// GetSupportedAlgorithms 获取支持的算法列表
func (c *Config) GetSupportedAlgorithms() []string {
	return c.GetAlgorithmDetector().GetSupportedAlgorithms()
}

// 全局配置相关方法

// GetGlobalConfigDir 获取全局配置目录路径
func GetGlobalConfigDir() (string, error) {
	usr, err := user.Current()
	if err != nil {
		return "", fmt.Errorf("获取用户目录失败: %w", err)
	}
	return filepath.Join(usr.HomeDir, ".hycrypt"), nil
}

// GetGlobalConfigPath 获取全局配置文件路径
func GetGlobalConfigPath() (string, error) {
	configDir, err := GetGlobalConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(configDir, "config.yaml"), nil
}

// InitializeGlobalConfig 初始化全局配置目录和配置文件
func InitializeGlobalConfig() error {
	configDir, err := GetGlobalConfigDir()
	if err != nil {
		return err
	}

	// 创建配置目录
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return fmt.Errorf("创建配置目录失败: %w", err)
	}

	// 创建密钥目录
	keyDir := filepath.Join(configDir, "keys")
	if err := os.MkdirAll(keyDir, 0700); err != nil { // 密钥目录权限更严格
		return fmt.Errorf("创建密钥目录失败: %w", err)
	}

	// 创建输出目录
	encryptedDir := filepath.Join(configDir, "encrypted")
	decryptedDir := filepath.Join(configDir, "decrypted")

	if err := os.MkdirAll(encryptedDir, 0755); err != nil {
		return fmt.Errorf("创建加密输出目录失败: %w", err)
	}

	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		return fmt.Errorf("创建解密输出目录失败: %w", err)
	}

	// 检查配置文件是否存在
	configPath := filepath.Join(configDir, "config.yaml")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		// 配置文件不存在，从模板创建
		if err := createConfigFromTemplate(configPath); err != nil {
			return fmt.Errorf("创建配置文件失败: %w", err)
		}

		// 生成默认RSA密钥对
		if err := generateDefaultRSAKeys(keyDir); err != nil {
			// RSA密钥生成失败不阻止程序运行，只记录错误
			fmt.Printf("⚠️  警告: 生成默认RSA密钥失败: %v\n", err)
		}
	}

	return nil
}

// generateDefaultRSAKeys 生成默认的RSA密钥对
func generateDefaultRSAKeys(keyDir string) error {
	privateKeyPath := filepath.Join(keyDir, "private.pem")
	publicKeyPath := filepath.Join(keyDir, "public.pem")

	// 检查密钥是否已存在
	if _, err := os.Stat(privateKeyPath); err == nil {
		return nil // 密钥已存在，跳过生成
	}

	// 检查openssl是否可用
	if _, err := exec.LookPath("openssl"); err != nil {
		return fmt.Errorf("openssl 命令未找到，请手动生成RSA密钥")
	}

	// 生成私钥
	cmd := exec.Command("openssl", "genrsa", "-out", privateKeyPath, "4096")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("生成RSA私钥失败: %w", err)
	}

	// 设置私钥文件权限
	if err := os.Chmod(privateKeyPath, 0600); err != nil {
		return fmt.Errorf("设置私钥文件权限失败: %w", err)
	}

	// 生成公钥
	cmd = exec.Command("openssl", constants.AlgorithmRSA, "-in", privateKeyPath, "-pubout", "-out", publicKeyPath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("生成RSA公钥失败: %w", err)
	}

	fmt.Printf("✅ 默认RSA密钥对已生成:\n")
	fmt.Printf("  - 公钥: %s\n", publicKeyPath)
	fmt.Printf("  - 私钥: %s\n", privateKeyPath)

	return nil
}

// createConfigFromTemplate 从模板创建配置文件
func createConfigFromTemplate(configPath string) error {
	config := Default()

	// 调整路径为相对于配置目录的路径
	config.Keys.KeyDir = "keys"
	config.Directories.EncryptedDir = "encrypted"
	config.Directories.DecryptedDir = "decrypted"

	// 不再在配置文件中生成KMAC密钥，将使用独立的密钥文件

	// 保存配置
	return Save(config, configPath)
}

// LoadConfigWithPriority 按优先级加载配置文件
// 优先级：指定路径 > 全局配置 > 当前目录配置 > 默认配置
func LoadConfigWithPriority(specifiedPath string) (*Config, error) {
	var configPath string
	var err error

	// 1. 如果指定了配置路径，使用指定路径
	if specifiedPath != "" && specifiedPath != "config.yaml" {
		configPath = specifiedPath
	} else {
		// 2. 优先使用全局配置
		globalConfigPath, err := GetGlobalConfigPath()
		if err == nil {
			if _, err := os.Stat(globalConfigPath); err == nil {
				configPath = globalConfigPath
			}
		}

		// 3. 如果全局配置不存在，尝试当前目录的config.yaml
		if configPath == "" {
			if _, err := os.Stat("config.yaml"); err == nil {
				configPath = "config.yaml"
			}
		}
	}

	// 如果找到配置文件，加载它
	if configPath != "" {
		return Load(configPath)
	}

	// 4. 都不存在，初始化全局配置并使用
	if err := InitializeGlobalConfig(); err != nil {
		// 如果初始化失败，返回默认配置
		return Default(), nil
	}

	globalConfigPath, err := GetGlobalConfigPath()
	if err != nil {
		return Default(), nil
	}

	return Load(globalConfigPath)
}

// UpdatePrivacyOutputSetting 更新隐私输出设置并保存配置
func (c *Config) UpdatePrivacyOutputSetting(enabled bool) error {
	c.Output.PrivateOutput = enabled

	// 获取全局配置路径
	globalConfigPath, err := GetGlobalConfigPath()
	if err != nil {
		return fmt.Errorf("获取配置路径失败: %w", err)
	}

	// 保存配置
	return Save(c, globalConfigPath)
}

// GetKeyDirPath 获取密钥目录完整路径
func (c *Config) GetKeyDirPath() string {
	keyDir := c.Keys.KeyDir
	if !filepath.IsAbs(keyDir) {
		// 如果不是绝对路径，则基于全局配置目录
		if globalConfigDir, err := GetGlobalConfigDir(); err == nil {
			keyDir = filepath.Join(globalConfigDir, keyDir)
		}
	}
	return keyDir
}

// GetEncryptedDirPath 获取加密输出目录完整路径
func (c *Config) GetEncryptedDirPath() string {
	dirPath := c.Directories.EncryptedDir
	// 如果是相对路径，转换为基于全局配置目录的绝对路径
	if !filepath.IsAbs(dirPath) {
		if configDir, err := GetGlobalConfigDir(); err == nil {
			dirPath = filepath.Join(configDir, dirPath)
		}
	}
	return dirPath
}

// GetDecryptedDirPath 获取解密输出目录完整路径
func (c *Config) GetDecryptedDirPath() string {
	dirPath := c.Directories.DecryptedDir
	// 如果是相对路径，转换为基于全局配置目录的绝对路径
	if !filepath.IsAbs(dirPath) {
		if configDir, err := GetGlobalConfigDir(); err == nil {
			dirPath = filepath.Join(configDir, dirPath)
		}
	}
	return dirPath
}

// LoadKMACKey 从独立文件加载 KMAC 密钥
func (c *Config) LoadKMACKey() ([]byte, error) {
	kmacKeyPath := c.GetKMACKeyPath()

	// 读取密钥文件
	keyData, err := os.ReadFile(kmacKeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read KMAC key file: %w", err)
	}

	// 去除可能的换行符
	keyStr := string(keyData)
	keyStr = strings.TrimSpace(keyStr)

	// 验证十六进制格式
	keyBytes, err := hex.DecodeString(keyStr)
	if err != nil {
		return nil, fmt.Errorf("invalid KMAC key format: %w", err)
	}

	// 验证密钥长度
	if len(keyBytes) != c.Encryption.KMACKeySize {
		return nil, fmt.Errorf("KMAC key length mismatch: expected %d bytes, got %d", c.Encryption.KMACKeySize, len(keyBytes))
	}

	return keyBytes, nil
}

// SaveKMACKey 保存 KMAC 密钥到独立文件
func (c *Config) SaveKMACKey(keyBytes []byte) error {
	kmacKeyPath := c.GetKMACKeyPath()

	// 确保密钥目录存在
	keyDir := c.GetKeyDirPath()
	if err := os.MkdirAll(keyDir, 0700); err != nil {
		return fmt.Errorf("failed to create key directory: %w", err)
	}

	// 将密钥转换为十六进制字符串
	keyStr := hex.EncodeToString(keyBytes)

	// 写入密钥文件
	if err := os.WriteFile(kmacKeyPath, []byte(keyStr), 0600); err != nil {
		return fmt.Errorf("failed to write KMAC key file: %w", err)
	}

	return nil
}

// CheckKMACKeyExists 检查 KMAC 密钥文件是否存在
func (c *Config) CheckKMACKeyExists() bool {
	kmacKeyPath := c.GetKMACKeyPath()
	_, err := os.Stat(kmacKeyPath)
	return err == nil
}
