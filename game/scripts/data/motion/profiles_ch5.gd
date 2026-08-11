extends RefCounted
## 模型动效档案(占位)——由子代理逐条填写。
## Schema:
## { "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": { "windup_ember": Color, "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int }, "aura": Color } }
static func profiles() -> Dictionary:
	return {
		## Ember Shore Drifter 烬岸漂魂 —— 烬岸游荡魂,随风游荡的余烬残魂。
		## 烬岸残魂:柔和漂浮 + 昏暗橙红余烬粒子环绕;蓄力余烬为黯淡橙。
		"enemy/body/by_id/ember_shore_drifter": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color("c97a3a"),
				"ambient": { "type": "embers", "color": Color("b86a33"), "count": 10 },
				"aura": Color("a8612e"),
			},
		},
		## Inverted Guardian 倒悬守者 —— 倒吊重甲,重力扭曲的重装守卫。
		## 倒吊重甲:缓慢沉重的反重力漂浮(浮幅偏小以显沉重),紫色重力光尘悬浮。
		"enemy/body/by_id/inverted_guardian": {
			"movement": { "type": "float", "amplitude": 0.16, "speed": 1.7 },
			"vfx": {
				"windup_ember": Color("8a5fc4"),
				"ambient": { "type": "motes", "color": Color("7a55b8"), "count": 10 },
				"aura": Color("6f49ad"),
			},
		},
		## Ember Bat 烬蝠 —— 小型火蝠,快速飞掠的余烬翼兽。
		## 烬蝠:大幅快速的飞掠漂浮,炽热橙红余烬随飞洒落。
		"enemy/body/by_id/ember_bat": {
			"movement": { "type": "float", "amplitude": 0.3, "speed": 3.2 },
			"vfx": {
				"windup_ember": Color("ffa046"),
				"ambient": { "type": "embers", "color": Color("ff9142"), "count": 10 },
				"aura": Color("ff7f1f"),
			},
		},
		## Forked Path Guardian 歧路守魂 —— 岔路阴影,守据岔路的冷蓝虚影。
		## 岔路阴影:中幅浮动,冷蓝阴影光尘随行;蓄力余烬为幽蓝。
		"enemy/body/by_id/forked_path_shade": {
			"movement": { "type": "float", "amplitude": 0.22, "speed": 2.4 },
			"vfx": {
				"windup_ember": Color("6f83e0"),
				"ambient": { "type": "motes", "color": Color("7d91e8"), "count": 8 },
				"aura": Color("6478cf"),
			},
		},
		## Shadow of Possibility 可能性之影 —— 量子虚影,闪烁不定的可能态。
		## 量子虚影:较快浮动以显闪烁不定,淡紫微光粒子 shimmer,蓄力余烬淡紫。
		"enemy/body/by_id/shadow_of_possibility": {
			"movement": { "type": "float", "amplitude": 0.28, "speed": 3.0 },
			"vfx": {
				"windup_ember": Color("d9c8ff"),
				"ambient": { "type": "motes", "color": Color("c3b6f5"), "count": 12 },
				"aura": Color("b6a8ea"),
			},
		},
	}
