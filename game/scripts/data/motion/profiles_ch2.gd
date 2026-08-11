extends RefCounted
## Ch.2 血铁(blood-iron) 敌人模型动效档案。
## Schema(每条 = 一个 resolver id):
## {
##   "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": {
##     "windup_ember": Color,          # 蓄力余烬色(敌人/首领)
##     "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int },
##     "aura": Color,                  # 可选:环境光点光源
##   },
## }
static func profiles() -> Dictionary:
	return {
		"enemy/body/by_id/battle_worn_soldier": {
			"movement": { "type": "bob", "amplitude": 0.045, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("#e04b3a"),
				"ambient": { "type": "dust", "color": Color("#8a7a68"), "count": 10 },
			},
		},
		"enemy/body/by_id/war_dog_wraith": {
			"movement": { "type": "float", "amplitude": 0.18, "speed": 2.4 },
			"vfx": {
				"windup_ember": Color("#7fd4ff"),
				"ambient": { "type": "motes", "color": Color("#8fd8ff"), "count": 14 },
				"aura": Color("#5aa9e6"),
			},
		},
		"enemy/body/by_id/camp_guard_wraith": {
			"movement": { "type": "float", "amplitude": 0.15, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("#9fe3ff"),
				"ambient": { "type": "motes", "color": Color("#a5d8ff"), "count": 12 },
				"aura": Color("#6fb6e8"),
			},
		},
		"enemy/body/by_id/torture_device_spirit": {
			"movement": { "type": "bob", "amplitude": 0.03, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color("#d97b3c"),
				"ambient": { "type": "dust", "color": Color("#5c5148"), "count": 8 },
			},
		},
		"enemy/body/by_id/generals_personal_guard": {
			"movement": { "type": "rock", "amplitude": 0.035, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("#a8322c"),
				"ambient": { "type": "dust", "color": Color("#7c6f66"), "count": 9 },
			},
		},
		"enemy/body/by_id/beacon_keeper_wraith": {
			"movement": { "type": "float", "amplitude": 0.16, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color("#ff9a2a"),
				"ambient": { "type": "embers", "color": Color("#ffb84d"), "count": 20 },
				"aura": Color("#ff8c1a"),
			},
		},
	}
