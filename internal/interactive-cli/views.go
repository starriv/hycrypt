package interactivecli

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
)

// ViewManagerInterface 视图管理器 - 重构后的views.go的主要接口
type ViewManagerInterface struct {
	flowManager       *FlowManagerInterface
	configFlowManager *ConfigFlowManagerInterface
}

// ViewManager 创建视图管理器
func ViewManager() *ViewManagerInterface {
	return &ViewManagerInterface{
		flowManager:       FlowManager(),
		configFlowManager: ConfigFlowManager(),
	}
}

// 添加handlers.go中缺失的方法以保持兼容性

// updateMainMenu 主菜单更新（保持兼容性）
func (m Model) updateMainMenu(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleMainMenu(m, msg)
}

// viewMainMenu 主菜单视图（保持兼容性）
func (m Model) viewMainMenu() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderMainMenu(m)
}

// updateAlgorithm 算法选择更新（保持兼容性）
func (m Model) updateAlgorithm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// viewAlgorithm 算法选择视图（保持兼容性）
func (m Model) viewAlgorithm() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderAlgorithm(m)
}

// updateInputType 输入类型选择更新（保持兼容性）
func (m Model) updateInputType(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// viewInputType 输入类型选择视图（保持兼容性）
func (m Model) viewInputType() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderInputType(m)
}

// UpdateFileInput 处理文件输入更新（保持原接口兼容性）
func (m Model) updateFileInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewFileInput 渲染文件输入视图（保持原接口兼容性）
func (m Model) viewFileInput() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderFileInput(m)
}

// UpdateTextInput 处理文本输入更新（保持原接口兼容性）
func (m Model) updateTextInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewTextInput 渲染文本输入视图（保持原接口兼容性）
func (m Model) viewTextInput() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderTextInput(m)
}

// UpdateOutputFormat 处理输出格式选择更新（保持原接口兼容性）
func (m Model) updateOutputFormat(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewOutputFormat 渲染输出格式选择视图（保持原接口兼容性）
func (m Model) viewOutputFormat() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderOutputFormat(m)
}

// UpdateOutput 处理输出目录选择更新（保持原接口兼容性）
func (m Model) updateOutput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewOutput 渲染输出目录选择视图（保持原接口兼容性）
func (m Model) viewOutput() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderOutput(m)
}

// ViewProcessing 渲染处理中视图（保持原接口兼容性）
func (m Model) viewProcessing() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderProcessing(m)
}

// ViewComplete 渲染完成视图（保持原接口兼容性）
func (m Model) viewComplete() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderComplete(m)
}

// UpdateComplete 处理完成状态更新（保持原接口兼容性）
func (m Model) updateComplete(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// UpdateHexOutputComplete 处理十六进制输出完成状态更新（保持原接口兼容性）
func (m Model) updateHexOutputComplete(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewHexOutputComplete 渲染十六进制输出完成视图（保持原接口兼容性）
func (m Model) viewHexOutputComplete() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderHexOutputComplete(m)
}

// UpdateKeyGeneration 处理密钥生成更新（保持原接口兼容性）
func (m Model) updateKeyGeneration(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	flowManager := FlowManager()
	return flowManager.HandleKeyMessage(m, msg)
}

// ViewKeyGeneration 渲染密钥生成视图（保持原接口兼容性）
func (m Model) viewKeyGeneration() string {
	viewRenderer := ViewRenderer()
	return viewRenderer.RenderKeyGeneration(m)
}

// ProcessOperation 处理操作（保持原接口兼容性）
func (m Model) processOperation() operationResult {
	operationProcessor := NewOperationProcessor()
	return operationProcessor.ProcessOperation(m)
}

// 配置相关方法（保持原接口兼容性）

// UpdateConfigInit 处理配置初始化更新
func (m Model) updateConfigInit(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	configFlowManager := ConfigFlowManager()
	return configFlowManager.HandleConfigInit(m, msg)
}

// ViewConfigInit 渲染配置初始化视图
func (m Model) viewConfigInit() string {
	s := titleStyle.Render("🔧 首次使用配置") + "\n\n"

	s += "欢迎使用 HyCrypt! 🎉\n\n"

	s += "检测到您还没有配置文件和密钥。\n"
	s += "为了正常使用程序，需要创建以下内容：\n\n"

	s += "📁 全局配置目录: ~/.hycrypt/\n"
	s += "📄 配置文件: config.yaml\n"
	s += "🔑 RSA密钥对: public.pem & private.pem (4096位)\n"
	s += "🔐 KMAC密钥: 自动生成256位密钥\n"
	s += "📂 输出目录: encrypted/ & decrypted/\n\n"

	s += "是否现在创建这些配置？\n\n"

	for i, choice := range m.choices {
		cursor := " "
		if m.cursor == i {
			cursor = ">"
			choice = selectedStyle.Render(choice)
		} else {
			choice = choiceStyle.Render(choice)
		}
		s += fmt.Sprintf("%s %s\n", cursor, choice)
	}

	s += "\n" + infoStyle.Render("↑/↓: 选择  回车: 确认  Ctrl+C: 退出")
	return s
}

// ViewConfigCreating 渲染配置创建中视图
func (m Model) viewConfigCreating() string {
	s := titleStyle.Render("⏳ 正在创建配置...") + "\n\n"

	s += "正在为您创建全局配置，请稍候...\n\n"

	s += infoStyle.Render("📁 创建目录结构") + "\n"
	s += infoStyle.Render("🔑 生成RSA密钥对") + "\n"
	s += infoStyle.Render("🔐 生成KMAC密钥") + "\n"
	s += infoStyle.Render("📄 保存配置文件") + "\n\n"

	s += "这可能需要几秒钟时间..."

	return s
}

// UpdateConfigComplete 处理配置完成更新
func (m Model) updateConfigComplete(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	configFlowManager := ConfigFlowManager()
	return configFlowManager.HandleConfigComplete(m, msg)
}

// ViewConfigComplete 渲染配置完成视图
func (m Model) viewConfigComplete() string {
	if m.error != "" {
		// 配置创建失败
		s := titleStyle.Render("❌ 配置创建失败") + "\n\n"
		s += errorStyle.Render("创建配置时发生错误:") + "\n\n"
		s += errorStyle.Render(m.error) + "\n\n"
		s += infoStyle.Render("程序无法正常使用，请检查文件权限或手动创建配置") + "\n\n"
		s += infoStyle.Render("按任意键退出程序")
		return s
	}

	// 配置创建成功
	s := titleStyle.Render("✅ 配置创建完成!") + "\n\n"

	s += successStyle.Render("恭喜！全局配置已成功创建") + "\n\n"

	s += infoStyle.Render("🎯 现在您可以使用所有功能了！") + "\n"
	s += infoStyle.Render("💡 配置文件可以随时手动编辑") + "\n\n"

	s += infoStyle.Render("按任意键进入主菜单")

	return s
}

// UpdateConfigMenu 处理配置菜单更新
func (m Model) updateConfigMenu(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	configFlowManager := ConfigFlowManager()
	return configFlowManager.HandleConfigMenu(m, msg)
}

// ViewConfigMenu 渲染配置菜单视图
func (m Model) viewConfigMenu() string {
	s := titleStyle.Render("⚙️  配置管理") + "\n\n"
	s += infoStyle.Render("选择要执行的配置操作：") + "\n\n"

	for i, choice := range m.choices {
		cursor := " "
		if m.cursor == i {
			cursor = ">"
			choice = selectedStyle.Render(choice)
		} else {
			choice = choiceStyle.Render(choice)
		}
		s += fmt.Sprintf("%s %s\n", cursor, choice)
	}

	s += "\n" + infoStyle.Render("ESC: 返回主菜单  ↑/↓: 选择  回车: 确认")
	return s
}

// UpdatePrivacyToggle 处理隐私输出设置更新
func (m Model) updatePrivacyToggle(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	configFlowManager := ConfigFlowManager()
	return configFlowManager.HandlePrivacyToggle(m, msg)
}

// ViewPrivacyToggle 渲染隐私输出设置视图
func (m Model) viewPrivacyToggle() string {
	s := titleStyle.Render("🔒 隐私输出设置") + "\n\n"

	// 显示当前设置
	currentStatus := "禁用"
	statusColor := errorStyle
	if m.config.Output.PrivateOutput {
		currentStatus = "启用"
		statusColor = successStyle
	}

	s += infoStyle.Render("当前隐私输出状态: ") + statusColor.Render(currentStatus) + "\n\n"

	s += infoStyle.Render("请选择：") + "\n"
	s += selectedStyle.Render("Y/1") + choiceStyle.Render(" - 启用隐私输出") + "\n"
	s += selectedStyle.Render("N/2") + choiceStyle.Render(" - 禁用隐私输出") + "\n\n"

	s += infoStyle.Render("ESC: 返回配置菜单")
	return s
}

// UpdateCleanupConfirm 处理清理确认更新
func (m Model) updateCleanupConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	configFlowManager := ConfigFlowManager()
	return configFlowManager.HandleCleanupConfirm(m, msg)
}

// ViewCleanupConfirm 渲染清理确认视图
func (m Model) viewCleanupConfirm() string {
	s := titleStyle.Render("🧹 清理隐私目录") + "\n\n"

	s += infoStyle.Render("确认要完全删除这些目录吗？") + "\n\n"
	s += selectedStyle.Render("Y") + " - 是，删除整个目录\n"
	s += choiceStyle.Render("N") + " - 否，取消操作\n\n"
	s += infoStyle.Render("ESC: 返回配置菜单")

	return s
}
