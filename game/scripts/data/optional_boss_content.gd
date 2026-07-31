class_name OptionalBossContent
extends RefCounted
## 可选隐藏 Boss:盲钟·听烬 (The Blind Bell · Hearer of Embers)
## 精（器物成精）· 独立定位 —— 不承接章节主线，不写命运旗标，可致死击杀。
## 唯一核心机制：声音与静默（Boss 全盲，以声辨位）。
## 招式 type 仅复用 game/scripts/boss/boss_attack_executor.gd 已执行的值
## （radial_aoe / status / teleport_after 命中 default 计时近战，安全）。


static func boss() -> Dictionary:
	return {
		"id": "boss_blind_bell",
		"display_name": "盲钟·听烬 / The Blind Bell · Hearer of Embers",
		"max_health": 520.0, "reward": 420,
		"arena": "hidden_belltower",
		"chapter": 5, "chinese_name": "听烬",
		"phases": {
			"1": {
				"threshold": 1.0,
				"description": "听者 · 以声辨位",
				"attacks": [
					# 听声扑袭 (Hearing Lunge) —— 升调独响 + 钟身向声源倾俯
					{"name": "hearing_lunge", "windup": 0.9, "active": 0.4, "recovery": 1.6, "damage": 28.0, "stagger": 34.0, "lunge": 3.6, "heavy": true},
					# 钟舌横扫 (Tongue Sweep) —— 铁链咯吱 + 钟舌 180° 弧扫
					{"name": "tongue_sweep", "windup": 1.1, "active": 0.5, "recovery": 1.2, "damage": 22.0, "stagger": 26.0, "lunge": 0.0, "heavy": false},
					# 千耳振 (Chime Burst) —— 急促颤音 + 音浪环（径向 AoE）
					{"name": "chime_burst", "windup": 1.6, "active": 0.6, "recovery": 2.0, "damage": 18.0, "stagger": 30.0, "lunge": 0.0, "heavy": true, "type": "radial_aoe", "range": 5.0},
					# 回声步 (Echo Shift) —— 一声叮回弹，荡向声源，无伤害
					{"name": "echo_shift", "windup": 0.7, "active": 0.0, "recovery": 0.9, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "heavy": false, "type": "teleport_after"},
				],
				"vfx": "sound_ring_pulses",
				"lighting": "moonlight_through_arrow_slits",
			},
			"2": {
				"threshold": 0.55,
				"description": "聋世 · 黑暗中的声音",
				"attacks": [
					# 无声钟舌 (Silent Tongue) —— 双段快刺（count/hits 元数据）
					{"name": "silent_tongue", "windup": 0.5, "active": 0.3, "recovery": 1.0, "damage": 20.0, "stagger": 20.0, "lunge": 2.2, "heavy": false, "count": 2, "hits": 2},
					# 沉钟横扫 (Deep Sweep) —— 低长轰鸣 + 地面大弧扫（带硬直）
					{"name": "deep_sweep", "windup": 0.9, "active": 0.5, "recovery": 1.4, "damage": 26.0, "stagger": 34.0, "lunge": 0.0, "heavy": true},
					# 三响冲锋 (Triple Toll Charge) —— 横穿全场冲锋（大 lunge）
					{"name": "triple_toll_charge", "windup": 0.7, "active": 0.6, "recovery": 1.8, "damage": 32.0, "stagger": 38.0, "lunge": 6.0, "heavy": true},
					# 摄魂鸣 (Soul-Drain Toll) —— 低频长鸣持续汲取（status 型，12m 半径）
					{"name": "soul_drain_toll", "windup": 1.2, "active": 0.5, "recovery": 2.2, "damage": 0.0, "stagger": 0.0, "lunge": 0.0, "heavy": false, "type": "status", "effect": "soul_drain", "range": 12.0},
					# 钟舌绞杀 (Tongue Strangulation) —— 链条甩出拖拽
					{"name": "tongue_strangulation", "windup": 0.8, "active": 0.5, "recovery": 2.2, "damage": 24.0, "stagger": 30.0, "lunge": 1.6, "heavy": true},
				],
				"vfx": "ember_glow_in_silence",
				"lighting": "darkness_ember_only",
			},
		},
		"vfx_unique": {
			"intro": "bell_slow_toll",
			"death": "last_toll_silence",
			"hit": "bronze_ring_sparks",
			"arena": "hanging_bells_circumference",
			"ground_effect": "prayer_slate_runes",
		},
		"body_type": "hanging_bell",
		"weapon_shape": "bell_tongue",
		"body_color": "7a6a4a", "weapon_color": "c8a050", "eye_emission": "ffcc44",
		"weak_point": "bell_mouth",
	}
