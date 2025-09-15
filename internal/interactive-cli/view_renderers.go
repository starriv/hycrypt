package interactivecli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"hycrypt/internal/utils"
)

// ViewRendererStruct 视图渲染器
type ViewRendererStruct struct{}

// ViewRenderer 创建视图渲染器
func ViewRenderer() *ViewRendererStruct {
	return &ViewRendererStruct{}
}

// RenderFileInput 渲染文件输入视图
func (r *ViewRendererStruct) RenderFileInput(m Model) string {
	// 使用状态管理器获取正确的标题
	var operation OperationType
	switch m.operation {
	case "encrypt":
		operation = OperationEncrypt
	case "decrypt":
		operation = OperationDecrypt
	}

	stateManager := UIStateManager()
	stateManager.SetOperation(operation)
	stateManager.SetState(StateFileInput)

	var title string
	if m.operation == "decrypt" {
		title = "📁 步骤 2/4: 选择文件"
	} else {
		title = "📁 步骤 3/5: 选择文件"
	}
	s := titleStyle.Render(title) + "\n\n"

	if m.operation == "decrypt" {
		s += infoStyle.Render("支持解密单个文件或整个加密文件夹") + "\n\n"
	} else {
		s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
		s += infoStyle.Render(fmt.Sprintf("算法: %s", strings.ToUpper(m.algorithm))) + "\n\n"
	}

	s += "请输入文件或文件夹路径：\n\n"
	s += m.pathInput.View() + "\n\n"

	inputPath := strings.TrimSpace(m.pathInput.Value())
	if inputPath != "" {
		if info, err := os.Stat(inputPath); err == nil {
			if info.IsDir() {
				s += successStyle.Render("✓ 目录有效") + "\n"
				if m.operation == "decrypt" {
					// 检查目录中是否有加密文件
					files, _ := filepath.Glob(filepath.Join(inputPath, "*"+m.config.Encryption.FileExtension))
					if len(files) > 0 {
						s += infoStyle.Render(fmt.Sprintf("发现 %d 个加密文件", len(files))) + "\n"
					} else {
						s += errorStyle.Render("⚠️  目录中没有找到加密文件") + "\n"
					}
				}
			} else {
				s += successStyle.Render("✓ 文件有效") + "\n"
				if m.operation == "decrypt" {
					// 检查是否是加密文件并显示算法检测结果
					if strings.Contains(inputPath, m.config.Encryption.FileExtension) {
						detectedAlgorithm := m.config.DetectAlgorithmFromPath(inputPath)
						if detectedAlgorithm != "" && m.config.IsAlgorithmSupported(detectedAlgorithm) {
							s += successStyle.Render(fmt.Sprintf("✓ 检测到 %s 加密文件", strings.ToUpper(detectedAlgorithm))) + "\n"
							s += infoStyle.Render("将自动跳过算法选择步骤") + "\n"
						} else {
							s += infoStyle.Render("检测到加密文件") + "\n"
							s += errorStyle.Render("⚠️  无法识别算法，需要手动选择") + "\n"
						}
					} else {
						s += errorStyle.Render("⚠️  这不是加密文件") + "\n"
					}
				}
			}
		} else {
			s += errorStyle.Render("✗ 路径不存在") + "\n"
		}
	}

	s += "\n" + infoStyle.Render("提示：可以拖拽文件/文件夹到终端获取路径") + "\n"
	s += infoStyle.Render("程序会自动清理路径中的多余空格") + "\n"
	if m.operation == "decrypt" {
		s += infoStyle.Render("支持：单个加密文件 或 包含加密文件的文件夹") + "\n"
	}
	s += infoStyle.Render("ESC: 返回上级  回车: 确认")
	return s
}

// RenderTextInput 渲染文本输入视图
func (r *ViewRendererStruct) RenderTextInput(m Model) string {
	// 使用状态管理器获取正确的标题
	stateManager := UIStateManager()
	stateManager.SetOperation(OperationEncrypt)
	stateManager.SetState(StateTextInput)

	var title string
	if m.operation == "decrypt" {
		title = "📝 步骤 2/4: 输入文本"
	} else {
		title = "📝 步骤 3/5: 输入文本"
	}
	s := titleStyle.Render(title) + "\n\n"
	s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
	s += infoStyle.Render(fmt.Sprintf("算法: %s", strings.ToUpper(m.algorithm))) + "\n\n"

	s += "请输入要加密的文本内容：\n\n"
	s += m.textArea.View() + "\n\n"

	textContent := m.textArea.Value()
	if len(textContent) > 0 {
		s += infoStyle.Render(fmt.Sprintf("已输入 %d 个字符", len(textContent))) + "\n"
	}

	s += "\n" + infoStyle.Render("ESC: 返回上级  Ctrl+D: 完成输入  回车: 换行")
	return s
}

// RenderOutputFormat 渲染输出格式选择视图
func (r *ViewRendererStruct) RenderOutputFormat(m Model) string {
	// 使用状态管理器获取正确的标题
	stateManager := UIStateManager()
	stateManager.SetOperation(OperationEncrypt)
	stateManager.SetState(StateOutputFormat)

	s := titleStyle.Render("📤 步骤 3/5: 选择输出格式") + "\n\n"
	s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
	s += infoStyle.Render(fmt.Sprintf("算法: %s", strings.ToUpper(m.algorithm))) + "\n"
	s += infoStyle.Render("输入类型: 文本内容") + "\n\n"

	s += "请选择文本加密的输出格式：\n\n"

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

	s += "\n" + infoStyle.Render("文件格式：保存为加密文件，可用于长期存储") + "\n"
	s += infoStyle.Render("十六进制：输出为可复制的十六进制字符串") + "\n"
	s += "\n" + infoStyle.Render("ESC: 返回上级  ↑/↓: 选择  回车: 确认")
	return s
}

// RenderOutput 渲染输出目录选择视图
func (r *ViewRendererStruct) RenderOutput(m Model) string {
	// 使用状态管理器获取正确的标题
	var operation OperationType
	switch m.operation {
	case "encrypt":
		operation = OperationEncrypt
	case "decrypt":
		operation = OperationDecrypt
	}

	stateManager := UIStateManager()
	stateManager.SetOperation(operation)
	stateManager.SetState(StateOutput)

	var title string
	if m.operation == "decrypt" {
		title = "📂 步骤 3/4: 设置输出目录"
	} else {
		title = "📂 步骤 4/5: 设置输出目录"
	}
	s := titleStyle.Render(title) + "\n\n"

	s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
	s += infoStyle.Render(fmt.Sprintf("算法: %s", strings.ToUpper(m.algorithm))) + "\n"

	if m.operation == "decrypt" {
		s += infoStyle.Render("解密文件将保存到：") + "\n\n"
	} else {
		s += infoStyle.Render("加密文件将保存到：") + "\n\n"
	}

	s += m.outputInput.View() + "\n\n"

	// 显示默认目录提示
	var defaultDir string
	if m.operation == "decrypt" {
		defaultDir = m.config.GetDecryptedDirPath()
	} else {
		defaultDir = m.config.GetEncryptedDirPath()
	}

	if m.outputInput.Value() == "" {
		s += infoStyle.Render(fmt.Sprintf("默认输出目录: %s", defaultDir)) + "\n"
	}

	s += infoStyle.Render("留空使用默认目录") + "\n"
	s += "\n" + infoStyle.Render("ESC: 返回上级  回车: 开始处理")
	return s
}

// RenderProcessing 渲染处理中视图
func (r *ViewRendererStruct) RenderProcessing(m Model) string {
	// 使用状态管理器获取正确的处理标题
	var operation OperationType
	switch m.operation {
	case "encrypt":
		operation = OperationEncrypt
	case "decrypt":
		operation = OperationDecrypt
	case "keygen":
		operation = OperationKeyGen
	}

	stateManager := UIStateManager()
	stateManager.SetOperation(operation)
	stateManager.SetAlgorithm(m.algorithm)
	stateManager.SetState(StateProcessing)
	stateManager.SetProgress(m.progress)

	// 获取正确的处理标题
	s := titleStyle.Render(stateManager.GetProcessingTitle()) + "\n\n"

	// 添加处理描述
	s += stateManager.GetProcessingDescription() + "\n\n"

	// 添加操作详情
	s += "密钥来源: 本地密钥文件\n"
	if m.inputType == "file" {
		s += fmt.Sprintf("输入文件: %s\n", filepath.Base(m.pathInput.Value()))
	} else {
		s += "输入类型: 文本内容\n"
	}

	s += "\n" + r.renderProgressBar(m) + "\n\n"
	s += infoStyle.Render("请稍候，正在处理您的请求...")

	return s
}

// RenderComplete 渲染完成视图
func (r *ViewRendererStruct) RenderComplete(m Model) string {
	// 使用状态管理器获取正确的标题
	stateManager := UIStateManager()
	stateManager.SetState(StateComplete)

	s := titleStyle.Render(stateManager.GetCompleteTitle()) + "\n\n"

	if m.error != "" {
		s += errorStyle.Render("❌ 错误: "+m.error) + "\n\n"
	} else if m.result != "" {
		s += successStyle.Render("✅ "+m.result) + "\n\n"

		// 显示详细的操作结果信息（与命令行模式完全一致）
		if m.resultInfo.FileName != "" {
			s += "📊 " + titleStyle.Render("操作结果详情") + "\n\n"

			if m.operation == "encrypt" {
				// 加密操作的详细信息
				var originalFileName string
				if m.inputType == "text" {
					originalFileName = "文本内容"
				} else {
					originalFileName = filepath.Base(strings.TrimSpace(m.pathInput.Value()))
				}

				s += fmt.Sprintf("📄 文件名: %s\n", originalFileName)
				if m.resultInfo.FileSize > 0 {
					s += fmt.Sprintf("📏 文件大小: %s\n", utils.FormatFileSize(m.resultInfo.FileSize))
				}
				s += fmt.Sprintf("🔐 加密算法: %s\n", m.resultInfo.Algorithm)
				s += fmt.Sprintf("⏱️  处理时间: %s\n", m.resultInfo.EncryptionTime)
				s += fmt.Sprintf("📂 储存目录: %s\n", m.resultInfo.OutputPath)

				// 显示实际生成的加密文件名
				s += fmt.Sprintf("📝 加密文件: %s\n", m.resultInfo.FileName)

			} else if m.operation == "decrypt" {
				// 解密操作的详细信息
				s += fmt.Sprintf("📄 原文件名: %s\n", m.resultInfo.FileName)
				if m.resultInfo.FileSize > 0 {
					s += fmt.Sprintf("📏 文件大小: %s\n", utils.FormatFileSize(m.resultInfo.FileSize))
				}
				s += fmt.Sprintf("🔐 检测算法: %s\n", m.resultInfo.Algorithm)
				s += fmt.Sprintf("⏱️  处理时间: %s\n", m.resultInfo.EncryptionTime)
				s += fmt.Sprintf("📂 输出目录: %s\n", m.resultInfo.OutputPath)

				// 显示解密后的文件
				decryptedFileName := m.resultInfo.DecryptedFile
				if decryptedFileName == "" {
					// 回退到原始逻辑
					decryptedFileName = utils.GetOriginalFileName(m.resultInfo.FileName)
				}
				s += fmt.Sprintf("📝 解密文件: %s\n", decryptedFileName)
			}
		} else {
			// 如果没有详细信息，显示基本信息
			s += infoStyle.Render("操作已完成，但缺少详细信息") + "\n"
		}
	}

	s += "\n" + infoStyle.Render("按任意键返回主菜单 | Ctrl+C: 退出程序")
	return s
}

// RenderHexOutputComplete 渲染十六进制输出完成视图
func (r *ViewRendererStruct) RenderHexOutputComplete(m Model) string {
	// 解析存储在OutputPath中的数据（格式：hexData|originalText|algorithm）
	parts := strings.Split(m.resultInfo.OutputPath, "|")
	if len(parts) == 3 {
		hexData := parts[0]
		originalText := parts[1]
		algorithm := parts[2]

		// 根据算法类型判断是加密还是解密
		isEncryption := !strings.Contains(algorithm, "解密")

		// 构建完整的输出字符串
		var result strings.Builder

		// 清除屏幕并移动光标到顶部
		result.WriteString("\033[2J\033[H")

		if isEncryption {
			// 加密结果输出
			result.WriteString(strings.Repeat("=", 70) + "\n")
			result.WriteString("🔑 文本加密完成 (" + algorithm + ")\n")
			result.WriteString(strings.Repeat("=", 70) + "\n\n")
			result.WriteString("原始文本:\n")
			result.WriteString(originalText + "\n\n")
			result.WriteString("加密结果 (十六进制):\n")
			result.WriteString(strings.Repeat("-", 70) + "\n")

			// 格式化十六进制输出，每行显示64个字符
			for i := 0; i < len(hexData); i += 64 {
				end := i + 64
				if end > len(hexData) {
					end = len(hexData)
				}
				result.WriteString(hexData[i:end] + "\n")
			}

			result.WriteString(strings.Repeat("-", 70) + "\n")
		} else {
			// 解密结果输出
			result.WriteString(strings.Repeat("=", 70) + "\n")
			result.WriteString("🔓 十六进制解密完成 (" + algorithm + ")\n")
			result.WriteString(strings.Repeat("=", 70) + "\n\n")
			result.WriteString("输入的十六进制数据:\n")
			result.WriteString(originalText + "\n\n")
			result.WriteString("解密结果:\n")
			result.WriteString(strings.Repeat("-", 70) + "\n")
			result.WriteString(hexData + "\n")
			result.WriteString(strings.Repeat("-", 70) + "\n")
		}

		result.WriteString(fmt.Sprintf("\n⏱️  处理时间: %s\n", m.resultInfo.EncryptionTime))
		result.WriteString(strings.Repeat("=", 70) + "\n\n")
		result.WriteString("按任意键返回主菜单 | Ctrl+C: 退出程序")

		return result.String()
	}

	return "输出错误：无法解析结果数据"
}

// RenderKeyGeneration 渲染密钥生成视图
func (r *ViewRendererStruct) RenderKeyGeneration(m Model) string {
	s := titleStyle.Render("🔑 密钥管理") + "\n\n"
	s += infoStyle.Render("选择要执行的操作：") + "\n\n"

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

	s += "\n" + infoStyle.Render("ESC: 返回主菜单  ↑/↓: 选择  回车: 执行")
	return s
}

// 辅助方法

func (r *ViewRendererStruct) renderProgressBar(m Model) string {
	const width = 40
	filled := int(m.progress * width)

	bar := "["
	for i := 0; i < width; i++ {
		if i < filled {
			bar += "█"
		} else {
			bar += "░"
		}
	}
	bar += "]"

	percentage := int(m.progress * 100)
	return fmt.Sprintf("%s %d%%", bar, percentage)
}

// RenderMainMenu 渲染主菜单视图
func (r *ViewRendererStruct) RenderMainMenu(m Model) string {
	s := titleStyle.Render("🔐 HyCrypt") + "\n\n"
	s += infoStyle.Render("选择要执行的操作：") + "\n\n"

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

	s += "\n" + infoStyle.Render("使用 ↑/↓ 选择，回车确认，q 退出")
	return s
}

// RenderAlgorithm 渲染算法选择视图
func (r *ViewRendererStruct) RenderAlgorithm(m Model) string {
	// 根据操作类型显示不同的标题和提示文本
	var title string
	var prompt string
	if m.operation == "decrypt" {
		title = "🔓 步骤 1/5: 选择解密算法"
		prompt = "请选择要使用的解密算法："
	} else {
		title = "🔐 步骤 1/5: 选择加密算法"
		prompt = "请选择要使用的加密算法："
	}

	s := titleStyle.Render(title) + "\n\n"
	s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
	s += infoStyle.Render(prompt) + "\n\n"

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

	s += "\n" + infoStyle.Render("RSA: 公钥加密，适合小文件和混合加密") + "\n"
	s += infoStyle.Render("KMAC: 对称加密，高性能，适合大文件") + "\n"
	s += "\n" + infoStyle.Render("ESC: 返回上级  ↑/↓: 选择  回车: 确认")
	return s
}

// RenderInputType 渲染输入类型选择视图
func (r *ViewRendererStruct) RenderInputType(m Model) string {
	// 根据操作类型显示不同的标题和描述
	var title string
	var fileDesc string
	var textDesc string
	if m.operation == "decrypt" {
		title = "📥 步骤 1/4: 选择解密模式"
		fileDesc = "文件模式：解密文件或文件夹（自动检测算法）"
		textDesc = "文本模式：解密十六进制文本（使用选定算法）"
	} else {
		title = "📥 步骤 2/5: 选择加密模式"
		fileDesc = "文件模式：加密文件或文件夹"
		textDesc = "文本模式：直接输入要加密的文本"
	}

	s := titleStyle.Render(title) + "\n\n"
	s += infoStyle.Render("密钥来源: 本地密钥文件") + "\n"
	s += infoStyle.Render(fmt.Sprintf("算法: %s", strings.ToUpper(m.algorithm))) + "\n\n"

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

	s += "\n" + infoStyle.Render(fileDesc) + "\n"
	s += infoStyle.Render(textDesc) + "\n"
	s += "\n" + infoStyle.Render("ESC: 返回上级  ↑/↓: 选择  回车: 确认")
	return s
}
