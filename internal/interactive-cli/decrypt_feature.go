package interactivecli

import (
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"hycrypt/internal/constants"
)

// getDecryptAlgorithmChoices 从配置中获取解密算法选择项
func getDecryptAlgorithmChoices(m Model) []string {
	supportedAlgorithms := m.config.GetSupportedAlgorithms()
	choices := make([]string, len(supportedAlgorithms))

	for i, algorithm := range supportedAlgorithms {
		switch strings.ToLower(algorithm) {
		case constants.AlgorithmRSA:
			choices[i] = "🔐 RSA-4096 解密"
		case constants.AlgorithmKMAC:
			choices[i] = "🔑 KMAC 解密"
		default:
			choices[i] = "🔒 " + strings.ToUpper(algorithm) + " 解密"
		}
	}

	return choices
}

// DecryptFeatureStruct 解密功能处理器
type DecryptFeatureStruct struct {
	keyHandler *CommonKeyHandlerStruct
}

// DecryptFeature 创建解密功能处理器
func DecryptFeature() *DecryptFeatureStruct {
	return &DecryptFeatureStruct{
		keyHandler: CommonKeyHandler(),
	}
}

// HandleInputType 处理解密流程的输入类型选择
func (d *DecryptFeatureStruct) HandleInputType(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	onConfirm := func(m Model) (Model, tea.Cmd) {
		if m.cursor == 0 {
			// 文件解密
			m.inputType = "file"
			m.state = stateFileInput
			m.pathInput.Focus()
			m.textArea.Blur()
			m.outputInput.Blur()
		} else if m.cursor == 1 {
			// 文本解密 - 需要先选择算法
			m.inputType = "text"
			m.state = stateAlgorithm
			m.choices = getDecryptAlgorithmChoices(m)
		}
		if m.state != stateAlgorithm {
			m.choices = []string{}
		}
		m.cursor = 0
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToMainMenu(&m)
		return m
	}

	newM, cmd, handled := d.keyHandler.HandleMenuKeys(m, msg, onConfirm, onEscape)
	if handled {
		return newM, cmd
	}

	return m, nil
}

// HandleFileInput 处理解密流程的文件输入
func (d *DecryptFeatureStruct) HandleFileInput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		inputPath := strings.TrimSpace(m.pathInput.Value())
		if inputPath != "" {
			m.pathInput.SetValue(inputPath)

			// 尝试自动检测算法
			detectedAlgorithm := m.config.DetectAlgorithmFromPath(inputPath)
			if detectedAlgorithm != "" && m.config.IsAlgorithmSupported(detectedAlgorithm) {
				// 自动检测到算法，直接设置并跳过算法选择
				m.algorithm = detectedAlgorithm
				m.state = stateOutput
				m.outputInput.Focus()
			} else {
				// 无法检测到算法，需要用户选择
				m.state = stateAlgorithm
				m.choices = getDecryptAlgorithmChoices(m)
				m.cursor = 0
			}
		}
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateInputType, inputTypeDecryptChoices)
		m.pathInput.Reset()
		return m
	}

	onPaste := func(m Model, msg tea.KeyMsg) Model {
		HandleTextInputPaste(&m.pathInput, msg)
		return m
	}

	newM, newCmd, handled := d.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, onPaste)
	if handled {
		return newM, newCmd
	}

	m.pathInput, cmd = m.pathInput.Update(msg)
	return m, cmd
}

// HandleTextInput 处理解密流程的文本输入
func (d *DecryptFeatureStruct) HandleTextInput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		textContent := strings.TrimSpace(m.textArea.Value())
		if textContent != "" {
			// 文本解密直接处理
			m.state = stateProcessing
			m.progress = 0.0
			return m, d.startProcessing(m)
		}
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateAlgorithm, getDecryptAlgorithmChoices(m))
		m.textArea.Reset()
		return m
	}

	newM, newCmd, handled := d.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, nil)
	if handled {
		return newM, newCmd
	}

	m.textArea, cmd = m.textArea.Update(msg)
	return m, cmd
}

// HandleAlgorithmForDecrypt 处理解密流程的算法选择
func (d *DecryptFeatureStruct) HandleAlgorithmForDecrypt(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	onConfirm := func(m Model) (Model, tea.Cmd) {
		supportedAlgorithms := m.config.GetSupportedAlgorithms()
		if m.cursor < len(supportedAlgorithms) {
			m.algorithm = supportedAlgorithms[m.cursor]
		}

		// 解密时算法选择后进入文本输入
		if m.inputType == "text" {
			m.state = stateTextInput
			m.textArea.Focus()
			m.pathInput.Blur()
			m.outputInput.Blur()
		} else {
			// 文件解密进入输出选择
			m.state = stateOutput
			m.outputInput.Focus()
		}
		m.cursor = 0
		return m, nil
	}

	onEscape := func(m Model) Model {
		HandleEscapeToState(&m, stateInputType, inputTypeDecryptChoices)
		return m
	}

	newM, cmd, handled := d.keyHandler.HandleMenuKeys(m, msg, onConfirm, onEscape)
	if handled {
		return newM, cmd
	}

	return m, nil
}

// HandleOutput 处理解密流程的输出目录选择
func (d *DecryptFeatureStruct) HandleOutput(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	var cmd tea.Cmd

	onSubmit := func(m Model) (Model, tea.Cmd) {
		outputPath := strings.TrimSpace(m.outputInput.Value())
		m.outputInput.SetValue(outputPath)
		m.state = stateProcessing
		m.progress = 0.0
		return m, d.startProcessing(m)
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

	newM, newCmd, handled := d.keyHandler.HandleInputKeys(m, msg, onSubmit, onEscape, onPaste)
	if handled {
		return newM, newCmd
	}

	m.outputInput, cmd = m.outputInput.Update(msg)
	return m, cmd
}

// startProcessing 开始解密处理流程
func (d *DecryptFeatureStruct) startProcessing(m Model) tea.Cmd {
	return tea.Tick(time.Millisecond*50, func(t time.Time) tea.Msg {
		return progressMsg(m.progress + 0.02)
	})
}
