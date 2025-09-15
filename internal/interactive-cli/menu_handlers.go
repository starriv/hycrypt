package interactivecli

import (
	tea "github.com/charmbracelet/bubbletea"
)

// MenuHandlerStrct 菜单处理器
type MenuHandlerStrct struct{}

// MenuHandler 创建菜单处理器
func MenuHandler() *MenuHandlerStrct {
	return &MenuHandlerStrct{}
}

// HandleComplete 处理完成状态菜单
func (h *MenuHandlerStrct) HandleComplete(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	// 如果是首次显示，重置标志但不处理按键
	if m.firstDisplay {
		m.firstDisplay = false
		return m, nil
	}

	switch msg.String() {
	case "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	default:
		// 用户真正按键后才返回主菜单
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
		m.operation = "" // 重置操作类型

		// 重置所有输入组件
		m.pathInput.Reset()
		m.textArea.Reset()
		m.outputInput.Reset()
		m.pathInput.Blur()
		m.textArea.Blur()
		m.outputInput.Blur()

		// 清空结果信息
		m.result = ""
		m.error = ""
		m.resultInfo = EncryptionResult{}

		return m, nil
	}
}

// HandleHexOutputComplete 处理十六进制输出完成状态菜单
func (h *MenuHandlerStrct) HandleHexOutputComplete(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	// 如果是首次显示，重置标志但不处理按键
	if m.firstDisplay {
		m.firstDisplay = false
		return m, nil
	}

	switch msg.String() {
	case "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	default:
		// 用户真正按键后才返回主菜单
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
		m.operation = "" // 重置操作类型

		// 重置所有输入组件
		m.pathInput.Reset()
		m.textArea.Reset()
		m.outputInput.Reset()
		m.pathInput.Blur()
		m.textArea.Blur()
		m.outputInput.Blur()

		// 清空结果信息
		m.result = ""
		m.error = ""
		m.resultInfo = EncryptionResult{}

		return m, nil
	}
}
