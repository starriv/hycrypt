package datasource

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"hycrypt/internal/domain"
	"hycrypt/internal/errors"
	"hycrypt/internal/utils"
)

// FileSourceInterface 文件数据源
type FileSourceInterface struct {
	path string
	size int64
}

func FileSource(path string) (*FileSourceInterface, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, errors.FileNotFound(path)
	}

	return &FileSourceInterface{
		path: path,
		size: info.Size(),
	}, nil
}

func (f *FileSourceInterface) Read(ctx context.Context) (io.ReadCloser, error) {
	file, err := os.Open(f.path)
	if err != nil {
		return nil, errors.FileNotFound(f.path)
	}
	return file, nil
}

func (f *FileSourceInterface) Size() int64 {
	return f.size
}

func (f *FileSourceInterface) Name() string {
	return f.path
}

func (f *FileSourceInterface) Type() string {
	return "file"
}

// DirectorySource 目录数据源（通过zip压缩）
type DirectorySource struct {
	dirPath     string
	tempZipPath string
	size        int64
}

func CreateDirectorySource(dirPath string) (*DirectorySource, error) {
	// 检查目录是否存在
	info, err := os.Stat(dirPath)
	if err != nil {
		return nil, errors.FileNotFound(dirPath)
	}

	if !info.IsDir() {
		return nil, errors.InvalidFormat("path", fmt.Errorf("path is not a directory: %s", dirPath))
	}

	// 创建临时zip文件
	tempZipPath, err := utils.CreateTempZipFile(dirPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create temp zip for directory: %w", err)
	}

	// 获取zip文件大小
	zipInfo, err := os.Stat(tempZipPath)
	if err != nil {
		os.Remove(tempZipPath) // 清理临时文件
		return nil, fmt.Errorf("failed to get zip file info: %w", err)
	}

	return &DirectorySource{
		dirPath:     dirPath,
		tempZipPath: tempZipPath,
		size:        zipInfo.Size(),
	}, nil
}

func (d *DirectorySource) Read(ctx context.Context) (io.ReadCloser, error) {
	file, err := os.Open(d.tempZipPath)
	if err != nil {
		return nil, errors.FileNotFound(d.tempZipPath)
	}

	// 返回一个包装器，在关闭时清理临时文件
	return &cleanupReader{
		ReadCloser: file,
		cleanup: func() {
			os.Remove(d.tempZipPath)
		},
	}, nil
}

func (d *DirectorySource) Size() int64 {
	return d.size
}

func (d *DirectorySource) Name() string {
	return d.dirPath
}

func (d *DirectorySource) Type() string {
	return "directory"
}

// cleanupReader 带清理功能的读取器
type cleanupReader struct {
	io.ReadCloser
	cleanup func()
}

func (c *cleanupReader) Close() error {
	err := c.ReadCloser.Close()
	if c.cleanup != nil {
		c.cleanup()
	}
	return err
}

// TextSourceInterface 文本数据源
type TextSourceInterface struct {
	data []byte
	name string
}

func TextSource(data []byte, name string) *TextSourceInterface {
	return &TextSourceInterface{
		data: data,
		name: name,
	}
}

func (t *TextSourceInterface) Read(ctx context.Context) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader(string(t.data))), nil
}

func (t *TextSourceInterface) Size() int64 {
	return int64(len(t.data))
}

func (t *TextSourceInterface) Name() string {
	return t.name
}

func (t *TextSourceInterface) Type() string {
	return "text"
}

// HexSource 十六进制数据源
type HexSource struct {
	data []byte
	name string
}

func CreateHexSource(hexData string, name string) (*HexSource, error) {
	// 清理十六进制输入
	cleaned := cleanHexInput(hexData)

	if len(cleaned)%2 != 0 {
		return nil, errors.InvalidFormat("hex", fmt.Errorf("odd length hex string"))
	}

	data := make([]byte, len(cleaned)/2)
	for i := 0; i < len(cleaned); i += 2 {
		var b byte
		if _, err := fmt.Sscanf(cleaned[i:i+2], "%02x", &b); err != nil {
			return nil, errors.InvalidFormat("hex", err)
		}
		data[i/2] = b
	}

	return &HexSource{
		data: data,
		name: name,
	}, nil
}

func (h *HexSource) Read(ctx context.Context) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader(string(h.data))), nil
}

func (h *HexSource) Size() int64 {
	return int64(len(h.data))
}

func (h *HexSource) Name() string {
	return h.name
}

func (h *HexSource) Type() string {
	return "hex"
}

// cleanHexInput 清理十六进制输入
func cleanHexInput(input string) string {
	cleaned := strings.ReplaceAll(input, " ", "")
	cleaned = strings.ReplaceAll(cleaned, "\n", "")
	cleaned = strings.ReplaceAll(cleaned, "\r", "")
	cleaned = strings.ReplaceAll(cleaned, "\t", "")
	cleaned = strings.ReplaceAll(cleaned, "=", "")
	return strings.ToLower(cleaned)
}

// CreateSource 根据输入类型创建数据源
func CreateSource(input string, inputType domain.InputFormat) (domain.DataSource, error) {
	switch inputType {
	case domain.InputFile:
		// 检查是文件还是目录
		info, err := os.Stat(input)
		if err != nil {
			return nil, errors.FileNotFound(input)
		}

		if info.IsDir() {
			return CreateDirectorySource(input)
		} else {
			return FileSource(input)
		}
	case domain.InputText:
		return TextSource([]byte(input), "text-input"), nil
	case domain.InputHex:
		return CreateHexSource(input, "hex-input")
	default:
		return nil, errors.InvalidFormat("input", fmt.Errorf("unsupported input type: %v", inputType))
	}
}
