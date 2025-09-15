package interactivecli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"hycrypt/internal/config"
	"hycrypt/internal/constants"
)

// getKeyGenMenuChoices 从配置中获取密钥生成菜单选择项
func getKeyGenMenuChoices(cfg *config.Config) []string {
	supportedAlgorithms := cfg.GetSupportedAlgorithms()
	choices := make([]string, len(supportedAlgorithms))

	for i, algorithm := range supportedAlgorithms {
		switch strings.ToLower(algorithm) {
		case constants.AlgorithmRSA:
			choices[i] = "🔐 生成 RSA-4096 密钥对"
		case constants.AlgorithmKMAC:
			choices[i] = "🔑 生成 KMAC 密钥"
		default:
			choices[i] = "🔒 生成 " + strings.ToUpper(algorithm) + " 密钥"
		}
	}

	return choices
}

// UI 状态
type uiState int

// 菜单选项常量
var (
	mainMenuChoices         = []string{"🔒 加密文件/文本", "🔓 解密文件/文本", "🔑 生成密钥", "⚙️  管理配置", "❌ 退出"}
	configMenuChoices       = []string{"🔒 隐私输出设置", "🧹 清理隐私目录", "📋 查看当前配置", "🔙 返回主菜单"}
	inputTypeDecryptChoices = []string{"📁 解密文件/文件夹", "📝 解密文本"}
	inputTypeEncryptChoices = []string{"📁 选择文件/文件夹", "📝 输入文本内容"}
)

const (
	stateMainMenu       uiState = iota
	stateConfigInit             // 配置初始化确认
	stateConfigCreating         // 配置创建中
	stateConfigComplete         // 配置创建完成
	stateConfigMenu             // 配置管理菜单
	statePrivacyToggle          // 隐私输出开关设置
	stateCleanupConfirm         // 清理隐私目录确认
	stateAlgorithm              // 1. 选择加密算法
	stateInputType              // 2. 选择加密模式
	stateFileInput              // 3. 选择文件路径
	stateTextInput              // 3. 输入文本内容
	stateOutputFormat           // 3.5. 选择输出格式（文本加密时）
	stateOutput
	stateKeyGeneration
	stateRSAKeyConfirm     // RSA 密钥覆盖确认
	stateKMACKeyConfirm    // KMAC 密钥覆盖确认
	stateProcessing        // 4. 显示进度条
	stateHexOutputComplete // 十六进制输出完成状态
	stateComplete          // 5. 显示结果
)

// Model Bubble Tea 模型
type Model struct {
	state   uiState
	config  *config.Config
	choices []string
	cursor  int

	// 输入组件
	pathInput   textinput.Model
	textArea    textarea.Model
	outputInput textinput.Model

	// 用户选择
	operation    string // "encrypt", "decrypt", "generate-keys", "config"
	algorithm    string // constants.AlgorithmRSA, constants.AlgorithmKMAC
	inputType    string // "file", "text"
	outputFormat string // "file", "hex" (for text encryption)

	// UI 状态
	quitting     bool
	progress     float64
	firstDisplay bool // 标记是否首次显示结果
	result       string
	error        string

	// 加密结果信息
	resultInfo EncryptionResult

	// 流程管理器（避免重复创建）
	flowManager *FlowManagerInterface
}

// EncryptionResult 加密结果信息
type EncryptionResult struct {
	FileName       string
	FileSize       int64
	Algorithm      string
	EncryptionTime string
	OutputPath     string
	DecryptedFile  string // 存储实际解密后的文件名
}

// 样式定义
var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FAFAFA")).
			Background(lipgloss.Color("#7D56F4")).
			Padding(0, 1)

	selectedStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7D56F4"))

	choiceStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FAFAFA"))

	errorStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FF0000"))

	successStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#00FF00"))

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#888888"))
)

// InitialModel 初始化模型
// needsConfigInit 检查是否需要配置初始化
func needsConfigInit() bool {
	globalConfigPath, err := config.GetGlobalConfigPath()
	if err != nil {
		return true // 无法获取路径，需要配置
	}

	// 检查全局配置文件是否存在
	if _, err := os.Stat(globalConfigPath); os.IsNotExist(err) {
		return true // 全局配置不存在
	}

	// 检查密钥目录是否存在
	globalConfigDir, err := config.GetGlobalConfigDir()
	if err != nil {
		return true
	}

	keyDir := filepath.Join(globalConfigDir, "keys")
	if _, err := os.Stat(keyDir); os.IsNotExist(err) {
		return true // 密钥目录不存在
	}

	return false // 配置完整
}

func InitialModel(cfg *config.Config) Model {
	// 初始化路径输入组件
	pathInput := textinput.New()
	pathInput.Placeholder = "Enter file or folder path..."
	pathInput.CharLimit = 500
	pathInput.Width = 60

	// 初始化文本区域组件
	textArea := textarea.New()
	textArea.Placeholder = "Enter text to encrypt..."
	textArea.SetWidth(60)
	textArea.SetHeight(5)

	// 初始化输出目录输入组件
	outputInput := textinput.New()
	outputInput.Placeholder = "Output directory (empty for default)..."
	outputInput.CharLimit = 300
	outputInput.Width = 60

	// 检查是否需要配置初始化
	var initialState uiState
	var initialChoices []string

	if needsConfigInit() {
		initialState = stateConfigInit
		initialChoices = []string{"✅ 是，创建配置", "❌ 否，退出程序"}
		// 在配置初始化状态下，路径输入失去焦点
		pathInput.Blur()
	} else {
		initialState = stateMainMenu
		initialChoices = mainMenuChoices
		pathInput.Focus()
	}

	return Model{
		state:        initialState,
		config:       cfg,
		choices:      initialChoices,
		pathInput:    pathInput,
		textArea:     textArea,
		outputInput:  outputInput,
		outputFormat: "file",        // 默认为文件输出
		flowManager:  FlowManager(), // 初始化流程管理器
	}
}

// Init Bubble Tea 初始化
func (m Model) Init() tea.Cmd {
	return nil
}

// progressMsg 进度消息类型
type progressMsg float64

// operationResult 操作结果类型
type operationResult struct {
	success    bool
	message    string
	resultInfo EncryptionResult
}

// newOperationResult 创建操作结果（不包含详细信息）
func newOperationResult(success bool, message string) operationResult {
	return operationResult{
		success:    success,
		message:    message,
		resultInfo: EncryptionResult{},
	}
}

// newOperationResultWithInfo 创建包含详细信息的操作结果
func newOperationResultWithInfo(success bool, message string, info EncryptionResult) operationResult {
	return operationResult{
		success:    success,
		message:    message,
		resultInfo: info,
	}
}

// configCreateMsg 配置创建完成消息类型
type configCreateMsg struct {
	success bool
	error   string
}

// Update Bubble Tea 更新函数
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	// 使用Model中的FlowManager避免重复创建
	if m.flowManager == nil {
		m.flowManager = FlowManager()
	}
	return m.flowManager.HandleUpdate(m, msg)
}

// View Bubble Tea 视图函数
func (m Model) View() string {
	// 对于配置相关的状态，仍然使用原来的方法
	switch m.state {
	case stateConfigInit:
		return m.viewConfigInit()
	case stateConfigCreating:
		return m.viewConfigCreating()
	case stateConfigComplete:
		return m.viewConfigComplete()
	case stateConfigMenu:
		return m.viewConfigMenu()
	case statePrivacyToggle:
		return m.viewPrivacyToggle()
	case stateCleanupConfirm:
		return m.viewCleanupConfirm()
	case stateRSAKeyConfirm:
		return m.viewRSAKeyConfirm()
	case stateKMACKeyConfirm:
		return m.viewKMACKeyConfirm()
	default:
		// 其他状态使用FlowManager处理
		if m.flowManager == nil {
			m.flowManager = FlowManager()
		}
		return m.flowManager.HandleView(m)
	}
}

// RunInteractiveUI 启动交互式 UI
func RunInteractiveUI(cfg *config.Config) error {
	// 检查是否有可用的 TTY
	if !isTerminal() {
		return fmt.Errorf("交互模式需要终端环境。请在真实的终端中运行程序，或使用命令行模式：\n\n加密文件: ./hycrypt -f <文件路径>\n解密文件: ./hycrypt -d -f <加密文件路径>\n查看帮助: ./hycrypt -help")
	}

	// 尝试创建 Bubbletea 程序，捕获 TTY 相关错误
	p := tea.NewProgram(InitialModel(cfg), tea.WithAltScreen())
	_, err := p.Run()
	if err != nil && (strings.Contains(strings.ToLower(err.Error()), "tty") ||
		strings.Contains(strings.ToLower(err.Error()), "terminal")) {
		return fmt.Errorf("无法启动交互界面：%v\n\n请在真实的终端中运行程序, 或使用命令行模式：\n\n加密文件: ./hycrypt -f <文件路径>\n解密文件: ./hycrypt -d -f <加密文件路径>\n查看帮助: ./hycrypt -help", err)
	}
	return err
}

// isTerminal 检查是否在终端环境中运行
func isTerminal() bool {
	// 检查 stdin 是否是终端
	stat, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (stat.Mode() & os.ModeCharDevice) != 0
}
