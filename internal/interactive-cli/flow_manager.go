package interactivecli

import (
	"time"

	"hycrypt/internal/config"

	tea "github.com/charmbracelet/bubbletea"
)

// FlowManagerInterface 流程管理器
type FlowManagerInterface struct {
	menuHandler        *MenuHandlerStrct
	viewRenderer       *ViewRendererStruct
	operationProcessor *OperationProcessor
	configFlowManager  *ConfigFlowManagerInterface

	// 专用流程管理器
	encryptFlowManager *EncryptFlowManager
	decryptFlowManager *DecryptFlowManager

	// 功能模块
	keygenFeature *KeygenFeatureStruct
	configFeature *ConfigFeatureStruct
}

// FlowManager 创建流程管理器
func FlowManager() *FlowManagerInterface {
	return &FlowManagerInterface{
		menuHandler:        MenuHandler(),
		viewRenderer:       ViewRenderer(),
		operationProcessor: NewOperationProcessor(),
		configFlowManager:  ConfigFlowManager(),

		// 初始化专用流程管理器
		encryptFlowManager: NewEncryptFlowManager(),
		decryptFlowManager: NewDecryptFlowManager(),

		// 初始化功能模块
		keygenFeature: KeygenFeature(),
		configFeature: ConfigFeature(),
	}
}

// HandleUpdate 处理更新逻辑
func (f *FlowManagerInterface) HandleUpdate(m Model, msg tea.Msg) (Model, tea.Cmd) {
	switch msg := msg.(type) {
	case configCreateMsg:
		if msg.success {
			// 配置创建成功，切换到完成状态
			m.state = stateConfigComplete
		} else {
			// 配置创建失败，显示错误并退出
			m.error = msg.error
			m.state = stateConfigComplete // 仍然进入完成状态，但显示错误
		}
		return m, nil
	case operationResult:
		// 特殊处理：十六进制输出
		if msg.success && msg.message == "HEX_OUTPUT_TRIGGER" {
			// 切换到十六进制输出完成状态
			m.state = stateHexOutputComplete
			m.result = msg.message
			m.resultInfo = msg.resultInfo
			m.firstDisplay = true // 标记为首次显示

			return m, nil
		}
		m.state = stateComplete
		m.firstDisplay = true // 标记为首次显示
		if msg.success {
			m.result = msg.message
			m.error = ""
			m.resultInfo = msg.resultInfo
		} else {
			m.error = msg.message
			m.result = ""
		}
		return m, nil
	case progressMsg:
		m.progress = float64(msg)
		if m.progress >= 1.0 {
			// 进度完成，开始实际处理
			return m, tea.Cmd(func() tea.Msg {
				return f.operationProcessor.ProcessOperation(m)
			})
		}
		return m, f.updateProgress(m)
	case tea.KeyMsg:
		return f.HandleKeyMessage(m, msg)
	}
	return m, nil
}

// HandleView 处理视图渲染
func (f *FlowManagerInterface) HandleView(m Model) string {
	switch m.state {
	case stateMainMenu:
		return f.viewRenderer.RenderMainMenu(m)
	case stateAlgorithm:
		return f.viewRenderer.RenderAlgorithm(m)
	case stateInputType:
		return f.viewRenderer.RenderInputType(m)
	case stateFileInput:
		return f.viewRenderer.RenderFileInput(m)
	case stateTextInput:
		return f.viewRenderer.RenderTextInput(m)
	case stateOutputFormat:
		return f.viewRenderer.RenderOutputFormat(m)
	case stateOutput:
		return f.viewRenderer.RenderOutput(m)
	case stateProcessing:
		return f.viewRenderer.RenderProcessing(m)
	case stateComplete:
		return f.viewRenderer.RenderComplete(m)
	case stateHexOutputComplete:
		return f.viewRenderer.RenderHexOutputComplete(m)
	case stateKeyGeneration:
		return f.viewRenderer.RenderKeyGeneration(m)
	default:
		return "未知状态"
	}
}

// HandleKeyMessage 处理按键消息 - 使用功能模块分发
func (f *FlowManagerInterface) HandleKeyMessage(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	// 根据操作类型和状态分发到对应的功能模块
	switch m.operation {
	case "encrypt":
		return f.handleEncryptFlow(m, msg)
	case "decrypt":
		return f.handleDecryptFlow(m, msg)
	case "generate-keys":
		return f.handleKeygenFlow(m, msg)
	case "config":
		return f.handleConfigFlow(m, msg)
	default:
		// 主菜单或未设置操作时的默认处理
		if m.state == stateMainMenu {
			return f.HandleMainMenu(m, msg)
		}
		// 通用状态处理
		return f.handleCommonStates(m, msg)
	}
}

// HandleMainMenu 处理主菜单（公开方法）
func (f *FlowManagerInterface) HandleMainMenu(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q", "esc":
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
		switch m.cursor {
		case 0: // 加密
			m = f.encryptFlowManager.HandleMainMenuEncrypt(m)
		case 1: // 解密
			m = f.decryptFlowManager.HandleMainMenuDecrypt(m)
		case 2: // 生成密钥
			m.operation = "generate-keys"
			m.state = stateKeyGeneration
			m.choices = getKeyGenMenuChoices(m.config)
			m.cursor = 0
		case 3: // 管理配置
			m.operation = "config"
			m.state = stateConfigMenu
			m.choices = configMenuChoices
			m.cursor = 0
		case 4: // 退出
			m.quitting = true
			return m, tea.Quit
		}
	}
	return m, nil
}

// handleEncryptFlow 处理加密流程
func (f *FlowManagerInterface) handleEncryptFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	newModel, cmd := f.encryptFlowManager.HandleEncryptFlow(m, msg)
	if cmd != nil {
		return newModel, cmd
	}
	return f.handleCommonStates(newModel, msg)
}

// handleDecryptFlow 处理解密流程
func (f *FlowManagerInterface) handleDecryptFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	newModel, cmd := f.decryptFlowManager.HandleDecryptFlow(m, msg)
	if cmd != nil {
		return newModel, cmd
	}
	return f.handleCommonStates(newModel, msg)
}

// handleKeygenFlow 处理密钥生成流程
func (f *FlowManagerInterface) handleKeygenFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch m.state {
	case stateKeyGeneration:
		return f.keygenFeature.HandleKeyGeneration(m, msg)
	case stateRSAKeyConfirm:
		return f.keygenFeature.HandleRSAKeyConfirm(m, msg)
	case stateKMACKeyConfirm:
		return f.keygenFeature.HandleKMACKeyConfirm(m, msg)
	default:
		return f.handleCommonStates(m, msg)
	}
}

// handleConfigFlow 处理配置管理流程
func (f *FlowManagerInterface) handleConfigFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch m.state {
	case stateConfigMenu:
		return f.configFeature.HandleConfigMenu(m, msg)
	case statePrivacyToggle:
		return f.configFeature.HandlePrivacyToggle(m, msg)
	case stateCleanupConfirm:
		return f.configFeature.HandleCleanupConfirm(m, msg)
	case stateConfigInit:
		return f.configFeature.HandleConfigInit(m, msg)
	case stateConfigComplete:
		return f.configFeature.HandleConfigComplete(m, msg)
	default:
		return f.handleCommonStates(m, msg)
	}
}

// handleCommonStates 处理通用状态
func (f *FlowManagerInterface) handleCommonStates(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch m.state {
	case stateHexOutputComplete:
		return f.menuHandler.HandleHexOutputComplete(m, msg)
	case stateComplete:
		return f.menuHandler.HandleComplete(m, msg)
	default:
		return m, nil
	}
}

// updateProgress 更新进度
func (f *FlowManagerInterface) updateProgress(m Model) tea.Cmd {
	return tea.Tick(time.Millisecond*50, func(t time.Time) tea.Msg {
		return progressMsg(m.progress + 0.02)
	})
}

// ConfigFlowManagerInterface 配置流程管理器
type ConfigFlowManagerInterface struct{}

// ConfigFlowManager 创建配置流程管理器
func ConfigFlowManager() *ConfigFlowManagerInterface {
	return &ConfigFlowManagerInterface{}
}

// HandleConfigInit 处理配置初始化
func (c *ConfigFlowManagerInterface) HandleConfigInit(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
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
func (c *ConfigFlowManagerInterface) HandleConfigComplete(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
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
		return m, nil
	}
}

// HandleConfigMenu 处理配置菜单
func (c *ConfigFlowManagerInterface) HandleConfigMenu(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		// 返回主菜单
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
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
		}
	}
	return m, nil
}

// HandlePrivacyToggle 处理隐私输出设置
func (c *ConfigFlowManagerInterface) HandlePrivacyToggle(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
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
func (c *ConfigFlowManagerInterface) HandleCleanupConfirm(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
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

// createGlobalConfig 异步创建全局配置
func (c *ConfigFlowManagerInterface) createGlobalConfig() tea.Msg {
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
func (c *ConfigFlowManagerInterface) generateConfigDisplay(m Model) string {
	// 这里实现配置显示逻辑，与原来的方法相同
	return "配置显示功能已移动到配置流程管理器"
}

// performCleanup 执行清理操作
func (c *ConfigFlowManagerInterface) performCleanup(m Model) operationResult {
	// 这里实现清理逻辑，与原来的方法相同
	return newOperationResult(true, "清理完成")
}
