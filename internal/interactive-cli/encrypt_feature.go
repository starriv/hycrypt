package interactivecli

import (
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"hycrypt/internal/constants"
)

// getEncryptAlgorithmChoices 从配置中获取加密算法选择项
func getEncryptAlgorithmChoices(m Model) []string {
	supportedAlgorithms := m.config.GetSupportedAlgorithms()
	choices := make([]string, len(supportedAlgorithms))

	for i, algorithm := range supportedAlgorithms {
		switch strings.ToLower(algorithm) {
		case constants.AlgorithmRSA:
			choices[i] = "🔐 RSA-4096 加密"
		case constants.AlgorithmKMAC:
			choices[i] = "🔑 KMAC 加密"
		default:
			choices[i] = "🔒 " + strings.ToUpper(algorithm) + " 加密"
		}
	}

	return choices
}

// EncryptFeatureInterface 加密功能处理器
type EncryptFeatureInterface struct {
	keyHandler *CommonKeyHandlerStruct
}

// EncryptFeature 创建加密功能处理器
func EncryptFeature() *EncryptFeatureInterface {
	return &EncryptFeatureInterface{
		keyHandler: CommonKeyHandler(),
	}
}

// HandleAlgorithm 处理加密流程的算法选择
func (e *EncryptFeatureInterface) HandleAlgorithm(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	onConfirm := func(m Model) (Model, tea.Cmd) {
		supportedAlgorithms := m.config.GetSupportedAlgorithms()
		if m.cursor < len(supportedAlgorithms) {
			m.algorithm = supportedAlgorithms[m.cursor]
		}
		// 加密操作进入输入类型选择
		m.state = stateInputType
		m.choices = inputTypeEncryptChoices
		m.cursor = 0
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToMainMenu(&m)
		return m
	}

	newM, cmd, handled := e.keyHandler.HandleMenuKeys(m, msg, onConfirm, onEscape)
	if handled {
		return newM, cmd
	}

	return m, nil
}

// HandleInputType 处理加密流程的输入类型选择
func (e *EncryptFeatureInterface) HandleInputType(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	onConfirm := func(m Model) (Model, tea.Cmd) {
		if m.cursor == 0 {
			// 文件加密
			m.inputType = "file"
			m.state = stateFileInput
			// 激活路径输入组件
			m.pathInput.Focus()
			m.textArea.Blur()
			m.outputInput.Blur()
		} else if m.cursor == 1 {
			// 文本加密 - 需要选择输出格式
			m.inputType = "text"
			m.state = stateOutputFormat
			m.choices = []string{"📁 保存为文件", "🔤 输出十六进制"}
		}
		if m.state != stateOutputFormat {
			m.choices = []string{}
		}
		m.cursor = 0
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateAlgorithm, getEncryptAlgorithmChoices(m))
		return m
	}

	newM, cmd, handled := e.keyHandler.HandleMenuKeys(m, msg, onConfirm, onEscape)
	if handled {
		return newM, cmd
	}

	return m, nil
}

// HandleFileInput 处理加密流程的文件输入
func (e *EncryptFeatureInterface) HandleFileInput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		inputPath := strings.TrimSpace(m.pathInput.Value())
		if inputPath != "" {
			m.pathInput.SetValue(inputPath)
			// 加密操作直接进入输出目录选择
			m.state = stateOutput
			m.outputInput.Focus()
		}
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateInputType, inputTypeEncryptChoices)
		m.pathInput.Reset()
		return m
	}

	onPaste := func(m Model, msg tea.KeyMsg) Model {
		HandleTextInputPaste(&m.pathInput, msg)
		return m
	}

	newM, newCmd, handled := e.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, onPaste)
	if handled {
		return newM, newCmd
	}

	// 更新路径输入组件
	m.pathInput, cmd = m.pathInput.Update(msg)
	return m, cmd
}

// HandleTextInput 处理加密流程的文本输入
func (e *EncryptFeatureInterface) HandleTextInput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		textContent := strings.TrimSpace(m.textArea.Value())
		if textContent != "" {
			if m.outputFormat == "hex" {
				// 十六进制输出，直接处理
				m.state = stateProcessing
				m.progress = 0.0
				return m, e.startProcessing(m)
			} else {
				// 文件输出，进入输出目录选择
				m.state = stateOutput
				m.outputInput.Focus()
			}
		}
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateOutputFormat, []string{"📁 保存为文件", "🔤 输出十六进制"})
		m.textArea.Reset()
		return m
	}

	newM, newCmd, handled := e.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, nil)
	if handled {
		return newM, newCmd
	}

	m.textArea, cmd = m.textArea.Update(msg)
	return m, cmd
}

// HandleOutputFormat 处理加密流程的输出格式选择
func (e *EncryptFeatureInterface) HandleOutputFormat(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	onConfirm := func(m Model) (Model, tea.Cmd) {
		if m.cursor == 0 {
			m.outputFormat = "file"
		} else {
			m.outputFormat = "hex"
		}
		m.state = stateTextInput
		// 激活文本区域组件
		m.textArea.Focus()
		m.pathInput.Blur()
		m.outputInput.Blur()
		m.choices = []string{}
		m.cursor = 0
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateInputType, inputTypeEncryptChoices)
		return m
	}

	newM, cmd, handled := e.keyHandler.HandleMenuKeys(m, msg, onConfirm, onEscape)
	if handled {
		return newM, cmd
	}

	return m, nil
}

// HandleOutput 处理加密流程的输出目录选择
func (e *EncryptFeatureInterface) HandleOutput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		outputPath := strings.TrimSpace(m.outputInput.Value())
		m.outputInput.SetValue(outputPath)
		m.state = stateProcessing
		m.progress = 0.0
		return m, e.startProcessing(m)
	}

	onEscape := func(m Model) Model {
		if m.inputType == "file" {
			m.state = stateFileInput
			m.pathInput.Focus()
		} else {
			m.state = stateTextInput
			m.textArea.Focus()
		}
		m.outputInput.Blur()
		return m
	}

	onPaste := func(m Model, msg tea.KeyMsg) Model {
		HandleTextInputPaste(&m.outputInput, msg)
		return m
	}

	newM, newCmd, handled := e.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, onPaste)
	if handled {
		return newM, newCmd
	}

	m.outputInput, cmd = m.outputInput.Update(msg)
	return m, cmd
}

// startProcessing 开始加密处理流程
func (e *EncryptFeatureInterface) startProcessing(m Model) tea.Cmd {
	return tea.Tick(time.Millisecond*50, func(t time.Time) tea.Msg {
		return progressMsg(m.progress + 0.02)
	})
}
