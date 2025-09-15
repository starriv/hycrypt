package interactivecli

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"hycrypt/internal/config"
)

// RSA 密钥确认状态处理
func (m Model) updateRSAKeyConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	case "y", "Y":
		// 用户确认覆盖，开始生成
		m.state = stateProcessing
		return m, tea.Cmd(func() tea.Msg {
			return m.generateRSAKeys(true) // 覆盖模式
		})
	case "n", "N":
		// 用户拒绝覆盖，返回密钥生成菜单
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	}
	return m, nil
}

func (m Model) viewRSAKeyConfirm() string {
	s := titleStyle.Render("⚠️  RSA 密钥已存在") + "\n\n"

	// 优先显示全局配置路径中的密钥
	var publicKeyPath, privateKeyPath string
	var isGlobal bool

	globalConfigDir, err := config.GetGlobalConfigDir()
	if err == nil {
		globalPublicKeyPath := filepath.Join(globalConfigDir, "keys", "public.pem")
		globalPrivateKeyPath := filepath.Join(globalConfigDir, "keys", "private.pem")

		_, pubErr := os.Stat(globalPublicKeyPath)
		_, privErr := os.Stat(globalPrivateKeyPath)

		if pubErr == nil || privErr == nil {
			publicKeyPath = globalPublicKeyPath
			privateKeyPath = globalPrivateKeyPath
			isGlobal = true
		}
	}

	if !isGlobal {
		publicKeyPath = m.config.GetPublicKeyPath()
		privateKeyPath = m.config.GetPrivateKeyPath()
	}

	if isGlobal {
		s += "检测到以下全局 RSA 密钥文件：\n\n"
	} else {
		s += "检测到以下本地 RSA 密钥文件：\n\n"
	}

	if _, err := os.Stat(publicKeyPath); err == nil {
		s += successStyle.Render("✓ 公钥文件: "+publicKeyPath) + "\n"
	}

	if _, err := os.Stat(privateKeyPath); err == nil {
		s += successStyle.Render("✓ 私钥文件: "+privateKeyPath) + "\n"
	}

	s += "\n" + errorStyle.Render("警告: 覆盖现有密钥将使用旧密钥加密的文件无法解密！") + "\n\n"
	s += "是否要覆盖现有密钥？\n\n"
	s += selectedStyle.Render("Y") + " - 是，覆盖现有密钥\n"
	s += choiceStyle.Render("N") + " - 否，保留现有密钥\n\n"
	s += infoStyle.Render("ESC: 返回上级")

	return s
}

// KMAC 密钥确认状态处理
func (m Model) updateKMACKeyConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	case "y", "Y":
		// 用户确认覆盖，开始生成
		m.state = stateProcessing
		return m, tea.Cmd(func() tea.Msg {
			return m.generateKMACKey(true) // 覆盖模式
		})
	case "n", "N":
		// 用户拒绝覆盖，返回密钥生成菜单
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	}
	return m, nil
}

func (m Model) viewKMACKeyConfirm() string {
	s := titleStyle.Render("⚠️  KMAC 密钥已存在") + "\n\n"

	var keyPath string
	var configLocation string

	// 优先检查全局配置中的KMAC密钥文件
	globalConfigPath, err := config.GetGlobalConfigPath()
	if err == nil {
		if _, err := os.Stat(globalConfigPath); err == nil {
			globalConfig, err := config.Load(globalConfigPath)
			if err == nil && globalConfig.CheckKMACKeyExists() {
				keyPath = globalConfig.GetKMACKeyPath()
				configLocation = "全局配置"
			}
		}
	}

	// 如果全局配置中没有找到，使用本地配置
	if keyPath == "" {
		if m.config.CheckKMACKeyExists() {
			keyPath = m.config.GetKMACKeyPath()
			configLocation = "本地配置"
		}
	}

	s += fmt.Sprintf("检测到%s中已有 KMAC 密钥文件：\n\n", configLocation)
	s += successStyle.Render("✓ 密钥文件路径: "+keyPath) + "\n\n"

	s += errorStyle.Render("警告: 覆盖现有密钥将使用旧密钥加密的文件无法解密！") + "\n\n"
	s += "是否要生成新的 KMAC 密钥？\n\n"
	s += selectedStyle.Render("Y") + " - 是，生成新密钥\n"
	s += choiceStyle.Render("N") + " - 否，保留现有密钥\n\n"
	s += infoStyle.Render("ESC: 返回上级")

	return s
}

// 生成 RSA 密钥对
func (m Model) generateRSAKeys(overwrite bool) operationResult {
	// 优先使用全局配置路径
	var keyDir, publicKeyPath, privateKeyPath string

	globalConfigDir, err := config.GetGlobalConfigDir()
	if err == nil {
		keyDir = filepath.Join(globalConfigDir, "keys")
		publicKeyPath = filepath.Join(keyDir, "public.pem")
		privateKeyPath = filepath.Join(keyDir, "private.pem")
	} else {
		// 回退到本地配置路径
		keyDir = m.config.Keys.KeyDir
		publicKeyPath = m.config.GetPublicKeyPath()
		privateKeyPath = m.config.GetPrivateKeyPath()
	}

	// 确保密钥目录存在
	if err := os.MkdirAll(keyDir, 0700); err != nil {
		return newOperationResult(false, fmt.Sprintf("创建密钥目录失败: %v", err))
	}

	// 如果是覆盖模式，先删除现有密钥
	if overwrite {
		os.Remove(publicKeyPath)
		os.Remove(privateKeyPath)
	}

	// 生成 RSA-4096 私钥
	privateKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("生成 RSA 私钥失败: %v", err))
	}

	// 保存私钥
	privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
	privateKeyPEM := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: privateKeyBytes,
	}

	privateKeyFile, err := os.OpenFile(privateKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("创建私钥文件失败: %v", err))
	}
	defer privateKeyFile.Close()

	if err := pem.Encode(privateKeyFile, privateKeyPEM); err != nil {
		return newOperationResult(false, fmt.Sprintf("写入私钥失败: %v", err))
	}

	// 生成并保存公钥
	publicKeyBytes, err := x509.MarshalPKIXPublicKey(&privateKey.PublicKey)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("序列化公钥失败: %v", err))
	}

	publicKeyPEM := &pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: publicKeyBytes,
	}

	publicKeyFile, err := os.OpenFile(publicKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return newOperationResult(false, fmt.Sprintf("创建公钥文件失败: %v", err))
	}
	defer publicKeyFile.Close()

	if err := pem.Encode(publicKeyFile, publicKeyPEM); err != nil {
		return newOperationResult(false, fmt.Sprintf("写入公钥失败: %v", err))
	}

	return newOperationResult(true, fmt.Sprintf("RSA-4096 密钥对生成成功！\n公钥: %s\n私钥: %s", publicKeyPath, privateKeyPath))
}

// 生成 KMAC 密钥
func (m Model) generateKMACKey(overwrite bool) operationResult {
	// 生成 32 字节随机密钥
	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		return newOperationResult(false, fmt.Sprintf("生成随机密钥失败: %v", err))
	}

	// 优先使用全局配置
	var cfg *config.Config
	var configLocation string

	globalConfigPath, err := config.GetGlobalConfigPath()
	if err == nil {
		// 尝试加载全局配置
		globalConfig, err := config.Load(globalConfigPath)
		if err == nil {
			cfg = globalConfig
			configLocation = "全局配置"
		}
	}

	// 回退到本地配置
	if cfg == nil {
		cfg = m.config
		configLocation = "本地配置"
	}

	// 保存 KMAC 密钥到独立文件
	if err := cfg.SaveKMACKey(keyBytes); err != nil {
		return newOperationResult(false, fmt.Sprintf("保存 KMAC 密钥文件失败: %v", err))
	}

	keyPath := cfg.GetKMACKeyPath()
	keyPreview := hex.EncodeToString(keyBytes)
	if len(keyPreview) > 16 {
		keyPreview = keyPreview[:16] + "..."
	}

	return newOperationResult(true, fmt.Sprintf("KMAC 密钥生成成功！\n密钥预览: %s\n已保存到 %s: %s\n配置位置: %s", keyPreview, configLocation, keyPath, configLocation))
}

// 检查 RSA 密钥是否存在
func (m Model) checkRSAKeysExist() bool {
	// 优先检查全局配置路径
	globalConfigDir, err := config.GetGlobalConfigDir()
	if err == nil {
		globalPublicKeyPath := filepath.Join(globalConfigDir, "keys", "public.pem")
		globalPrivateKeyPath := filepath.Join(globalConfigDir, "keys", "private.pem")

		_, pubErr := os.Stat(globalPublicKeyPath)
		_, privErr := os.Stat(globalPrivateKeyPath)

		if pubErr == nil || privErr == nil {
			return true
		}
	}

	// 回退到本地配置路径
	publicKeyPath := m.config.GetPublicKeyPath()
	privateKeyPath := m.config.GetPrivateKeyPath()

	_, pubErr := os.Stat(publicKeyPath)
	_, privErr := os.Stat(privateKeyPath)

	return pubErr == nil || privErr == nil
}

// 检查 KMAC 密钥是否存在且有效
func (m Model) checkKMACKeyExists() bool {
	// 优先检查全局配置中的KMAC密钥文件
	globalConfigPath, err := config.GetGlobalConfigPath()
	if err == nil {
		if _, err := os.Stat(globalConfigPath); err == nil {
			globalConfig, err := config.Load(globalConfigPath)
			if err == nil && globalConfig.CheckKMACKeyExists() {
				return true
			}
		}
	}

	// 回退到当前配置中的密钥文件检查
	return m.config.CheckKMACKeyExists()
}
