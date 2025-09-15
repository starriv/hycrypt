package interactivecli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"hycrypt/internal/config"

	tea "github.com/charmbracelet/bubbletea"
)

// ConfigFeatureStruct 配置管理功能处理器
type ConfigFeatureStruct struct{}

// ConfigFeature 创建配置管理功能处理器
func ConfigFeature() *ConfigFeatureStruct {
	return &ConfigFeatureStruct{}
}

// HandleConfigMenu 处理配置菜单
func (c *ConfigFeatureStruct) HandleConfigMenu(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		// 返回主菜单
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
		m.operation = "" // 重置操作类型
		return m, nil
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(m.choices)-1 {
			m.cursor++
		}
	case "enter", " ":
		switch m.cursor {
		case 0: // 隐私输出设置
			m.state = statePrivacyToggle
			m.choices = []string{}
			m.cursor = 0
		case 1: // 清理隐私目录
			m.state = stateCleanupConfirm
			m.choices = []string{}
			m.cursor = 0
		case 2: // 查看当前配置
			m.state = stateComplete
			m.result = c.generateConfigDisplay(m)
			m.firstDisplay = true
		case 3: // 返回主菜单
			m.state = stateMainMenu
			m.choices = mainMenuChoices
			m.cursor = 0
			m.operation = "" // 重置操作类型
		}
	}
	return m, nil
}

// HandlePrivacyToggle 处理隐私输出设置
func (c *ConfigFeatureStruct) HandlePrivacyToggle(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		// 返回配置菜单
		m.state = stateConfigMenu
		m.choices = configMenuChoices
		m.cursor = 0
		return m, nil
	case "y", "Y", "1":
		// 启用隐私输出
		err := m.config.UpdatePrivacyOutputSetting(true)
		if err != nil {
			m.state = stateComplete
			m.error = "保存配置失败: " + err.Error()
			m.result = ""
		} else {
			m.state = stateComplete
			m.result = "✅ 隐私输出已启用\n文件将输出到全局配置目录：\n" +
				"• 加密文件: " + m.config.GetEncryptedDirPath() + "\n" +
				"• 解密文件: " + m.config.GetDecryptedDirPath()
			m.error = ""
		}
		m.firstDisplay = true
		return m, nil
	case "n", "N", "2":
		// 禁用隐私输出
		err := m.config.UpdatePrivacyOutputSetting(false)
		if err != nil {
			m.state = stateComplete
			m.error = "保存配置失败: " + err.Error()
			m.result = ""
		} else {
			m.state = stateComplete
			m.result = "✅ 隐私输出已禁用\n文件将输出到与输入文件相同的目录"
			m.error = ""
		}
		m.firstDisplay = true
		return m, nil
	}
	return m, nil
}

// HandleCleanupConfirm 处理清理确认
func (c *ConfigFeatureStruct) HandleCleanupConfirm(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		// 返回配置菜单
		m.state = stateConfigMenu
		m.choices = configMenuChoices
		m.cursor = 0
		return m, nil
	case "y", "Y":
		// 用户确认清理，执行清理操作
		m.state = stateProcessing
		return m, tea.Cmd(func() tea.Msg {
			return c.performCleanup(m)
		})
	case "n", "N":
		// 用户取消，返回配置菜单
		m.state = stateConfigMenu
		m.choices = configMenuChoices
		m.cursor = 0
		return m, nil
	}
	return m, nil
}

// HandleConfigInit 处理配置初始化
func (c *ConfigFeatureStruct) HandleConfigInit(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(m.choices)-1 {
			m.cursor++
		}
	case "enter", " ":
		if m.cursor == 0 {
			// 用户选择创建配置，切换到创建状态
			m.state = stateConfigCreating
			return m, tea.Cmd(func() tea.Msg {
				// 异步执行配置创建
				return c.createGlobalConfig()
			})
		} else {
			// 用户选择退出
			m.quitting = true
			return m, tea.Quit
		}
	}
	return m, nil
}

// HandleConfigComplete 处理配置完成
func (c *ConfigFeatureStruct) HandleConfigComplete(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	default:
		if m.error != "" {
			// 配置创建失败，退出程序
			m.quitting = true
			return m, tea.Quit
		}
		// 配置创建成功，进入主菜单
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
		m.operation = "" // 重置操作类型
		return m, nil
	}
}

// createGlobalConfig 异步创建全局配置
func (c *ConfigFeatureStruct) createGlobalConfig() tea.Msg {
	if err := config.InitializeGlobalConfig(); err != nil {
		return configCreateMsg{
			success: false,
			error:   err.Error(),
		}
	}

	return configCreateMsg{
		success: true,
		error:   "",
	}
}

// generateConfigDisplay 生成配置显示内容
func (c *ConfigFeatureStruct) generateConfigDisplay(m Model) string {
	var s strings.Builder

	s.WriteString("📋 当前配置信息\n")
	s.WriteString("==================\n\n")

	// 配置文件位置
	globalConfigPath, _ := config.GetGlobalConfigPath()
	s.WriteString(fmt.Sprintf("配置文件位置: %s\n\n", globalConfigPath))

	// 密钥配置
	s.WriteString("🔑 密钥配置:\n")
	s.WriteString(fmt.Sprintf("  密钥目录: %s\n", m.config.GetKeyDirPath()))
	s.WriteString(fmt.Sprintf("  RSA公钥: %s\n", m.config.Keys.PublicKey))
	s.WriteString(fmt.Sprintf("  RSA私钥: %s\n", m.config.Keys.PrivateKey))
	s.WriteString(fmt.Sprintf("  KMAC密钥文件: %s\n\n", m.config.Keys.KMACKey))

	// 目录配置
	s.WriteString("📁 目录配置:\n")
	s.WriteString(fmt.Sprintf("  加密文件目录: %s\n", m.config.GetEncryptedDirPath()))
	s.WriteString(fmt.Sprintf("  解密文件目录: %s\n\n", m.config.GetDecryptedDirPath()))

	// 加密配置
	s.WriteString("🔐 加密配置:\n")
	s.WriteString(fmt.Sprintf("  默认加密方法: %s\n", strings.ToUpper(m.config.Encryption.Method)))
	s.WriteString(fmt.Sprintf("  RSA密钥长度: %d 位\n", m.config.Encryption.RSAKeySize))
	s.WriteString(fmt.Sprintf("  AES密钥长度: %d 字节\n", m.config.Encryption.AESKeySize))
	s.WriteString(fmt.Sprintf("  文件扩展名: %s\n\n", m.config.Encryption.FileExtension))

	// 输出配置
	s.WriteString("📤 输出配置:\n")
	s.WriteString(fmt.Sprintf("  详细输出: %t\n", m.config.Output.Verbose))
	s.WriteString(fmt.Sprintf("  显示进度: %t\n", m.config.Output.ShowProgress))
	s.WriteString(fmt.Sprintf("  使用表情: %t\n", m.config.Output.UseEmoji))

	privacyStatus := "禁用"
	if m.config.Output.PrivateOutput {
		privacyStatus = "启用"
	}
	s.WriteString(fmt.Sprintf("  隐私输出: %s\n", privacyStatus))

	return s.String()
}

// performCleanup 执行清理操作
func (c *ConfigFeatureStruct) performCleanup(m Model) operationResult {
	encryptedDir := m.config.GetEncryptedDirPath()
	decryptedDir := m.config.GetDecryptedDirPath()

	var errors []string
	var cleanedCount int

	// 清理加密目录
	if count, err := c.cleanDirectory(encryptedDir); err != nil {
		errors = append(errors, fmt.Sprintf("清理加密目录失败: %v", err))
	} else {
		cleanedCount += count
	}

	// 清理解密目录
	if count, err := c.cleanDirectory(decryptedDir); err != nil {
		errors = append(errors, fmt.Sprintf("清理解密目录失败: %v", err))
	} else {
		cleanedCount += count
	}

	// 生成结果消息
	var message string
	if len(errors) > 0 {
		message = fmt.Sprintf("清理完成，共删除 %d 个文件\n\n", cleanedCount)
		if len(errors) > 0 {
			message += "遇到以下错误:\n"
			for _, err := range errors {
				message += "• " + err + "\n"
			}
		}
		return newOperationResult(false, message)
	}

	message = fmt.Sprintf("清理完成！\n\n共删除 %d 个文件\n• 加密目录: %s\n• 解密目录: %s",
		cleanedCount, encryptedDir, decryptedDir)
	return newOperationResult(true, message)
}

// cleanDirectory 清理指定目录中的所有文件并删除目录本身
func (c *ConfigFeatureStruct) cleanDirectory(dirPath string) (int, error) {
	// 如果目录不存在，不算错误
	if _, err := os.Stat(dirPath); os.IsNotExist(err) {
		return 0, nil
	}

	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return 0, err
	}

	count := 0
	// 递归删除目录中的所有内容（包括子目录）
	for _, entry := range entries {
		itemPath := filepath.Join(dirPath, entry.Name())
		if entry.IsDir() {
			// 递归删除子目录
			if subCount, err := c.cleanDirectory(itemPath); err != nil {
				return count, fmt.Errorf("删除子目录 %s 失败: %w", itemPath, err)
			} else {
				count += subCount
			}
		} else {
			// 删除文件
			if err := os.Remove(itemPath); err != nil {
				return count, fmt.Errorf("删除文件 %s 失败: %w", itemPath, err)
			}
			count++
		}
	}

	// 删除空的目录本身
	if err := os.Remove(dirPath); err != nil {
		return count, fmt.Errorf("删除目录 %s 失败: %w", dirPath, err)
	}

	return count, nil
}
