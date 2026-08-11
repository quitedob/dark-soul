extends RefCounted
## Ch.1 敌人模型动效档案(占位)——由子代理逐条填写。
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
		## Lost Soul Soldier 迷失魂兵 —— 持剑残兵,尘埃破旧。
		## 破旧残兵:轻微呼吸起伏(bob)+ 淡淡尘埃粒子;剑上蓄力余烬为黯淡橙红。
		"enemy/body/by_id/lost_soul_soldier": {
			"movement": { "type": "bob", "amplitude": 0.05, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("d98f3d"),
				"ambient": { "type": "dust", "color": Color("9e8f80"), "count": 8 },
			},
		},
		## Temple Guardian Warrior 庙守战士 —— 苔藓石甲重剑,静止威压。
		## 厚重石甲:几乎静止,仅极轻微的 sway 沉稳呼吸;苔藓微尘弥漫。
		"enemy/body/by_id/temple_guardian_warrior": {
			"movement": { "type": "sway", "amplitude": 0.02, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color("c9a853"),
				"ambient": { "type": "dust", "color": Color("6f8c73"), "count": 5 },
			},
		},
		## Mirror Shade 镜影 —— 幽灵镜灵,虚体浮动,青光。
		## 虚体幽灵:大幅浮动 + 青色光尘;蓄力与周身均为冷青光。
		"enemy/body/by_id/mirror_shade": {
			"movement": { "type": "float", "amplitude": 0.18, "speed": 2.4 },
			"vfx": {
				"windup_ember": Color("66ccff"),
				"ambient": { "type": "motes", "color": Color("6fd9ff"), "count": 10 },
				"aura": Color("4db8e6"),
			},
		},
		## Furnace Slag Beast 炉渣怪 —— 熔炉兽,赤红裂口,余烬。
		## 熔炉兽:厚重低频 bob + 赤红余烬粒子喷发;蓄力为炽热橙红。
		"enemy/body/by_id/furnace_slag_beast": {
			"movement": { "type": "bob", "amplitude": 0.07, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color("ff590d"),
				"ambient": { "type": "embers", "color": Color("ff731a"), "count": 12 },
				"aura": Color("ff6614"),
			},
		},
		## Ember Shade Skirmisher 烬影伏击者 —— 远程烬影,飘忽。
		## 飘忽远程烬影:大幅快速浮动,橙烬光尘随行,蓄力余烬明亮。
		"enemy/body/by_id/ember_shade_skirmisher": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.8 },
			"vfx": {
				"windup_ember": Color("ff8a26"),
				"ambient": { "type": "motes", "color": Color("ff9966"), "count": 8 },
				"aura": Color("e68a4d"),
			},
		},
	}
