package interactivecli

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"hycrypt/internal/constants"
)

// KeygenFeatureStruct 密钥生成功能处理器
type KeygenFeatureStruct struct{}

// KeygenFeature 创建密钥生成功能处理器
func KeygenFeature() *KeygenFeatureStruct {
	return &KeygenFeatureStruct{}
}

// HandleKeyGeneration 处理密钥生成菜单
func (k *KeygenFeatureStruct) HandleKeyGeneration(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.state = stateMainMenu
		m.choices = mainMenuChoices
		m.cursor = 0
		m.operation = "" // 重置操作类型
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(m.choices)-1 {
			m.cursor++
		}
	case "enter", " ":
		supportedAlgorithms := m.config.GetSupportedAlgorithms()
		if m.cursor < len(supportedAlgorithms) {
			algorithm := supportedAlgorithms[m.cursor]
			switch strings.ToLower(algorithm) {
			case constants.AlgorithmRSA:
				// 生成 RSA 密钥对
				if m.checkRSAKeysExist() {
					// 密钥已存在，询问是否覆盖
					m.state = stateRSAKeyConfirm
				} else {
					// 直接生成
					m.state = stateProcessing
					return m, tea.Cmd(func() tea.Msg {
						return m.generateRSAKeys(false)
					})
				}
			case constants.AlgorithmKMAC:
				// 生成 KMAC 密钥
				if m.checkKMACKeyExists() {
					// 密钥已存在，询问是否覆盖
					m.state = stateKMACKeyConfirm
				} else {
					// 直接生成
					m.state = stateProcessing
					return m, tea.Cmd(func() tea.Msg {
						return m.generateKMACKey(false)
					})
				}
			}
		}
	}
	return m, nil
}

// HandleRSAKeyConfirm 处理RSA密钥确认
func (k *KeygenFeatureStruct) HandleRSAKeyConfirm(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	case "y", "Y":
		// 确认覆盖，开始生成
		m.state = stateProcessing
		return m, tea.Cmd(func() tea.Msg {
			return m.generateRSAKeys(true)
		})
	case "n", "N":
		// 取消操作，返回密钥生成菜单
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	}
	return m, nil
}

// HandleKMACKeyConfirm 处理KMAC密钥确认
func (k *KeygenFeatureStruct) HandleKMACKeyConfirm(m Model, msg tea.KeyMsg) (Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c", "q":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	case "y", "Y":
		// 确认覆盖，开始生成
		m.state = stateProcessing
		return m, tea.Cmd(func() tea.Msg {
			return m.generateKMACKey(true)
		})
	case "n", "N":
		// 取消操作，返回密钥生成菜单
		m.state = stateKeyGeneration
		m.choices = getKeyGenMenuChoices(m.config)
		m.cursor = 0
	}
	return m, nil
}
