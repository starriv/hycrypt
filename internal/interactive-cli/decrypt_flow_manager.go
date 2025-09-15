package interactivecli

import (
	tea "github.com/charmbracelet/bubbletea"
)

// DecryptFlowManager 解密流程管理器
type DecryptFlowManager struct {
	decryptFeature *DecryptFeatureStruct
}

// NewDecryptFlowManager 创建解密流程管理器
func NewDecryptFlowManager() *DecryptFlowManager {
	return &DecryptFlowManager{
		decryptFeature: DecryptFeature(),
	}
}

// HandleDecryptFlow 处理解密流程
func (f *DecryptFlowManager) HandleDecryptFlow(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch m.state {
	case stateInputType:
		return f.decryptFeature.HandleInputType(m, msg)
	case stateFileInput:
		return f.decryptFeature.HandleFileInput(m, msg)
	case stateTextInput:
		return f.decryptFeature.HandleTextInput(m, msg)
	case stateAlgorithm:
		return f.decryptFeature.HandleAlgorithmForDecrypt(m, msg)
	case stateOutput:
		return f.decryptFeature.HandleOutput(m, msg)
	default:
		return m, nil
	}
}

// HandleMainMenuDecrypt 处理主菜单中的解密选择
func (f *DecryptFlowManager) HandleMainMenuDecrypt(m Model) Model {
	m.operation = "decrypt"
	m.state = stateInputType
	m.choices = inputTypeDecryptChoices
	m.cursor = 0
	// 重置所有输入组件
	m.pathInput.Reset()
	m.textArea.Reset()
	m.outputInput.Reset()
	return m
}
