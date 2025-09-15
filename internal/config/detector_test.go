package config

import (
	"testing"

	"hycrypt/internal/constants"
)

func TestStandardAlgorithmDetector(t *testing.T) {
	// 创建支持 RSA 和 KMAC 的检测器
	detector := CreateStandardDetector(constants.SupportedAlgorithms, ".encrypted")

	tests := []struct {
		name     string
		filePath string
		expected string
	}{
		{
			name:     "RSA encrypted file",
			filePath: "document-abcdef-20250915-rsa.encrypted",
			expected: constants.AlgorithmRSA,
		},
		{
			name:     "KMAC encrypted file",
			filePath: "untitledfolder-htboda-20250915-kmac.zip.encrypted",
			expected: constants.AlgorithmKMAC,
		},
		{
			name:     "RSA directory archive",
			filePath: "mydirectory-defghi-20250915-rsa.zip.encrypted",
			expected: constants.AlgorithmRSA,
		},
		{
			name:     "Invalid format",
			filePath: "document.txt",
			expected: "",
		},
		{
			name:     "Old format (should not match)",
			filePath: "document-rsa.encrypted",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := detector.DetectFromPath(tt.filePath)
			if result != tt.expected {
				t.Errorf("DetectFromPath(%s) = %s, expected %s", tt.filePath, result, tt.expected)
			}
		})
	}
}

func TestAlgorithmDetectorSupport(t *testing.T) {
	// 测试只支持 RSA 的检测器
	rsaOnlyDetector := CreateStandardDetector([]string{constants.AlgorithmRSA}, ".encrypted")

	// 应该支持 RSA
	if !rsaOnlyDetector.IsSupported(constants.AlgorithmRSA) {
		t.Error("Expected RSA to be supported")
	}

	// 不应该支持 KMAC
	if rsaOnlyDetector.IsSupported(constants.AlgorithmKMAC) {
		t.Error("Expected KMAC not to be supported")
	}

	// 检测 KMAC 文件时应该返回空字符串
	result := rsaOnlyDetector.DetectFromPath("file-abc123-20250915-kmac.encrypted")
	if result != "" {
		t.Errorf("Expected empty result for unsupported algorithm, got %s", result)
	}
}

func TestConfigAlgorithmDetection(t *testing.T) {
	config := Default()

	// 测试默认配置支持的算法
	supportedAlgs := config.GetSupportedAlgorithms()
	expectedAlgs := constants.SupportedAlgorithms

	if len(supportedAlgs) != len(expectedAlgs) {
		t.Errorf("Expected %d supported algorithms, got %d", len(expectedAlgs), len(supportedAlgs))
	}

	for _, alg := range expectedAlgs {
		if !config.IsAlgorithmSupported(alg) {
			t.Errorf("Expected algorithm %s to be supported", alg)
		}
	}

	// 测试算法检测
	testFile := "test-abcdef-20250915-rsa.encrypted"
	detected := config.DetectAlgorithmFromPath(testFile)
	if detected != constants.AlgorithmRSA {
		t.Errorf("Expected to detect 'rsa', got '%s'", detected)
	}
}

func TestExtensibleAlgorithmDetection(t *testing.T) {
	// 测试支持未来新算法的可扩展性
	futureDetector := CreateStandardDetector(
		[]string{constants.AlgorithmRSA, constants.AlgorithmKMAC, "aes", "chacha20"},
		".encrypted",
	)

	tests := []struct {
		filePath string
		expected string
	}{
		{"file-abcdef-20250915-aes.encrypted", "aes"},
		{"file-defghi-20250915-chacha20.zip.encrypted", "chacha20"},
		{"file-ghijkl-20250915-unknown.encrypted", ""}, // 不支持的算法
	}

	for _, tt := range tests {
		result := futureDetector.DetectFromPath(tt.filePath)
		if result != tt.expected {
			t.Errorf("DetectFromPath(%s) = %s, expected %s", tt.filePath, result, tt.expected)
		}
	}
}
