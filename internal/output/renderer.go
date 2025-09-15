package output

import (
	"fmt"
	"strings"
	"time"

	"hycrypt/internal/utils"
)

// OutputMode 输出模式
type OutputMode int

const (
	ModeCLI OutputMode = iota // 命令行模式
	ModeUI                    // 界面模式
)

// ResultType 结果类型
type ResultType int

const (
	TypeEncryption ResultType = iota // 加密结果
	TypeDecryption                   // 解密结果
	TypeKeyGen                       // 密钥生成结果
	TypeHexOutput                    // 十六进制输出
	TypeHexDecrypt                   // 十六进制解密
	TypeError                        // 错误结果
)

// OperationResult 操作结果
type OperationResult struct {
	Success     bool
	Type        ResultType
	Message     string
	Details     *ResultDetails
	Error       error
	ProcessTime time.Duration
}

// ResultDetails 结果详情
type ResultDetails struct {
	// 基本信息
	FileName   string
	FilePath   string
	FileSize   int64
	Algorithm  string
	OutputPath string

	// 特殊数据
	HexData       string // 十六进制数据
	OriginalText  string // 原始文本
	DecryptedText string // 解密文本

	// 扩展信息
	Extra map[string]interface{}
}

// RendererInterface 统一渲染器接口
type RendererInterface interface {
	RenderResult(result *OperationResult) string
	RenderProgress(progress float64, message string) string
	RenderError(err error) string
}

// UnifiedRenderer 统一渲染器
type UnifiedRenderer struct {
	mode   OutputMode
	config *RendererConfig
}

// RendererConfig 渲染器配置
type RendererConfig struct {
	UseEmoji     bool
	UseColors    bool
	ShowProgress bool
	Verbose      bool
}

// NewRenderer 创建渲染器
func Renderer(mode OutputMode, config *RendererConfig) *UnifiedRenderer {
	if config == nil {
		config = &RendererConfig{
			UseEmoji:     true,
			UseColors:    mode == ModeCLI,
			ShowProgress: true,
			Verbose:      false,
		}
	}

	return &UnifiedRenderer{
		mode:   mode,
		config: config,
	}
}

// RenderResult 渲染操作结果
func (r *UnifiedRenderer) RenderResult(result *OperationResult) string {
	if !result.Success {
		return r.renderError(result)
	}

	switch result.Type {
	case TypeEncryption:
		return r.renderEncryptionResult(result)
	case TypeDecryption:
		return r.renderDecryptionResult(result)
	case TypeKeyGen:
		return r.renderKeyGenResult(result)
	case TypeHexOutput:
		return r.renderHexOutputResult(result)
	case TypeHexDecrypt:
		return r.renderHexDecryptResult(result)
	default:
		return r.renderGenericResult(result)
	}
}

// RenderProgress 渲染进度
func (r *UnifiedRenderer) RenderProgress(progress float64, message string) string {
	if !r.config.ShowProgress {
		return ""
	}

	if r.mode == ModeUI {
		return r.renderUIProgress(progress, message)
	}
	return r.renderCLIProgress(progress, message)
}

// RenderError 渲染错误
func (r *UnifiedRenderer) RenderError(err error) string {
	if r.config.UseEmoji {
		return fmt.Sprintf("❌ 错误: %v", err)
	}
	return fmt.Sprintf("错误: %v", err)
}

// 内部渲染方法

func (r *UnifiedRenderer) renderEncryptionResult(result *OperationResult) string {
	var builder strings.Builder

	// 标题
	if r.config.UseEmoji {
		builder.WriteString("✅ 加密完成!\n\n")
	} else {
		builder.WriteString("加密完成!\n\n")
	}

	// 详细信息
	if result.Details != nil {
		builder.WriteString(r.renderResultDetails("加密", result.Details, result.ProcessTime))
	}

	return builder.String()
}

func (r *UnifiedRenderer) renderDecryptionResult(result *OperationResult) string {
	var builder strings.Builder

	// 标题
	if r.config.UseEmoji {
		builder.WriteString("✅ 解密完成!\n\n")
	} else {
		builder.WriteString("解密完成!\n\n")
	}

	// 详细信息
	if result.Details != nil {
		builder.WriteString(r.renderResultDetails("解密", result.Details, result.ProcessTime))
	}

	return builder.String()
}

func (r *UnifiedRenderer) renderKeyGenResult(result *OperationResult) string {
	var builder strings.Builder

	if r.config.UseEmoji {
		builder.WriteString("✅ 密钥生成完成!\n\n")
	} else {
		builder.WriteString("密钥生成完成!\n\n")
	}

	builder.WriteString(result.Message)
	return builder.String()
}

func (r *UnifiedRenderer) renderHexOutputResult(result *OperationResult) string {
	if result.Details == nil {
		return result.Message
	}

	var builder strings.Builder

	// 统一的十六进制输出格式
	builder.WriteString(strings.Repeat("=", 70) + "\n")
	if r.config.UseEmoji {
		builder.WriteString(fmt.Sprintf("🔑 文本加密完成 (%s)\n", result.Details.Algorithm))
	} else {
		builder.WriteString(fmt.Sprintf("文本加密完成 (%s)\n", result.Details.Algorithm))
	}
	builder.WriteString(strings.Repeat("=", 70) + "\n\n")

	// 原始文本
	builder.WriteString("原始文本:\n")
	builder.WriteString(result.Details.OriginalText + "\n\n")

	// 加密结果
	builder.WriteString("加密结果 (十六进制):\n")
	builder.WriteString(strings.Repeat("-", 70) + "\n")

	// 格式化十六进制输出，每行64字符
	hexData := result.Details.HexData
	for i := 0; i < len(hexData); i += 64 {
		end := i + 64
		if end > len(hexData) {
			end = len(hexData)
		}
		builder.WriteString(hexData[i:end] + "\n")
	}

	builder.WriteString(strings.Repeat("-", 70) + "\n")

	// 处理时间
	if r.config.UseEmoji {
		builder.WriteString(fmt.Sprintf("\n⏱️  处理时间: %v\n", result.ProcessTime))
	} else {
		builder.WriteString(fmt.Sprintf("\n处理时间: %v\n", result.ProcessTime))
	}

	builder.WriteString(strings.Repeat("=", 70) + "\n")

	return builder.String()
}

func (r *UnifiedRenderer) renderHexDecryptResult(result *OperationResult) string {
	if result.Details == nil {
		return result.Message
	}

	var builder strings.Builder

	// 统一的十六进制解密输出格式
	builder.WriteString(strings.Repeat("=", 70) + "\n")
	if r.config.UseEmoji {
		builder.WriteString(fmt.Sprintf("🔓 十六进制解密完成 (%s)\n", result.Details.Algorithm))
	} else {
		builder.WriteString(fmt.Sprintf("十六进制解密完成 (%s)\n", result.Details.Algorithm))
	}
	builder.WriteString(strings.Repeat("=", 70) + "\n\n")

	// 输入的十六进制数据
	builder.WriteString("输入的十六进制数据:\n")
	builder.WriteString(result.Details.HexData + "\n\n")

	// 解密结果
	builder.WriteString("解密结果:\n")
	builder.WriteString(strings.Repeat("-", 70) + "\n")
	builder.WriteString(result.Details.DecryptedText + "\n")
	builder.WriteString(strings.Repeat("-", 70) + "\n")

	// 处理时间
	if r.config.UseEmoji {
		builder.WriteString(fmt.Sprintf("\n⏱️  处理时间: %v\n", result.ProcessTime))
	} else {
		builder.WriteString(fmt.Sprintf("\n处理时间: %v\n", result.ProcessTime))
	}

	builder.WriteString(strings.Repeat("=", 70) + "\n")

	return builder.String()
}

func (r *UnifiedRenderer) renderGenericResult(result *OperationResult) string {
	var builder strings.Builder

	if result.Success {
		if r.config.UseEmoji {
			builder.WriteString("✅ ")
		}
		builder.WriteString(result.Message)
	} else {
		if r.config.UseEmoji {
			builder.WriteString("❌ ")
		}
		builder.WriteString(result.Message)
	}

	return builder.String()
}

func (r *UnifiedRenderer) renderError(result *OperationResult) string {
	if r.config.UseEmoji {
		return fmt.Sprintf("❌ 错误: %s", result.Message)
	}
	return fmt.Sprintf("错误: %s", result.Message)
}

func (r *UnifiedRenderer) renderResultDetails(operation string, details *ResultDetails, processTime time.Duration) string {
	var builder strings.Builder

	if r.config.UseEmoji {
		builder.WriteString("📊 ")
	}
	builder.WriteString(fmt.Sprintf("%s结果详情:\n", operation))

	// 文件信息
	if details.FileName != "" {
		if r.config.UseEmoji {
			builder.WriteString("📄 ")
		}
		builder.WriteString(fmt.Sprintf("文件名: %s\n", details.FileName))
	}

	if details.FileSize > 0 {
		if r.config.UseEmoji {
			builder.WriteString("📏 ")
		}
		builder.WriteString(fmt.Sprintf("文件大小: %s\n", utils.FormatFileSize(details.FileSize)))
	}

	// 算法信息
	if details.Algorithm != "" {
		if r.config.UseEmoji {
			builder.WriteString("🔐 ")
		}
		builder.WriteString(fmt.Sprintf("算法: %s\n", details.Algorithm))
	}

	// 处理时间
	if r.config.UseEmoji {
		builder.WriteString("⏱️  ")
	}
	builder.WriteString(fmt.Sprintf("处理时间: %v\n", processTime))

	// 输出路径
	if details.OutputPath != "" {
		if r.config.UseEmoji {
			builder.WriteString("📂 ")
		}
		builder.WriteString(fmt.Sprintf("输出目录: %s\n", details.OutputPath))
	}

	// 具体文件信息
	if details.FilePath != "" {
		// 判断是加密还是解密
		if strings.Contains(operation, "加密") {
			if r.config.UseEmoji {
				builder.WriteString("📝 ")
			}
			builder.WriteString(fmt.Sprintf("加密文件: %s\n", details.FileName))
		} else {
			originalFileName := utils.GetOriginalFileName(details.FileName)
			if r.config.UseEmoji {
				builder.WriteString("📝 ")
			}
			builder.WriteString(fmt.Sprintf("解密文件: %s\n", originalFileName))
		}
	}

	return builder.String()
}

func (r *UnifiedRenderer) renderUIProgress(progress float64, message string) string {
	const width = 40
	filled := int(progress * width)

	bar := "["
	for i := 0; i < width; i++ {
		if i < filled {
			bar += "█"
		} else {
			bar += "░"
		}
	}
	bar += "]"

	percentage := int(progress * 100)
	return fmt.Sprintf("%s %d%%\n%s", bar, percentage, message)
}

func (r *UnifiedRenderer) renderCLIProgress(progress float64, message string) string {
	if progress >= 1.0 {
		return ""
	}

	percentage := int(progress * 100)
	return fmt.Sprintf("进度: %d%% - %s", percentage, message)
}

// 辅助函数
