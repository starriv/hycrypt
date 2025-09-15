package domain

import (
	"context"
	"io"
)

// CryptoOptions 加密配置选项
type CryptoOptions struct {
	Method       string
	OutputFormat OutputFormat
	InputFormat  InputFormat
	Verbose      bool
}

// OutputFormat 输出格式
type OutputFormat int

const (
	OutputFile OutputFormat = iota
	OutputHex
)

// InputFormat 输入格式
type InputFormat int

const (
	InputFile InputFormat = iota
	InputHex
	InputText
)

// CryptoResult 加密/解密结果
type CryptoResult struct {
	Success       bool
	OutputPath    string
	ProcessedSize int64
	Method        string
	ProcessTime   int64
	Error         error
}

// DataSource 数据源接口
type DataSource interface {
	Read(ctx context.Context) (io.ReadCloser, error)
	Size() int64
	Name() string
	Type() string
}

// DataSink 数据输出接口
type DataSink interface {
	Write(ctx context.Context, data io.Reader) error
	Path() string
	Close() error
}

// CryptoProcessor 加密处理器接口
type CryptoProcessor interface {
	Encrypt(ctx context.Context, source DataSource, sink DataSink, opts CryptoOptions) (*CryptoResult, error)
	Decrypt(ctx context.Context, source DataSource, sink DataSink, opts CryptoOptions) (*CryptoResult, error)
	ValidateConfig() error
}

// FileNameStrategy 文件命名策略接口
type FileNameStrategy interface {
	GenerateEncryptedName(originalName, method string) string
	ParseEncryptedName(encryptedName string) (originalName, method, date string, isDirectory bool)
	IsEncryptedFile(fileName string) bool
}
