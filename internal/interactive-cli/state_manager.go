package interactivecli

import (
	"fmt"
	"strings"
)

// UIState UI状态
type UIState int

const (
	StateMainMenu UIState = iota
	StateKeySource
	StateKeySelection
	StateAlgorithm
	StateInputType
	StateFileInput
	StateTextInput
	StateHexInput
	StateOutputFormat
	StateOutput
	StateKeyGeneration
	StateRSAKeyConfirm
	StateKMACKeyConfirm
	StateProcessing
	StateComplete
)

// OperationType 操作类型
type OperationType int

const (
	OperationEncrypt OperationType = iota
	OperationDecrypt
	OperationKeyGen
)

// InputType 输入类型
type InputType int

const (
	InputTypeFile InputType = iota
	InputTypeText
	InputTypeHex
)

// UIStateManagerStruct UI状态管理器
type UIStateManagerStruct struct {
	currentState UIState
	operation    OperationType
	inputType    InputType
	algorithm    string
	progress     float64

	// 步骤计算
	totalSteps  int
	currentStep int
	stepNames   map[UIState]string
}

// UIStateManager 创建状态管理器
func UIStateManager() *UIStateManagerStruct {
	return &UIStateManagerStruct{
		currentState: StateMainMenu,
		stepNames: map[UIState]string{
			StateMainMenu:       "选择操作",
			StateKeySource:      "选择密钥来源",
			StateKeySelection:   "选择密钥",
			StateAlgorithm:      "选择算法",
			StateInputType:      "选择输入类型",
			StateFileInput:      "选择文件",
			StateTextInput:      "输入文本",
			StateHexInput:       "输入十六进制",
			StateOutputFormat:   "选择输出格式",
			StateOutput:         "设置输出目录",
			StateProcessing:     "处理中",
			StateComplete:       "完成",
			StateKeyGeneration:  "密钥管理",
			StateRSAKeyConfirm:  "确认RSA密钥",
			StateKMACKeyConfirm: "确认KMAC密钥",
		},
	}
}

// SetState 设置当前状态
func (sm *UIStateManagerStruct) SetState(state UIState) {
	sm.currentState = state
	sm.updateStepInfo()
}

// SetOperation 设置操作类型
func (sm *UIStateManagerStruct) SetOperation(op OperationType) {
	sm.operation = op
	sm.updateStepInfo()
}

// SetInputType 设置输入类型
func (sm *UIStateManagerStruct) SetInputType(inputType InputType) {
	sm.inputType = inputType
}

// SetAlgorithm 设置算法
func (sm *UIStateManagerStruct) SetAlgorithm(algorithm string) {
	sm.algorithm = algorithm
}

// SetProgress 设置进度
func (sm *UIStateManagerStruct) SetProgress(progress float64) {
	sm.progress = progress
}

// GetProcessingTitle 获取处理中标题
func (sm *UIStateManagerStruct) GetProcessingTitle() string {
	switch sm.operation {
	case OperationEncrypt:
		return fmt.Sprintf("⏳ 步骤 %d/%d: 加密处理中...", sm.currentStep, sm.totalSteps)
	case OperationDecrypt:
		return fmt.Sprintf("⏳ 步骤 %d/%d: 解密处理中...", sm.currentStep, sm.totalSteps)
	case OperationKeyGen:
		return fmt.Sprintf("⏳ 步骤 %d/%d: 密钥生成中...", sm.currentStep, sm.totalSteps)
	default:
		return fmt.Sprintf("⏳ 步骤 %d/%d: 处理中...", sm.currentStep, sm.totalSteps)
	}
}

// GetProcessingDescription 获取处理描述
func (sm *UIStateManagerStruct) GetProcessingDescription() string {
	switch sm.operation {
	case OperationEncrypt:
		if sm.algorithm != "" {
			return fmt.Sprintf("🔒 正在使用 %s 算法加密...", strings.ToUpper(sm.algorithm))
		}
		return "🔒 正在加密..."
	case OperationDecrypt:
		if sm.algorithm != "" {
			return fmt.Sprintf("🔓 正在使用 %s 算法解密...", strings.ToUpper(sm.algorithm))
		}
		return "🔓 正在解密..."
	case OperationKeyGen:
		return "🔑 正在生成密钥..."
	default:
		return "正在处理..."
	}
}

// GetCompleteTitle 获取完成标题
func (sm *UIStateManagerStruct) GetCompleteTitle() string {
	return fmt.Sprintf("🎉 步骤 %d/%d: 操作完成", sm.totalSteps, sm.totalSteps)
}

// GetStepTitle 获取步骤标题
func (sm *UIStateManagerStruct) GetStepTitle(state UIState) string {
	stepName := sm.stepNames[state]
	if stepName == "" {
		stepName = "未知步骤"
	}

	// 根据操作类型添加图标
	var icon string
	switch sm.operation {
	case OperationEncrypt:
		icon = getEncryptionIcon(state)
	case OperationDecrypt:
		icon = getDecryptionIcon(state)
	case OperationKeyGen:
		icon = getKeyGenIcon(state)
	default:
		icon = "🛠️"
	}

	return fmt.Sprintf("%s 步骤 %d/%d: %s", icon, sm.currentStep, sm.totalSteps, stepName)
}

// 内部方法

func (sm *UIStateManagerStruct) updateStepInfo() {
	switch sm.operation {
	case OperationEncrypt:
		sm.updateEncryptionSteps()
	case OperationDecrypt:
		sm.updateDecryptionSteps()
	case OperationKeyGen:
		sm.updateKeyGenSteps()
	default:
		sm.totalSteps = 7
		sm.currentStep = sm.getStepNumber(sm.currentState)
	}
}

func (sm *UIStateManagerStruct) updateEncryptionSteps() {
	sm.totalSteps = 7
	sm.currentStep = sm.getStepNumber(sm.currentState)
}

func (sm *UIStateManagerStruct) updateDecryptionSteps() {
	sm.totalSteps = 6 // 解密通常少一步（不需要选择输出格式）
	sm.currentStep = sm.getStepNumber(sm.currentState)
}

func (sm *UIStateManagerStruct) updateKeyGenSteps() {
	sm.totalSteps = 3
	sm.currentStep = sm.getStepNumber(sm.currentState)
}

func (sm *UIStateManagerStruct) getStepNumber(state UIState) int {
	switch state {
	case StateMainMenu:
		return 1
	case StateKeySource, StateAlgorithm:
		return 2
	case StateKeySelection:
		return 3
	case StateInputType:
		return 3
	case StateFileInput, StateTextInput, StateHexInput:
		return 4
	case StateOutputFormat:
		return 5
	case StateOutput:
		if sm.operation == OperationEncrypt {
			return 6
		}
		return 5
	case StateProcessing:
		if sm.operation == OperationEncrypt {
			return 6
		}
		return 5
	case StateComplete:
		return sm.totalSteps
	case StateKeyGeneration:
		return 1
	case StateRSAKeyConfirm, StateKMACKeyConfirm:
		return 2
	default:
		return 1
	}
}

// 图标获取函数

func getEncryptionIcon(state UIState) string {
	switch state {
	case StateFileInput:
		return "📁"
	case StateTextInput:
		return "📝"
	case StateHexInput:
		return "🔤"
	case StateOutputFormat:
		return "📤"
	case StateOutput:
		return "📂"
	case StateProcessing:
		return "⏳"
	case StateComplete:
		return "🎉"
	default:
		return "🔒"
	}
}

func getDecryptionIcon(state UIState) string {
	switch state {
	case StateFileInput:
		return "📁"
	case StateTextInput:
		return "📝"
	case StateHexInput:
		return "🔤"
	case StateOutput:
		return "📂"
	case StateProcessing:
		return "⏳"
	case StateComplete:
		return "🎉"
	default:
		return "🔓"
	}
}

func getKeyGenIcon(state UIState) string {
	switch state {
	case StateKeyGeneration:
		return "🔑"
	case StateRSAKeyConfirm, StateKMACKeyConfirm:
		return "⚠️"
	case StateProcessing:
		return "⏳"
	case StateComplete:
		return "🎉"
	default:
		return "🔑"
	}
}
