package output

import (
	"fmt"
	"io"
	"os"
	"sync"
)

// OutputManagerInterface 输出管理器
type OutputManagerInterface struct {
	renderer RendererInterface
	writer   io.Writer
	mutex    sync.RWMutex

	// 配置
	immediate bool // 是否立即输出
	buffered  bool // 是否缓冲输出
	buffer    []string
}

// OutputManager 创建输出管理器
func OutputManager(mode OutputMode, config *RendererConfig) *OutputManagerInterface {
	renderer := Renderer(mode, config)

	return &OutputManagerInterface{
		renderer:  renderer,
		writer:    os.Stdout,
		immediate: true,
		buffered:  false,
		buffer:    make([]string, 0),
	}
}

// BufferedOutputManager 创建缓冲输出管理器
func BufferedOutputManager(mode OutputMode, config *RendererConfig) *OutputManagerInterface {
	renderer := Renderer(mode, config)

	return &OutputManagerInterface{
		renderer:  renderer,
		writer:    os.Stdout,
		immediate: false,
		buffered:  true,
		buffer:    make([]string, 0),
	}
}

// PrintResult 输出操作结果
func (m *OutputManagerInterface) PrintResult(result *OperationResult) {
	content := m.renderer.RenderResult(result)
	m.write(content)
}

// 内部方法
func (m *OutputManagerInterface) write(content string) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	if m.buffered {
		m.buffer = append(m.buffer, content)
		if !m.immediate {
			return
		}
	}

	fmt.Fprint(m.writer, content)
}
