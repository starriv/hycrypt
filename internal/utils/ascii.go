package utils

import (
	"fmt"
	"time"

	"github.com/charmbracelet/lipgloss"
)

// 显示 HyCrypt ASCII 动画
func ShowASCIIArt() {
	// 定义颜色样式
	titleColor := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#7D56F4")).
		Bold(true)

	subtitleColor := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888"))

	// HyCrypt ASCII 艺术字
	asciiArt := `
 ██╗  ██╗██╗   ██╗ ██████╗██████╗ ██╗   ██╗██████╗ ████████╗
 ██║  ██║╚██╗ ██╔╝██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝
 ███████║ ╚████╔╝ ██║     ██████╔╝ ╚████╔╝ ██████╔╝   ██║   
 ██╔══██║  ╚██╔╝  ██║     ██╔══██╗  ╚██╔╝  ██╔═══╝    ██║   
 ██║  ██║   ██║   ╚██████╗██║  ██║   ██║   ██║        ██║   
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝        ╚═╝   
`

	// 清屏
	fmt.Print("\033[2J\033[H")

	// 显示 ASCII 艺术字
	fmt.Println(titleColor.Render(asciiArt))

	// 显示副标题
	subtitle := "🔐 混合加密程序 - 支持 RSA & KMAC 算法 🔐"
	fmt.Println(titleColor.Render("                    " + subtitle))
	fmt.Println()

	version := "v0.1.0 - 快速的备份加密解决方案, 支持本地密钥与 KMS 云密钥"
	fmt.Println(subtitleColor.Render("                           " + version))

	// 制作者标题
	author := "💝 Made With Love By Starriv 💝"
	fmt.Println(subtitleColor.Render("                           " + author))
	fmt.Println()

	// 简短的动画效果
	loading := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	for i := 0; i < 10; i++ {
		fmt.Printf("\r                           %s 初始化中...", loading[i%len(loading)])
		time.Sleep(100 * time.Millisecond)
	}

	fmt.Print("\r                           ✅ 初始化完成!     \n\n")

	time.Sleep(600 * time.Millisecond)
}

// 显示简化版标题（用于命令行模式）
func ShowSimpleTitle() {
	titleColor := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#7D56F4")).
		Bold(true)

	subtitleColor := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#888888"))

	fmt.Println(titleColor.Render("🔐 HyCrypt - 混合加密程序"))
	fmt.Println(subtitleColor.Render("💝 Made With Love By Starriv 💝"))
	fmt.Println()
}
