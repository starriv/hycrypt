package main

import (
	"context"
	"flag"
	"fmt"
	"hycrypt/internal/app"
	"hycrypt/internal/config"
	"hycrypt/internal/errors"
	"hycrypt/internal/utils"
	"os"
)

func main() {
	// 解析命令行参数
	opts := parseFlags()

	// 处理帮助和配置生成
	if opts.ShowHelp {
		showUsage()
		return
	}

	if opts.GenerateConfig {
		if err := generateDefaultConfig(opts.ConfigPath); err != nil {
			fmt.Fprintf(os.Stderr, "❌ %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("✅ 配置文件已生成: %s\n", opts.ConfigPath)
		return
	}

	// 加载配置（使用优先级逻辑）
	cfg, err := config.LoadConfigWithPriority(opts.ConfigPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ %v\n", err)
		os.Exit(1)
	}

	// 应用命令行覆盖
	cfg.ApplyOverrides(opts)

	// 显示ASCII艺术
	if !opts.NoArt {
		showASCII(opts.Interactive)
	}

	// 创建应用程序
	application, err := app.CreateApp(cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()

	// 运行应用程序
	if opts.Interactive {
		err = application.RunInteractive(ctx)
	} else {
		// 转换为app.Options
		appOpts := &app.Options{
			FilePath:     opts.FilePath,
			TextMode:     opts.TextMode,
			OutputDir:    opts.OutputDir,
			OutputFormat: opts.OutputFormat,
			InputFormat:  opts.InputFormat,
			Method:       opts.Method,
			Decrypt:      opts.Decrypt,
			Verbose:      opts.Verbose,
		}
		err = application.RunCLI(ctx, appOpts)
	}

	if err != nil {
		if cryptoErr, ok := err.(*errors.CryptoErrorInterface); ok {
			fmt.Fprintf(os.Stderr, "❌ %v\n", cryptoErr)
		} else {
			fmt.Fprintf(os.Stderr, "❌ %v\n", err)
		}
		os.Exit(1)
	}
}

type Options struct {
	ConfigPath     string
	FilePath       string
	TextMode       bool
	OutputDir      string
	OutputFormat   string
	InputFormat    string
	KeyDir         string
	Method         string
	Decrypt        bool
	Verbose        bool
	GenerateConfig bool
	ShowHelp       bool
	NoArt          bool
	Interactive    bool
}

// GetKeyDir implements config.CLIOptions interface
func (o *Options) GetKeyDir() string {
	return o.KeyDir
}

// GetMethod implements config.CLIOptions interface
func (o *Options) GetMethod() string {
	return o.Method
}

// GetVerbose implements config.CLIOptions interface
func (o *Options) GetVerbose() bool {
	return o.Verbose
}

func parseFlags() *Options {
	opts := &Options{}

	flag.StringVar(&opts.ConfigPath, "config", "config.yaml", "配置文件路径")
	flag.StringVar(&opts.FilePath, "f", "", "要处理的文件或文件夹路径")
	flag.BoolVar(&opts.TextMode, "t", false, "文本输入模式")
	flag.StringVar(&opts.OutputDir, "output", "", "输出目录")
	flag.StringVar(&opts.OutputFormat, "output-format", "file", "输出格式: file 或 hex")
	flag.StringVar(&opts.InputFormat, "input-format", "file", "输入格式: file 或 hex")
	flag.StringVar(&opts.KeyDir, "key-dir", "", "密钥文件夹路径")
	flag.StringVar(&opts.Method, "method", "", "加密方法: rsa 或 kmac")
	methodShort := flag.String("m", "", "加密方法（简写）")
	flag.BoolVar(&opts.Decrypt, "d", false, "解密模式")
	flag.BoolVar(&opts.Verbose, "verbose", false, "详细输出模式")
	flag.BoolVar(&opts.GenerateConfig, "gen-config", false, "生成默认配置文件")
	flag.BoolVar(&opts.ShowHelp, "help", false, "显示帮助信息")
	flag.BoolVar(&opts.NoArt, "no-art", false, "跳过ASCII动画")

	flag.Parse()

	// 处理方法简写
	if *methodShort != "" {
		opts.Method = *methodShort
	}

	// 判断是否为交互模式
	opts.Interactive = !opts.GenerateConfig && opts.FilePath == "" && !opts.TextMode && !opts.Decrypt

	return opts
}

func showUsage() {
	fmt.Fprintf(os.Stderr, "用法: %s [选项]\n\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "HyCrypt - 混合加密程序，支持 RSA & KMAC 算法\n\n")
	fmt.Fprintf(os.Stderr, "选项:\n")
	flag.PrintDefaults()

	examples := []string{
		"\n配置管理:",
		"  hycrypt -gen-config                    # 生成默认配置文件",
		"  hycrypt -config=custom.yaml -f=file   # 使用自定义配置",
		"\n文件加密:",
		"  hycrypt -f=myfile.txt                 # RSA 加密文件",
		"  hycrypt -m=kmac -f=myfile.txt         # KMAC 加密文件",
		"  hycrypt -f=myfolder                   # 加密文件夹",
		"\n文本加密:",
		"  echo \"secret\" | hycrypt -t           # 文本加密",
		"  hycrypt -t --output-format=hex        # 输出十六进制",
		"\n解密:",
		"  hycrypt -d -f=file.encrypted          # 解密文件",
		"  echo \"hex...\" | hycrypt -d -t --input-format=hex  # 十六进制解密",
	}

	for _, example := range examples {
		fmt.Fprintf(os.Stderr, "%s\n", example)
	}
}

func generateDefaultConfig(path string) error {
	cfg := config.Default()
	return config.Save(cfg, path)
}

func showASCII(interactive bool) {
	if interactive {
		showFullASCII()
	} else {
		showSimpleTitle()
	}
}

func showFullASCII() {
	// 显示完整的ASCII动画
	utils.ShowASCIIArt()
}

func showSimpleTitle() {
	// 显示简化标题
	utils.ShowSimpleTitle()
}
