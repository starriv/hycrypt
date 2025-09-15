package crypto

import (
	"context"
	"io"
)

// CryptoService 加密服务接口
type CryptoService interface {
	EncryptData(ctx context.Context, data io.Reader) (io.Reader, error)
	DecryptData(ctx context.Context, data io.Reader) (io.Reader, error)
	ValidateKeys() error
}

// BaseService 基础服务
type BaseService struct {
	config interface{}
}
