package interactivecli

import (
	tea "github.com/charmbracelet/bubbletea"
)

// EncryptFlowManager 加密流程管理器
type EncryptFlowManager struct {
	encryptFeature *EncryptFeatureInterface
}

// NewEncryptFlowManager 创建加密流程管理器
func NewEncryptFlowManager() *EncryptFlowManager {
	return &EncryptFlowManager{
		encryptFeature: EncryptFeature(),
	}
}

// HandleEncryptFlow 处理加密流程
func (f *EncryptFlowManager) HandleEncryptFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch m.state {
	case stateAlgorithm:
		return f.encryptFeature.HandleAlgorithm(m, msg)
	case stateInputType:
		return f.encryptFeature.HandleInputType(m, msg)
	case stateFileInput:
		return f.encryptFeature.HandleFileInput(m, msg)
	case stateTextInput:
		return f.encryptFeature.HandleTextInput(m, msg)
	case stateOutputFormat:
		return f.encryptFeature.HandleOutputFormat(m, msg)
	case stateOutput:
		return f.encryptFeature.HandleOutput(m, msg)
	default:
		return m, nil
	}
}

// HandleMainMenuEncrypt 处理主菜单中的加密选择
func (f *EncryptFlowManager) HandleMainMenuEncrypt(m Model) Model {
	m.operation = "encrypt"
	m.state = stateAlgorithm
	m.choices = getEncryptAlgorithmChoices(m)
	m.cursor = 0
	// 重置所有输入组件
	m.pathInput.Reset()
	m.textArea.Reset()
	m.outputInput.Reset()
	return m
}
