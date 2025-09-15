package datasink

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"hycrypt/internal/domain"
	"hycrypt/internal/errors"
	"io"
	"math/big"
	"os"
	"path/filepath"
	"strings"
)

// FileSinkInterface 文件输出
type FileSinkInterface struct {
	path string
	file *os.File
}

func FileSink(path string) (*FileSinkInterface, error) {
	// 确保目录存在
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create directory: %w", err)
	}

	// 检查文件是否已存在，如果存在则生成唯一文件名
	uniquePath := generateUniqueFilePath(path)

	file, err := os.Create(uniquePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create file: %w", err)
	}

	return &FileSinkInterface{
		path: uniquePath,
		file: file,
	}, nil
}

func (f *FileSinkInterface) Write(ctx context.Context, data io.Reader) error {
	_, err := io.Copy(f.file, data)
	return err
}

func (f *FileSinkInterface) Path() string {
	return f.path
}

func (f *FileSinkInterface) Close() error {
	if f.file != nil {
		return f.file.Close()
	}
	return nil
}

// HexSink 十六进制输出
type HexSink struct {
	output chan string
	result string
}

func CreateHexSink() *HexSink {
	return &HexSink{
		output: make(chan string, 1),
	}
}

func (h *HexSink) Write(ctx context.Context, data io.Reader) error {
	bytes, err := io.ReadAll(data)
	if err != nil {
		return err
	}

	hexString := hex.EncodeToString(bytes)
	h.result = hexString

	// 输出到控制台
	fmt.Printf("🔑 加密结果（十六进制）:\n")
	fmt.Printf("%s", "="+fmt.Sprintf("%*s", 60, "")+"\n")
	fmt.Printf("%s\n", hexString)
	fmt.Printf("%s", "="+fmt.Sprintf("%*s", 60, "")+"\n")

	return nil
}

func (h *HexSink) Path() string {
	return "stdout"
}

func (h *HexSink) Close() error {
	close(h.output)
	return nil
}

func (h *HexSink) GetResult() string {
	return h.result
}

// ConsoleSink 控制台输出（用于解密的文本结果）
type ConsoleSink struct {
	result string
}

func CreateConsoleSink() *ConsoleSink {
	return &ConsoleSink{}
}

func (c *ConsoleSink) Write(ctx context.Context, data io.Reader) error {
	bytes, err := io.ReadAll(data)
	if err != nil {
		return err
	}

	text := string(bytes)
	c.result = text

	// 输出到控制台
	fmt.Printf("🔓 解密结果（文本内容）:\n")
	fmt.Printf("%s", "="+fmt.Sprintf("%*s", 60, "")+"\n")
	fmt.Printf("%s\n", text)
	fmt.Printf("%s", "="+fmt.Sprintf("%*s", 60, "")+"\n")

	return nil
}

func (c *ConsoleSink) Path() string {
	return "stdout"
}

func (c *ConsoleSink) Close() error {
	return nil
}

func (c *ConsoleSink) GetResult() string {
	return c.result
}

// CreateSink 根据输出类型创建数据输出
func CreateSink(outputPath string, outputType domain.OutputFormat) (domain.DataSink, error) {
	switch outputType {
	case domain.OutputFile:
		return FileSink(outputPath)
	case domain.OutputHex:
		return CreateHexSink(), nil
	default:
		return nil, errors.InvalidFormat("output", fmt.Errorf("unsupported output type: %v", outputType))
	}
}

// generateUniqueFilePath 生成唯一的文件路径，如果文件已存在则添加随机后缀
func generateUniqueFilePath(originalPath string) string {
	// 检查文件是否存在
	if _, err := os.Stat(originalPath); os.IsNotExist(err) {
		// 文件不存在，直接返回原路径
		return originalPath
	}

	// 文件存在，需要生成唯一名称
	dir := filepath.Dir(originalPath)
	filename := filepath.Base(originalPath)

	// 分离文件名和扩展名
	ext := filepath.Ext(filename)
	nameWithoutExt := strings.TrimSuffix(filename, ext)

	// 生成6位随机数
	randomSuffix := generateRandomString(6)

	// 构造新的文件名：原名-随机数.扩展名
	newFilename := fmt.Sprintf("%s-%s%s", nameWithoutExt, randomSuffix, ext)
	newPath := filepath.Join(dir, newFilename)

	// 递归检查新路径是否也存在冲突（虽然概率很低）
	return generateUniqueFilePath(newPath)
}

// generateRandomString 生成指定长度的随机字符串
func generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
	result := make([]byte, length)
	for i := range result {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		result[i] = charset[num.Int64()]
	}
	return string(result)
}
