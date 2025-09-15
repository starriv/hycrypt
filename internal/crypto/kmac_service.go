package crypto

import (
	"context"
	"crypto/rand"
	"hycrypt/internal/constants"
	"hycrypt/internal/errors"
	"io"
	"strings"

	"golang.org/x/crypto/sha3"
)

// KMACServiceInterface KMAC加密服务
type KMACServiceInterface struct {
	*BaseService
	config *KMACConfig
}

func KMACService(config *KMACConfig) (*KMACServiceInterface, error) {
	service := &KMACServiceInterface{
		BaseService: &BaseService{config: config},
		config:      config,
	}

	if len(config.Key) != config.KeySize {
		return nil, errors.InvalidConfig("KMAC key length mismatch", nil)
	}

	return service, nil
}

func (k *KMACServiceInterface) EncryptData(ctx context.Context, data io.Reader) (io.Reader, error) {
	plaintext, err := io.ReadAll(data)
	if err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmKMAC, err)
	}

	// 生成随机salt
	salt := make([]byte, 16)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmKMAC, err)
	}

	// 派生AES密钥
	aesKey := k.deriveKey(salt, k.config.AESKeySize)
	defer k.clearKey(aesKey)

	// AES加密
	ciphertext, err := encryptAESGCM(aesKey, plaintext)
	if err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmKMAC, err)
	}

	// 组合结果: [salt][ciphertext]
	result := make([]byte, 16+len(ciphertext))
	copy(result[:16], salt)
	copy(result[16:], ciphertext)

	return strings.NewReader(string(result)), nil
}

func (k *KMACServiceInterface) DecryptData(ctx context.Context, data io.Reader) (io.Reader, error) {
	ciphertext, err := io.ReadAll(data)
	if err != nil {
		return nil, errors.DecryptionFailed(constants.AlgorithmKMAC, err)
	}

	if len(ciphertext) < 16 {
		return nil, errors.InvalidFormat("kmac encrypted data", err)
	}

	// 提取salt和数据
	salt := ciphertext[:16]
	encryptedData := ciphertext[16:]

	// 派生相同的AES密钥
	aesKey := k.deriveKey(salt, k.config.AESKeySize)
	defer k.clearKey(aesKey)

	// AES解密
	plaintext, err := decryptAESGCM(aesKey, encryptedData)
	if err != nil {
		return nil, errors.DecryptionFailed(constants.AlgorithmKMAC, err)
	}

	return strings.NewReader(string(plaintext)), nil
}

func (k *KMACServiceInterface) ValidateKeys() error {
	if len(k.config.Key) == 0 {
		return errors.KeyNotFound(constants.AlgorithmKMAC, "config")
	}
	return nil
}

func (k *KMACServiceInterface) deriveKey(salt []byte, keyLength int) []byte {
	// 使用SHAKE256作为KMAC的实现
	h := sha3.NewShake256()
	h.Write(k.config.Key)
	h.Write(salt)
	h.Write([]byte("KMAC-AES-KEY-DERIVATION"))

	key := make([]byte, keyLength)
	h.Read(key)
	return key
}

func (k *KMACServiceInterface) clearKey(key []byte) {
	for i := range key {
		key[i] = 0
	}
}
