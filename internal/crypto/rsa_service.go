package crypto

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/binary"
	"encoding/pem"
	"fmt"
	"hycrypt/internal/constants"
	"hycrypt/internal/errors"
	"io"
	"os"
	"strings"
)

// RSAServiceInterface RSA加密服务
type RSAServiceInterface struct {
	*BaseService
	publicKey  *rsa.PublicKey
	privateKey *rsa.PrivateKey
	config     *RSAConfig
}

func RSAService(config *RSAConfig) (*RSAServiceInterface, error) {
	service := &RSAServiceInterface{
		BaseService: &BaseService{config: config},
		config:      config,
	}

	// 加载公钥
	if err := service.loadPublicKey(); err != nil {
		return nil, err
	}

	// 尝试加载私钥（解密需要）
	service.loadPrivateKey() // 忽略错误，私钥可选

	return service, nil
}

func (r *RSAServiceInterface) EncryptData(ctx context.Context, data io.Reader) (io.Reader, error) {
	plaintext, err := io.ReadAll(data)
	if err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmRSA, err)
	}

	// 尝试直接RSA加密
	ciphertext, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, r.publicKey, plaintext, nil)
	if err != nil {
		// 数据太大，使用混合加密
		return r.encryptLargeData(plaintext)
	}

	return strings.NewReader(string(ciphertext)), nil
}

func (r *RSAServiceInterface) DecryptData(ctx context.Context, data io.Reader) (io.Reader, error) {
	if r.privateKey == nil {
		return nil, errors.KeyNotFound("private", r.config.PrivateKeyPath)
	}

	ciphertext, err := io.ReadAll(data)
	if err != nil {
		return nil, errors.DecryptionFailed(constants.AlgorithmRSA, err)
	}

	var plaintext []byte

	// 检查是否是混合加密
	if r.isHybridEncrypted(ciphertext) {
		plaintext, err = r.decryptHybridData(ciphertext)
	} else {
		plaintext, err = rsa.DecryptOAEP(sha256.New(), rand.Reader, r.privateKey, ciphertext, nil)
	}

	if err != nil {
		return nil, errors.DecryptionFailed(constants.AlgorithmRSA, err)
	}

	return strings.NewReader(string(plaintext)), nil
}

func (r *RSAServiceInterface) ValidateKeys() error {
	if r.publicKey == nil {
		return errors.KeyNotFound("public", r.config.PublicKeyPath)
	}
	return nil
}

func (r *RSAServiceInterface) loadPublicKey() error {
	keyData, err := os.ReadFile(r.config.PublicKeyPath)
	if err != nil {
		return errors.KeyNotFound("public", r.config.PublicKeyPath)
	}

	block, _ := pem.Decode(keyData)
	if block == nil {
		return errors.InvalidFormat("pem", fmt.Errorf("invalid PEM format"))
	}

	publicKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return errors.InvalidFormat("public key", err)
	}

	rsaPublicKey, ok := publicKey.(*rsa.PublicKey)
	if !ok {
		return errors.InvalidFormat("public key", fmt.Errorf("not an RSA public key"))
	}

	r.publicKey = rsaPublicKey
	return nil
}

func (r *RSAServiceInterface) loadPrivateKey() error {
	keyData, err := os.ReadFile(r.config.PrivateKeyPath)
	if err != nil {
		return errors.KeyNotFound("private", r.config.PrivateKeyPath)
	}

	block, _ := pem.Decode(keyData)
	if block == nil {
		return errors.InvalidFormat("pem", fmt.Errorf("invalid PEM format"))
	}

	privateKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		// 尝试PKCS8格式
		key, err2 := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err2 != nil {
			return errors.InvalidFormat("private key", err)
		}

		rsaPrivateKey, ok := key.(*rsa.PrivateKey)
		if !ok {
			return errors.InvalidFormat("private key", fmt.Errorf("not an RSA private key"))
		}
		privateKey = rsaPrivateKey
	}

	r.privateKey = privateKey
	return nil
}

func (r *RSAServiceInterface) encryptLargeData(plaintext []byte) (io.Reader, error) {
	// 生成AES密钥
	aesKey := make([]byte, r.config.AESKeySize)
	if _, err := io.ReadFull(rand.Reader, aesKey); err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmRSA, err)
	}

	// RSA加密AES密钥
	encryptedKey, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, r.publicKey, aesKey, nil)
	if err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmRSA, err)
	}

	// AES加密数据
	ciphertext, err := encryptAESGCM(aesKey, plaintext)
	if err != nil {
		return nil, errors.EncryptionFailed(constants.AlgorithmRSA, err)
	}

	// 组合结果
	result := make([]byte, 4+len(encryptedKey)+len(ciphertext))
	binary.BigEndian.PutUint32(result[0:4], uint32(len(encryptedKey)))
	copy(result[4:4+len(encryptedKey)], encryptedKey)
	copy(result[4+len(encryptedKey):], ciphertext)

	// 清除内存中的密钥
	for i := range aesKey {
		aesKey[i] = 0
	}

	return strings.NewReader(string(result)), nil
}

func (r *RSAServiceInterface) decryptHybridData(encryptedData []byte) ([]byte, error) {
	if len(encryptedData) < 4 {
		return nil, errors.InvalidFormat("hybrid encrypted data", fmt.Errorf("data too short"))
	}

	// 读取密钥长度
	keyLen := binary.BigEndian.Uint32(encryptedData[0:4])
	if keyLen == 0 || keyLen >= uint32(len(encryptedData)) {
		return nil, errors.InvalidFormat("hybrid encrypted data", fmt.Errorf("invalid key length"))
	}

	// 提取加密的AES密钥和数据
	encryptedKey := encryptedData[4 : 4+keyLen]
	encryptedContent := encryptedData[4+keyLen:]

	// RSA解密AES密钥
	aesKey, err := rsa.DecryptOAEP(sha256.New(), rand.Reader, r.privateKey, encryptedKey, nil)
	if err != nil {
		return nil, errors.DecryptionFailed(constants.AlgorithmRSA, err)
	}
	defer func() {
		for i := range aesKey {
			aesKey[i] = 0
		}
	}()

	// AES解密数据
	return decryptAESGCM(aesKey, encryptedContent)
}

func (r *RSAServiceInterface) isHybridEncrypted(data []byte) bool {
	if len(data) <= 4 {
		return false
	}

	keyLen := binary.BigEndian.Uint32(data[0:4])
	return keyLen > 0 && keyLen < uint32(len(data)) && keyLen <= 1024
}
