package constants

import "testing"

func TestAlgorithmConstants(t *testing.T) {
	// 测试算法常量值
	if AlgorithmRSA != "rsa" {
		t.Errorf("Expected AlgorithmRSA to be 'rsa', got %s", AlgorithmRSA)
	}

	if AlgorithmKMAC != "kmac" {
		t.Errorf("Expected AlgorithmKMAC to be 'kmac', got %s", AlgorithmKMAC)
	}
}

func TestSupportedAlgorithms(t *testing.T) {
	// 测试支持的算法列表
	if len(SupportedAlgorithms) != 2 {
		t.Errorf("Expected 2 supported algorithms, got %d", len(SupportedAlgorithms))
	}

	// 检查RSA算法是否在列表中
	found := false
	for _, alg := range SupportedAlgorithms {
		if alg == AlgorithmRSA {
			found = true
			break
		}
	}
	if !found {
		t.Error("RSA algorithm not found in SupportedAlgorithms")
	}

	// 检查KMAC算法是否在列表中
	found = false
	for _, alg := range SupportedAlgorithms {
		if alg == AlgorithmKMAC {
			found = true
			break
		}
	}
	if !found {
		t.Error("KMAC algorithm not found in SupportedAlgorithms")
	}
}

func TestIsValidAlgorithm(t *testing.T) {
	// 测试有效算法检查
	testCases := []struct {
		algorithm string
		expected  bool
	}{
		{AlgorithmRSA, true},
		{AlgorithmKMAC, true},
		{"aes", false},
		{"unknown", false},
		{"", false},
	}

	for _, tc := range testCases {
		result := IsValidAlgorithm(tc.algorithm)
		if result != tc.expected {
			t.Errorf("IsValidAlgorithm(%s) = %v, expected %v", tc.algorithm, result, tc.expected)
		}
	}
}
