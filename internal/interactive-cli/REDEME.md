📁 UI模块架构

├── 🎯 功能模块 (按一级菜单分离)
│   ├── encrypt_feature.go    # 🔒 加密功能专用
│   ├── decrypt_feature.go    # 🔓 解密功能专用  
│   ├── keygen_feature.go     # 🔑 密钥生成功能专用
│   └── config_feature.go     # ⚙️ 配置管理功能专用
│
├── 🏗️ 核心基础设施
│   ├── flow_manager.go       # 流程管理和消息分发
│   ├── view_renderers.go     # 统一的视图渲染器
│   ├── state_manager.go      # UI状态管理器
│   ├── keygen.go            # 密钥生成业务逻辑
│   └── operation_processor.go # 业务操作处理器
│
├── 🔗 兼容性桥接
│   ├── views.go             # 向后兼容的接口桥接
│   ├── menu_handlers.go     # 通用菜单处理器
│   └── interactive.go       # Bubble Tea主入口
│
└── 🛠️ 工具组件
    └── ui_utils.go          # UI工具函数