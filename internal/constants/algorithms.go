package constants

// Algorithm constants - 算法常量
const (
	// AlgorithmRSA RSA 算法标识
	AlgorithmRSA = "rsa"

	// AlgorithmKMAC KMAC 算法标识
	AlgorithmKMAC = "kmac"
)

// SupportedAlgorithms 支持的算法列表
var SupportedAlgorithms = []string{
	AlgorithmRSA,
	AlgorithmKMAC,
}

// IsValidAlgorithm 检查算法是否有效
func IsValidAlgorithm(algorithm string) bool {
	for _, supported := range SupportedAlgorithms {
		if algorithm == supported {
			return true
		}
	}
	return false
}
