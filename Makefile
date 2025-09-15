.PHONY: build test clean install keys kmac-key demo config help demo-basic demo-text demo-full

# 默认目标
all: build

# 构建程序
build:
	@echo "🔨 构建 HyCrypt..."
	go build -o hycrypt .
	@echo "✅ 构建完成: hycrypt"

# 运行测试
test:
	@echo "🧪 运行测试..."
	go test -v ./...

# 生成 RSA 密钥对
keys:
	@echo "🔑 生成 RSA-4096 密钥对..."
	@mkdir -p keys
	openssl genrsa -out keys/private.pem 4096
	openssl rsa -in keys/private.pem -pubout -out keys/public.pem
	@chmod 600 keys/private.pem
	@echo "✅ RSA 密钥生成完成:"
	@echo "  - 公钥: keys/public.pem"
	@echo "  - 私钥: keys/private.pem"

# 生成 KMAC 密钥
kmac-key:
	@echo "🔑 生成 KMAC 密钥..."
	@mkdir -p keys
	@KMAC_KEY=$$(openssl rand -hex 32); \
	echo "$$KMAC_KEY" > keys/kmac.key; \
	echo "✅ KMAC 密钥生成完成:"; \
	echo "  - 密钥文件: keys/kmac.key"; \
	echo "  - 密钥内容: $$KMAC_KEY"; \
	echo "💡 密钥已保存到文件，可直接使用"

# 生成配置文件
config:
	@echo "⚙️  生成默认配置文件..."
	./hycrypt -gen-config
	@echo "✅ 配置文件生成完成: config.yaml"
	@echo "💡 您可以编辑 config.yaml 来自定义程序行为"

# 安装程序到系统路径
install: build
	@echo "📦 安装 HyCrypt..."
	sudo cp hycrypt /usr/local/bin/
	@echo "✅ 安装完成，现在可以在任何地方使用 hycrypt 命令"

# 基础演示
demo-basic: build
	@echo "🎭 运行基础演示..."
	@cd demo && ./basic_demo.sh

# 文本演示  
demo-text: build
	@echo "📝 运行文本演示..."
	@cd demo && ./text_demo.sh

# 完整演示
demo-full: build keys kmac-key
	@echo "🚀 运行完整演示..."
	@echo "🔑 密钥已准备完成"
	@echo "📁 开始文件加密演示..."
	@echo "这是一个演示文件\\n包含中文和特殊字符：!@#$$%^&*()" > demo_temp.txt
	@echo "\\n📄 原文件内容:"
	@cat demo_temp.txt
	@echo "\\n🔒 RSA 加密..."
	./hycrypt -f=demo_temp.txt -key-dir=keys -output=demo_encrypted -no-art
	@echo "\\n🔒 KMAC 加密演示文件..."
	./hycrypt -m=kmac -f=demo/sample.txt -key-dir=keys -output=demo_encrypted -no-art
	@echo "\\n📁 加密文件列表:"
	@ls -la demo_encrypted/
	@echo "\\n🔓 解密所有文件..."
	@for file in demo_encrypted/*.hycrypt; do \\
		echo "解密: $$(basename $$file)"; \\
		./hycrypt -d -f="$$file" -key-dir=keys -output=demo_decrypted -no-art; \\
	done
	@echo "\\n📁 解密文件列表:"
	@ls -la demo_decrypted/
	@echo "\\n📝 文本加密演示..."
	@echo "Secret message for demo" | ./hycrypt -t -key-dir=keys -output=demo_encrypted -no-art
	@echo "\\n🎉 完整演示完成！"
	@rm -f demo_temp.txt

# 快速演示（默认）
demo: demo-basic

# 清理生成的文件
clean:
	@echo "🧹 清理文件..."
	rm -f hycrypt
	rm -rf encrypted/ decrypted/ demo_encrypted/ demo_decrypted/
	rm -f demo.txt demo_temp.txt test.txt *.encrypted *.hycrypt
	rm -f config.yaml
	@echo "✅ 清理完成"

# 显示帮助信息
help:
	@echo "HyCrypt Makefile - 可用的命令："
	@echo ""
	@echo "🔨 构建相关："
	@echo "  build       - 构建程序"
	@echo "  test        - 运行测试"
	@echo "  install     - 安装程序到系统路径"
	@echo "  clean       - 清理生成的文件"
	@echo ""
	@echo "🔑 密钥管理："
	@echo "  keys        - 生成 RSA-4096 密钥对"
	@echo "  kmac-key    - 生成 KMAC 密钥"
	@echo "  config      - 生成默认配置文件"
	@echo ""
	@echo "🎭 演示功能："
	@echo "  demo        - 运行基础演示（快速）"
	@echo "  demo-basic  - 运行基础文件加密演示"
	@echo "  demo-text   - 运行文本加密演示"
	@echo "  demo-full   - 运行完整功能演示"
	@echo ""
	@echo "ℹ️  其他："
	@echo "  help        - 显示此帮助信息"
	@echo "  all         - 默认目标（等同于 build）"
