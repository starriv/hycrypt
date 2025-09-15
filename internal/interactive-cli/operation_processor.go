package interactivecli

// OperationProcessor 操作处理器
type OperationProcessor struct {
	encryptProcessor *EncryptProcessor
	decryptProcessor *DecryptProcessor
}

// NewOperationProcessor 创建操作处理器
func NewOperationProcessor() *OperationProcessor {
	return &OperationProcessor{
		encryptProcessor: NewEncryptProcessor(),
		decryptProcessor: NewDecryptProcessor(),
	}
}

// ProcessOperation 处理操作
func (p *OperationProcessor) ProcessOperation(m Model) operationResult {
	if m.operation == "encrypt" {
		return p.encryptProcessor.ProcessEncryption(m)
	} else {
		return p.decryptProcessor.ProcessDecryption(m)
	}
}
