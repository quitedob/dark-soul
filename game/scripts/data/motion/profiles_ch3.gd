extends RefCounted
## Ch.3 玉障(jade-veil)敌人模型动效档案——由子代理逐条填写。
## Schema(每条 = 一个 resolver id):
## {
##   "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": {
##     "windup_ember": Color,          # 蓄力余烬色(敌人/首领)
##     "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int },
##     "aura": Color,                  # 可选:模型周围环境点光源
##   },
## }
static func profiles() -> Dictionary:
	return {
		# --- 幻蝶:荧光蝴蝶,粉尘 ---
		"enemy/body/by_id/illusion_butterfly": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color(0.65, 0.9, 1.0),
				"ambient": { "type": "dust", "color": Color(0.7, 0.85, 1.0, 0.6), "count": 8 },
				"aura": Color(0.6, 0.85, 1.0),
			},
		},
		# --- 忆盗:钩爪夺忆鬼,漂浮 ---
		"enemy/body/by_id/memory_thief": {
			"movement": { "type": "float", "amplitude": 0.22, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color(0.45, 0.5, 0.75),
				"ambient": { "type": "motes", "color": Color(0.4, 0.45, 0.7, 0.5), "count": 6 },
			},
		},
		# --- 回声灵:悬浮球体灵,青碧 ---
		"enemy/body/by_id/echo_spirit": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color(0.25, 0.75, 0.68),
				"ambient": { "type": "motes", "color": Color(0.3, 0.7, 0.65, 0.55), "count": 10 },
				"aura": Color(0.2, 0.6, 0.55),
			},
		},
		# --- 狐火灯笼:灯笼狐火,青白焰 ---
		"enemy/body/by_id/foxfire_lantern": {
			"movement": { "type": "bob", "amplitude": 0.05, "speed": 2.5 },
			"vfx": {
				"windup_ember": Color(0.6, 1.0, 0.8),
				"ambient": { "type": "embers", "color": Color(0.6, 1.0, 0.8, 0.7), "count": 12 },
				"aura": Color(0.55, 0.9, 0.75),
			},
		},
		# --- 嫁衣鬼:红嫁衣漂浮鬼 ---
		"enemy/body/by_id/wedding_gown_ghost": {
			"movement": { "type": "float", "amplitude": 0.25, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color(0.9, 0.2, 0.2),
				"ambient": { "type": "motes", "color": Color(0.85, 0.18, 0.18, 0.45), "count": 8 },
				"aura": Color(0.7, 0.15, 0.15),
			},
		},
		# --- 水中月:镜面水月幻象 ---
		"enemy/body/by_id/water_moon_spirit": {
			"movement": { "type": "float", "amplitude": 0.15, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color(0.8, 0.85, 1.0),
				"ambient": { "type": "motes", "color": Color(0.8, 0.85, 1.0, 0.5), "count": 7 },
				"aura": Color(0.75, 0.8, 1.0),
			},
		},
		# --- 镜花灵:静止花灵,辉光 ---
		"enemy/body/by_id/mirror_flower_spirit": {
			"movement": { "type": "sway", "amplitude": 0.02, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color(1.0, 0.68, 0.88),
				"ambient": { "type": "motes", "color": Color(1.0, 0.75, 0.9, 0.5), "count": 6 },
				"aura": Color(1.0, 0.7, 0.9),
			},
		},
		# --- 迷阵守者:青玉重甲,沉稳 ---
		"enemy/body/by_id/maze_guardian": {
			"movement": { "type": "rock", "amplitude": 0.05, "speed": 1.5 },
			"vfx": {
				"windup_ember": Color(0.2, 0.8, 0.6),
				"ambient": { "type": "motes", "color": Color(0.3, 0.85, 0.7, 0.35), "count": 3 },
			},
		},
		# --- 心猿狐妖:兽型狐妖 ---
		"enemy/body/by_id/mind_lost_fox_demon": {
			"movement": { "type": "sway", "amplitude": 0.05, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color(0.5, 0.9, 0.85),
				"ambient": { "type": "embers", "color": Color(0.55, 0.95, 0.85, 0.5), "count": 6 },
			},
		},
		# --- 烬贪鬼:贪焰鬼 ---
		"enemy/body/by_id/ember_greedy_ghost": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color(0.95, 0.4, 0.1),
				"ambient": { "type": "embers", "color": Color(0.95, 0.5, 0.15, 0.6), "count": 10 },
				"aura": Color(0.9, 0.4, 0.15),
			},
		},
	}
