package interactivecli

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// 键盘事件常量
const (
	// 控制键
	KeyQuit         = "ctrl+c"
	KeyQuitAlt      = "q"
	KeyEscape       = "esc"
	KeyConfirm      = "enter"
	KeyConfirmSpace = " "
	KeySubmit       = "ctrl+d"
	KeyPaste        = "ctrl+v"

	// 导航键
	KeyUp      = "up"
	KeyUpVim   = "k"
	KeyDown    = "down"
	KeyDownVim = "j"

	// 确认键
	KeyYes      = "y"
	KeyYesUpper = "Y"
	KeyYes1     = "1"
	KeyNo       = "n"
	KeyNoUpper  = "N"
	KeyNo2      = "2"
)

// KeyAction 键盘动作类型
type KeyAction int

const (
	ActionNone KeyAction = iota
	ActionQuit
	ActionEscape
	ActionConfirm
	ActionNavigateUp
	ActionNavigateDown
	ActionSubmit
	ActionPaste
	ActionYes
	ActionNo
	ActionUnknown
)

// KeyActionResult 键盘动作处理结果
type KeyActionResult struct {
	Action  KeyAction
	Handled bool
}

// ParseKeyAction 解析键盘消息到动作
func ParseKeyAction(msg tea.KeyMsg) KeyActionResult {
	key := msg.String()

	switch key {
	case KeyQuit, KeyQuitAlt:
		return KeyActionResult{Action: ActionQuit, Handled: true}
	case KeyEscape:
		return KeyActionResult{Action: ActionEscape, Handled: true}
	case KeyConfirm, KeyConfirmSpace:
		return KeyActionResult{Action: ActionConfirm, Handled: true}
	case KeyUp, KeyUpVim:
		return KeyActionResult{Action: ActionNavigateUp, Handled: true}
	case KeyDown, KeyDownVim:
		return KeyActionResult{Action: ActionNavigateDown, Handled: true}
	case KeySubmit:
		return KeyActionResult{Action: ActionSubmit, Handled: true}
	case KeyPaste:
		return KeyActionResult{Action: ActionPaste, Handled: true}
	case KeyYes, KeyYesUpper, KeyYes1:
		return KeyActionResult{Action: ActionYes, Handled: true}
	case KeyNo, KeyNoUpper, KeyNo2:
		return KeyActionResult{Action: ActionNo, Handled: true}
	default:
		return KeyActionResult{Action: ActionUnknown, Handled: false}
	}
}

// HandleMenuNavigation 处理菜单导航的通用逻辑
func HandleMenuNavigation(m *Model, action KeyAction) bool {
	switch action {
	case ActionNavigateUp:
		if m.cursor > 0 {
			m.cursor--
		}
		return true
	case ActionNavigateDown:
		if m.cursor < len(m.choices)-1 {
			m.cursor++
		}
		return true
	default:
		return false
	}
}

// HandleQuitAction 处理退出动作的通用逻辑
func HandleQuitAction(m *Model) (Model, tea.Cmd) {
	m.quitting = true
	return *m, tea.Quit
}

// HandleEscapeAction 处理ESC键的通用逻辑 - 返回主菜单
func HandleEscapeToMainMenu(m *Model) {
	m.state = stateMainMenu
	m.choices = mainMenuChoices
	m.cursor = 0
	m.operation = "" // 重置操作类型
}

// HandleEscapeToState 处理ESC键返回到指定状态
func HandleEscapeToState(m *Model, state uiState, choices []string) {
	m.state = state
	m.choices = choices
	m.cursor = 0
}

// HandleTextInputPaste 处理文本输入的粘贴操作
type TextInputInterface interface {
	Value() string
	SetValue(string)
}

func HandleTextInputPaste(component interface {
	Value() string
	SetValue(string)
}, msg tea.KeyMsg) {
	if msg.String() == KeyPaste {
		cleanedValue := strings.TrimSpace(component.Value())
		component.SetValue(cleanedValue)
	}
}

// CommonKeyHandlerStruct 通用键盘处理器
type CommonKeyHandlerStruct struct{}

// CommonKeyHandler 创建通用键盘处理器
func CommonKeyHandler() *CommonKeyHandlerStruct {
	return &CommonKeyHandlerStruct{}
}

// HandleCommonKeys 处理通用键盘操作
func (h *CommonKeyHandlerStruct) HandleCommonKeys(m Model, msg tea.KeyMsg) (Model, tea.Cmd, bool) {
	action := ParseKeyAction(msg)

	switch action.Action {
	case ActionQuit:
		newM, cmd := HandleQuitAction(&m)
		return newM, cmd, true
	case ActionNavigateUp, ActionNavigateDown:
		if HandleMenuNavigation(&m, action.Action) {
			return m, nil, true
		}
	}

	return m, nil, false
}

// HandleMenuKeys 处理菜单类型的键盘操作
func (h *CommonKeyHandlerStruct) HandleMenuKeys(m Model, msg tea.KeyMsg, onConfirm func(Model) (Model, tea.Cmd), onEscape func(Model) Model) (Model, tea.Cmd, bool) {
	newM, cmd, handled := h.HandleCommonKeys(m, msg)
	if handled {
		return newM, cmd, true
	}

	action := ParseKeyAction(msg)

	switch action.Action {
	case ActionConfirm:
		if onConfirm != nil {
			newM, cmd := onConfirm(m)
			return newM, cmd, true
		}
		return m, nil, true
	case ActionEscape:
		if onEscape != nil {
			return onEscape(m), nil, true
		}
		HandleEscapeToMainMenu(&m)
		return m, nil, true
	}

	return m, nil, false
}

// HandleInputKeys 处理输入类型的键盘操作
func (h *CommonKeyHandlerStruct) HandleInputKeys(m Model, msg tea.KeyMsg,
	onSubmit func(Model) (Model, tea.Cmd),
	onEscape func(Model) Model,
	onPaste func(Model, tea.KeyMsg) Model) (Model, tea.Cmd, bool) {

	action := ParseKeyAction(msg)

	switch action.Action {
	case ActionQuit:
		newM, cmd := HandleQuitAction(&m)
		return newM, cmd, true
	case ActionSubmit, ActionConfirm:
		if onSubmit != nil {
			newM, cmd := onSubmit(m)
			return newM, cmd, true
		}
		return m, nil, true
	case ActionEscape:
		if onEscape != nil {
			return onEscape(m), nil, true
		}
		return m, nil, true
	case ActionPaste:
		if onPaste != nil {
			return onPaste(m, msg), nil, true
		}
		return m, nil, true
	}

	return m, nil, false
}

// HandleConfirmationKeys 处理确认类型的键盘操作
func (h *CommonKeyHandlerStruct) HandleConfirmationKeys(m Model, msg tea.KeyMsg,
	onYes func(Model) (Model, tea.Cmd),
	onNo func(Model) (Model, tea.Cmd),
	onEscape func(Model) Model) (Model, tea.Cmd, bool) {

	action := ParseKeyAction(msg)

	switch action.Action {
	case ActionQuit:
		newM, cmd := HandleQuitAction(&m)
		return newM, cmd, true
	case ActionYes:
		if onYes != nil {
			newM, cmd := onYes(m)
			return newM, cmd, true
		}
		return m, nil, true
	case ActionNo:
		if onNo != nil {
			newM, cmd := onNo(m)
			return newM, cmd, true
		}
		return m, nil, true
	case ActionEscape:
		if onEscape != nil {
			return onEscape(m), nil, true
		}
		return m, nil, true
	}

	return m, nil, false
}
