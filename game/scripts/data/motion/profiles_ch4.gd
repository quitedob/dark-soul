extends RefCounted
## 模型动效档案(第四章·天崩)——天梯卫鬼 / 云空鹫 / 丹炉灵 / 丹道堕仙 / 书灵 / 藏书阁守灵 / 残仙遗骸。
## Schema:
## { "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": { "windup_ember": Color, "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int }, "aura": Color } }
static func profiles() -> Dictionary:
	return {
		# Stairway Guard Wraith 天梯卫鬼 — 云甲持戟: 重甲守卫 → sway + dust(云气)。
		"enemy/body/by_id/stairway_guard_wraith": {
			"movement": { "type": "sway", "amplitude": 0.05, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("#BFE8FF"),
				"ambient": { "type": "dust", "color": Color("#D6ECFF"), "count": 12 },
				"aura": Color("#9CC8E8"),
			},
		},
		# Cloud Sky Eagle 云空鹫 — 巨大飞鹰: 飞鹰 → float(大振幅) + dust(云)。
		"enemy/body/by_id/cloud_sky_eagle": {
			"movement": { "type": "float", "amplitude": 0.30, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color("#EAF6FF"),
				"ambient": { "type": "dust", "color": Color("#C9E4FF"), "count": 14 },
				"aura": Color("#A5CCE8"),
			},
		},
		# Elixir Furnace Spirit 丹炉灵 — 高大丹炉碧火: 丹炉 → bob + embers(碧火绿青)。
		"enemy/body/by_id/elixir_furnace_spirit": {
			"movement": { "type": "bob", "amplitude": 0.06, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color("#3EFF9E"),
				"ambient": { "type": "embers", "color": Color("#4BFFB8"), "count": 20 },
				"aura": Color("#2FA87F"),
			},
		},
		# Alchemy Fallen Immortal 丹道堕仙 — 袍服炼丹仙: 袍服仙 → sway + motes(经卷青蓝)。
		"enemy/body/by_id/alchemy_fallen_immortal": {
			"movement": { "type": "sway", "amplitude": 0.06, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("#6FA8FF"),
				"ambient": { "type": "motes", "color": Color("#4A7BFF"), "count": 16 },
				"aura": Color("#4E66C8"),
			},
		},
		# Book Spirit 书灵 — 悬浮典籍: 书灵 → float + motes(纸金墨蓝)。
		"enemy/body/by_id/book_spirit": {
			"movement": { "type": "float", "amplitude": 0.25, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("#FFD27F"),
				"ambient": { "type": "motes", "color": Color("#E8C47F"), "count": 14 },
				"aura": Color("#C89A5E"),
			},
		},
		# Library Guardian Spirit 藏书阁守灵 — 重甲持经剑: 重甲守卫 → sway + dust(纸尘)。
		"enemy/body/by_id/library_guardian_spirit": {
			"movement": { "type": "sway", "amplitude": 0.04, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color("#E8CFA0"),
				"ambient": { "type": "dust", "color": Color("#D8C8A8"), "count": 10 },
				"aura": Color("#B09A72"),
			},
		},
		# Broken Immortal Body 残仙遗骸 — 破碎巨躯: 残躯 → rock + dust(残灰)。
		"enemy/body/by_id/broken_immortal_body": {
			"movement": { "type": "rock", "amplitude": 0.05, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color("#A6AEBB"),
				"ambient": { "type": "dust", "color": Color("#8A8F9A"), "count": 12 },
				"aura": Color("#6E7280"),
			},
		},
	}
