package errors

import (
	"fmt"
	"strings"
)

// ErrorCode 错误代码
type ErrorCode string

const (
	ErrInvalidConfig    ErrorCode = "INVALID_CONFIG"
	ErrKeyNotFound      ErrorCode = "KEY_NOT_FOUND"
	ErrEncryptionFailed ErrorCode = "ENCRYPTION_FAILED"
	ErrDecryptionFailed ErrorCode = "DECRYPTION_FAILED"
	ErrFileNotFound     ErrorCode = "FILE_NOT_FOUND"
	ErrInvalidFormat    ErrorCode = "INVALID_FORMAT"
	ErrPermissionDenied ErrorCode = "PERMISSION_DENIED"
	ErrInvalidInput     ErrorCode = "INVALID_INPUT"
)

// CryptoErrorInterface 加密相关错误
type CryptoErrorInterface struct {
	Code    ErrorCode
	Message string
	Cause   error
	Context map[string]interface{}
}

func (e *CryptoErrorInterface) Error() string {
	var parts []string
	parts = append(parts, fmt.Sprintf("[%s] %s", e.Code, e.Message))

	if e.Cause != nil {
		parts = append(parts, fmt.Sprintf("caused by: %v", e.Cause))
	}

	if len(e.Context) > 0 {
		var contextParts []string
		for k, v := range e.Context {
			contextParts = append(contextParts, fmt.Sprintf("%s=%v", k, v))
		}
		parts = append(parts, fmt.Sprintf("context: {%s}", strings.Join(contextParts, ", ")))
	}

	return strings.Join(parts, " ")
}

func (e *CryptoErrorInterface) Unwrap() error {
	return e.Cause
}

// NewCryptoError 创建新的加密错误
func CryptoError(code ErrorCode, message string, cause error) *CryptoErrorInterface {
	return &CryptoErrorInterface{
		Code:    code,
		Message: message,
		Cause:   cause,
		Context: make(map[string]interface{}),
	}
}

// WithContext 添加上下文信息
func (e *CryptoErrorInterface) WithContext(key string, value interface{}) *CryptoErrorInterface {
	if e.Context == nil {
		e.Context = make(map[string]interface{})
	}
	e.Context[key] = value
	return e
}

// 便捷的错误创建函数
func InvalidConfig(message string, cause error) *CryptoErrorInterface {
	return CryptoError(ErrInvalidConfig, message, cause)
}

func KeyNotFound(keyType string, path string) *CryptoErrorInterface {
	return CryptoError(ErrKeyNotFound, fmt.Sprintf("%s key not found", keyType), nil).
		WithContext("keyType", keyType).
		WithContext("path", path)
}

func EncryptionFailed(method string, cause error) *CryptoErrorInterface {
	return CryptoError(ErrEncryptionFailed, fmt.Sprintf("encryption with %s failed", method), cause).
		WithContext("method", method)
}

func DecryptionFailed(method string, cause error) *CryptoErrorInterface {
	return CryptoError(ErrDecryptionFailed, fmt.Sprintf("decryption with %s failed", method), cause).
		WithContext("method", method)
}

func FileNotFound(path string) *CryptoErrorInterface {
	return CryptoError(ErrFileNotFound, "file not found", nil).
		WithContext("path", path)
}

func InvalidFormat(format string, cause error) *CryptoErrorInterface {
	return CryptoError(ErrInvalidFormat, fmt.Sprintf("invalid %s format", format), cause).
		WithContext("format", format)
}
