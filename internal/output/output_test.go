package output

import (
	"strings"
	"testing"
	"time"
)

func TestOutputConsistency(t *testing.T) {
	// 测试数据
	testResult := EncryptionResult(
		"document.txt",
		"RSA",
		"./encrypted/",
		1024,
		100*time.Millisecond,
	)

	// 创建CLI和UI渲染器
	cliConfig := &RendererConfig{
		UseEmoji:     true,
		UseColors:    true,
		ShowProgress: true,
		Verbose:      false,
	}

	uiConfig := &RendererConfig{
		UseEmoji:     true,
		UseColors:    false, // UI模式不使用颜色
		ShowProgress: true,
		Verbose:      false,
	}

	cliRenderer := Renderer(ModeCLI, cliConfig)
	uiRenderer := Renderer(ModeUI, uiConfig)

	// 渲染结果
	cliOutput := cliRenderer.RenderResult(testResult)
	uiOutput := uiRenderer.RenderResult(testResult)

	// 验证基本一致性（除了颜色代码）
	cliLines := strings.Split(cliOutput, "\n")
	uiLines := strings.Split(uiOutput, "\n")

	if len(cliLines) != len(uiLines) {
		t.Errorf("CLI和UI输出行数不一致: CLI=%d, UI=%d", len(cliLines), len(uiLines))
	}

	// 验证关键信息存在
	expectedContents := []string{
		"加密完成",
		"document.txt",
		"RSA",
		"./encrypted/",
		"1.00 KB", // 修正文件大小格式
		"100ms",
	}

	for _, expected := range expectedContents {
		if !strings.Contains(cliOutput, expected) {
			t.Errorf("CLI输出缺少预期内容: %s", expected)
		}
		if !strings.Contains(uiOutput, expected) {
			t.Errorf("UI输出缺少预期内容: %s", expected)
		}
	}
}

func TestHexOutputConsistency(t *testing.T) {
	// 测试十六进制输出一致性
	testResult := HexOutputResult(
		"Hello, World!",
		"48656c6c6f2c20576f726c6421",
		"RSA",
		50*time.Millisecond,
	)

	cliRenderer := Renderer(ModeCLI, &RendererConfig{UseEmoji: true})
	uiRenderer := Renderer(ModeUI, &RendererConfig{UseEmoji: true})

	cliOutput := cliRenderer.RenderResult(testResult)
	uiOutput := uiRenderer.RenderResult(testResult)

	// 验证十六进制输出格式一致性
	expectedElements := []string{
		"文本加密完成",
		"Hello, World!",
		"48656c6c6f2c20576f726c6421",
		"RSA",
		"50ms",
		"=",
		"-",
	}

	for _, element := range expectedElements {
		if !strings.Contains(cliOutput, element) {
			t.Errorf("CLI十六进制输出缺少元素: %s", element)
		}
		if !strings.Contains(uiOutput, element) {
			t.Errorf("UI十六进制输出缺少元素: %s", element)
		}
	}

	// 验证输出结构相似
	cliHasHeader := strings.Contains(cliOutput, "=====")
	uiHasHeader := strings.Contains(uiOutput, "=====")

	if cliHasHeader != uiHasHeader {
		t.Error("CLI和UI十六进制输出头部格式不一致")
	}
}

func TestErrorOutputConsistency(t *testing.T) {
	// 测试错误输出一致性
	testError := ErrorResultWithMessage("文件未找到")

	cliRenderer := Renderer(ModeCLI, &RendererConfig{UseEmoji: true})
	uiRenderer := Renderer(ModeUI, &RendererConfig{UseEmoji: true})

	cliOutput := cliRenderer.RenderResult(testError)
	uiOutput := uiRenderer.RenderResult(testError)

	// 验证错误格式一致
	if !strings.Contains(cliOutput, "❌") {
		t.Error("CLI错误输出缺少错误图标")
	}
	if !strings.Contains(uiOutput, "❌") {
		t.Error("UI错误输出缺少错误图标")
	}

	if !strings.Contains(cliOutput, "文件未找到") {
		t.Error("CLI错误输出缺少错误消息")
	}
	if !strings.Contains(uiOutput, "文件未找到") {
		t.Error("UI错误输出缺少错误消息")
	}
}

func TestProgressOutputConsistency(t *testing.T) {
	// 测试进度输出一致性
	cliRenderer := Renderer(ModeCLI, &RendererConfig{ShowProgress: true})
	uiRenderer := Renderer(ModeUI, &RendererConfig{ShowProgress: true})

	cliProgress := cliRenderer.RenderProgress(0.5, "处理中...")
	uiProgress := uiRenderer.RenderProgress(0.5, "处理中...")

	// UI模式应该有进度条，CLI模式可能是简化显示
	if !strings.Contains(uiProgress, "50%") {
		t.Error("UI进度输出缺少百分比")
	}

	if !strings.Contains(uiProgress, "处理中...") {
		t.Error("UI进度输出缺少状态消息")
	}

	// CLI进度可能是简化的
	if cliProgress != "" && !strings.Contains(cliProgress, "50%") {
		t.Error("CLI进度输出格式不正确")
	}
}

func TestBuilderConsistency(t *testing.T) {
	// 测试结果构建器的一致性
	result1 := EncryptionResult("test.txt", "AES", "/tmp", 512, 200*time.Millisecond)
	result2 := ResultBuilder().
		Type(TypeEncryption).
		Message("加密完成").
		FileName("test.txt").
		Algorithm("AES").
		OutputPath("/tmp").
		FileSize(512).
		ProcessTime(200 * time.Millisecond).
		Build()

	renderer := Renderer(ModeCLI, &RendererConfig{UseEmoji: true})

	output1 := renderer.RenderResult(result1)
	output2 := renderer.RenderResult(result2)

	if output1 != output2 {
		t.Error("使用不同方式构建的相同结果渲染输出不一致")
		t.Logf("便捷方法输出:\n%s", output1)
		t.Logf("构建器输出:\n%s", output2)
	}
}

// 基准测试
func BenchmarkCLIRendering(b *testing.B) {
	result := EncryptionResult("large-file.txt", "RSA", "/encrypted", 1024*1024, 500*time.Millisecond)
	renderer := Renderer(ModeCLI, &RendererConfig{UseEmoji: true})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		renderer.RenderResult(result)
	}
}

func BenchmarkUIRendering(b *testing.B) {
	result := EncryptionResult("large-file.txt", "RSA", "/encrypted", 1024*1024, 500*time.Millisecond)
	renderer := RendererInterface(ModeUI, &RendererConfig{UseEmoji: true})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		renderer.RenderResult(result)
	}
}

func BenchmarkHexOutputRendering(b *testing.B) {
	longHex := strings.Repeat("deadbeef", 1000) // 8000字符的十六进制字符串
	result := HexOutputResult("Long text content", longHex, "AES", 100*time.Millisecond)
	renderer := Renderer(ModeCLI, &RendererConfig{UseEmoji: true})

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		renderer.RenderResult(result)
	}
}
