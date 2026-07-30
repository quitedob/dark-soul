# Godot MCP Native — 安装与测试报告

**日期:** 2026-07-30
**状态:** ✅ 已验证可用
**插件版本:** 1.0.8
**Godot 版本:** 4.7.1.stable.official.a13da4feb

---

## 1. 安装步骤

### 1.1 克隆仓库

```bash
mkdir -p mcp
cd mcp
git clone https://github.com/yurineko73/Godot-MCP-Native .
```

仓库位置: `E:\godot\darksoul\mcp\`

### 1.2 安装插件到游戏项目

```bash
cp -r mcp/addons/godot_mcp game/addons/godot_mcp
```

### 1.3 启用插件

在 `game/project.godot` 中添加:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")

[autoload]
MCPRuntimeProbe="*res://addons/godot_mcp/runtime/mcp_runtime_probe.gd"
```

### 1.4 安装 CLI 工具

Windows 预构建二进制下载:

```bash
cd mcp/cli/gdmcp
curl -L -o gdmcp.zip \
  "https://github.com/yurineko73/Godot-MCP-Native/releases/download/v1.0.8/gdmcp-1.0.8-x86_64-pc-windows-msvc.zip"
unzip -o gdmcp.zip
```

CLI 位置: `E:\godot\darksoul\mcp\cli\gdmcp\gdmcp.exe` (4.7 MB)

---

## 2. 测试结果

### 2.1 启动 Godot MCP 服务器

```bash
E:\godot\Godot_v4.7.1-stable_win64_console.exe \
  --headless --editor \
  --path "E:\godot\darksoul\game" \
  -- --mcp-server
```

**结果:** ✅ 启动成功，编辑器初始化完成，MCP 服务器监听 `http://127.0.0.1:9080`

### 2.2 `gdmcp doctor` — 连接状态检查

```bash
$ gdmcp.exe --json doctor
```

```json
{
  "api_version": 1,
  "auth": {"required": false, "source": "localhost"},
  "catalog_hash": "6e83d737e85a83a50f93542341393760927401d6901b651a6b28eeeb94e87bd9",
  "editor_connected": true,
  "godot_version": "4.7.1-stable (official)",
  "plugin_version": "1.0.8",
  "project_path": "E:/godot/darksoul/game/",
  "runtime_running": false,
  "schema_version": 1
}
```

| 字段 | 值 | 状态 |
|------|-----|------|
| `editor_connected` | `true` | ✅ |
| `godot_version` | `4.7.1-stable (official)` | ✅ |
| `plugin_version` | `1.0.8` | ✅ |
| `project_path` | `E:/godot/darksoul/game/` | ✅ |
| `auth.required` | `false` (localhost) | ✅ |
| `runtime_running` | `false` (编辑器模式) | ✅ 正常 |

### 2.3 `get_editor_screenshot` — 场景截图

```bash
$ gdmcp.exe --json tool-call get_editor_screenshot --args-json '{}'
```

**截图输出路径规则:**
- ✅ 所有截图统一存放在 **仓库根目录的 `screenshot/`** 下
- ❌ 禁止将截图散放在 `game/`、`docs/` 或其他任意目录
- 📁 可按日期创建子目录，如 `screenshot/2026-07-30/`

详见 [`project-structure.md`](project-structure.md) § `screenshot/`

### 2.4 `scenes current` — 当前场景信息

```bash
$ gdmcp.exe --json scenes current
```

```json
{
  "ok": true,
  "data": {
    "scene_name": "Main",
    "scene_path": "res://main.tscn",
    "node_count": 2,
    "root_node_type": "Node",
    "is_modified": false
  }
}
```

**结果:** ✅ 正确读取 `main.tscn` 场景信息

### 2.4 `get_project_info` — 项目信息

```bash
$ gdmcp.exe --json tool-call get_project_info --args-json "{}"
```

```json
{
  "ok": true,
  "data": {
    "project_name": "Ashen Hollow",
    "godot_version": "4.7.stable",
    "main_scene": "res://main.tscn",
    "project_path": "E:/godot/darksoul/game/"
  }
}
```

**结果:** ✅ 正确返回项目元数据

### 2.5 `list_project_scripts` — 脚本清单

```bash
$ gdmcp.exe --json tool-call list_project_scripts --args-json "{}"
```

```json
{
  "ok": true,
  "data": {
    "count": 50,
    "scripts": [
      "res://addons/godot_mcp/mcp_server_native.gd",
      "res://addons/godot_mcp/native_mcp/cli_api_handler.gd",
      "res://addons/godot_mcp/native_mcp/config_manager.gd",
      "res://addons/godot_mcp/native_mcp/mcp_auth_manager.gd",
      "res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd",
      "res://addons/godot_mcp/native_mcp/mcp_http_server.gd",
      "... (50 scripts total)"
    ]
  }
}
```

**结果:** ✅ 检测到 50 个脚本（包括 MCP 插件自身的所有脚本 + 游戏脚本）

---

## 3. CLI 命令速查

### 基础命令

| 命令 | 用途 |
|------|------|
| `gdmcp --json doctor` | 检查连接状态 |
| `gdmcp --json tools catalog` | 列出所有可用工具（概览） |
| `gdmcp --json tools search "<关键词>"` | 搜索工具 |
| `gdmcp --json tools schema <工具名>` | 查看工具完整 schema |
| `gdmcp --json tool-call <工具名> --args-json "{}"` | 直接调用工具 |

### 领域命令 (~33 个)

| 命令组 | 示例 |
|--------|------|
| **scenes** | `gdmcp --json scenes current` |
| **nodes** | `gdmcp --json nodes list --path "."` |
| **scripts** | `gdmcp --json scripts read --path "res://scripts/player/player.gd"` |
| **resources** | `gdmcp --json resources list` |
| **project** | `gdmcp --json project info` |
| **editor** | `gdmcp --json editor state` |
| **debug** | `gdmcp --json debug logs` |
| **runtime** | `gdmcp --json runtime info` (需要游戏运行中) |
| **batch** | `gdmcp --json batch preview --file tasks.json` |

### 全局参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--url <URL>` | MCP 服务器地址 | `http://127.0.0.1:9080` |
| `--token-env <ENV>` | Bearer token 环境变量名 | — |
| `--timeout <MS>` | 请求超时（毫秒） | — |
| `--json` | JSON 格式输出 | — |

---

## 4. 已知问题

### 4.1 引擎关闭时的无害报错

Godot 编辑器在 headless 模式下退出时会产生以下报错，**不影响功能**:

```
ERROR: BUG: Unreferenced static string to 0: _enter_world
ERROR: 7 RID allocations of type '23NavMeshGeometryParser3D' were leaked at exit.
WARNING: A Thread object is being destroyed without its completion having been realized.
```

这些是 Godot 4.7.1 引擎在 headless 模式下的已知无害报错，不是 MCP 插件问题。

### 4.2 Runtime 功能需游戏正在运行

`runtime_running: false` 是正常的 — 编辑器模式下游戏未启动。需要调用 `gdmcp editor run` 或通过 `run_project` 工具启动游戏后，runtime 相关功能才可用。

### 4.3 认证

默认仅允许 localhost 连接，无需认证 (`auth.required: false`)。如需远程访问，在 MCP 面板中启用 `auth_enabled` 并设置 `auth_token`。

---

## 5. 故障排查

| 问题 | 解决方案 |
|------|----------|
| `SERVICE_UNREACHABLE` | 确认 Godot 编辑器已启动且带 `-- --mcp-server` 参数 |
| `401 Unauthorized` | 检查 `--token-env` 或请求头中的 Bearer token |
| 端口冲突 | 使用 `--mcp-port=19081` 覆盖端口 + CLI `--url http://127.0.0.1:19081` |
| CLI 连接超时 | 增加 `--timeout 30000`，或检查防火墙 |

---

## 6. 与外部 AI 工具集成

### Claude Desktop

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:9080/mcp"]
    }
  }
}
```

### Cursor / Trae

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

### Cline

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "type": "streamableHttp",
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

---

## 7. 插件文件结构

```
game/addons/godot_mcp/
├── plugin.cfg                    # 插件配置 (name, version, script entry)
├── mcp_server_native.gd          # 插件主入口 (EditorPlugin)
├── native_mcp/                   # 核心 MCP 引擎
│   ├── mcp_server_core.gd        # 服务器核心逻辑
│   ├── mcp_http_server.gd        # HTTP 传输层
│   ├── mcp_stdio_server.gd       # Stdio 传输层
│   ├── mcp_auth_manager.gd       # 认证管理
│   ├── config_manager.gd         # 配置持久化
│   ├── tool_registry.gd          # 工具注册中心
│   ├── tool_executor.gd          # 工具执行引擎
│   ├── mcp_debugger_bridge.gd    # 调试器桥接
│   ├── mcp_resource_manager.gd   # 资源管理
│   ├── cli_api_handler.gd        # CLI API 端点
│   └── ...
├── tools/                        # 工具实现
│   ├── node_tools_native.gd      # 节点 CRUD
│   ├── scene_tools_native.gd     # 场景管理
│   ├── script_tools_native.gd    # 脚本编辑/分析
│   ├── debug_tools_native.gd     # 调试工具 (~68 个)
│   ├── editor_tools_native.gd    # 编辑器控制
│   ├── project_tools_native.gd   # 项目管理
│   └── resource_tools_native.gd  # 资源操作
├── runtime/
│   └── mcp_runtime_probe.gd      # 运行时探针 (autoload)
├── ui/                           # 编辑器面板
├── utils/                        # 辅助工具类
└── translations/                 # 本地化
```

---

## 8. 参考链接

- 仓库: https://github.com/yurineko73/Godot-MCP-Native
- 完整工具参考: `mcp/docs/current/tools-reference.md`
- CLI 参考: `mcp/docs/current/gdmcp-cli-reference.md`
- 架构设计: `mcp/docs/current/architecture.md`
