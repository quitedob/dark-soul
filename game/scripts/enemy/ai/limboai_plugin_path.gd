# game/scripts/enemy/ai/limboai_plugin_path.gd
class_name LimboAIPluginPath
extends RefCounted
## G-01：LimboAI 插件落地路径与探测（无二进制时走兼容宏层）

## 官方仓库
const REPO_URL := "https://github.com/limbonaut/limboai"
## 目标安装目录（相对 game 工程）
const ADDON_DIR := "res://addons/limboai/"
## 插件入口探测文件
const PLUGIN_CFG := "res://addons/limboai/plugin.cfg"
## GDExtension 清单探测（Windows 示例；实际文件名随发布包变化）
const GDEXTENSION_HINT := "res://addons/limboai/bin/"


## 是否已安装 LimboAI 插件目录
static func is_installed() -> bool:
	return ResourceLoader.exists(PLUGIN_CFG) or DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(ADDON_DIR)
	)


## 安装说明摘要（文档 / 合约可读）
static func install_instructions() -> String:
	return "\n".join([
		"LimboAI 落地步骤：",
		"1) 从 %s 下载匹配 Godot 4.7.x 的 GDExtension 发布包" % REPO_URL,
		"2) 解压到 game/addons/limboai/（含 plugin.cfg 与 bin/）",
		"3) 项目设置启用插件；用 BTPlayer + BTBlackboard 替换 BossMacroBT.tick",
		"4) 黑板键名保持与 BossMacroBlackboard 一致，便于热切换",
		"当前无二进制时：BossMacroBT 兼容层已可验收宏意图切换。",
	])


## 返回后端标签：limboai | compat_macro
static func backend_id() -> StringName:
	return &"limboai" if is_installed() else &"compat_macro"
