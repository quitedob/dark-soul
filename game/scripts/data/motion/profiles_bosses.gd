extends RefCounted
## Boss 模型动效档案——每个 Boss 一个独特 运动 + 视觉特效 组合。
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
		## Furnace-Keeper JuQue 炉守·炬阚 —— 熔炉闸门巨身,门缝炽光。
		## 熔炉闸门巨身:厚重低频呼吸(bob);周身橙红余烬喷涌(count 30),蓄力炽橙。
		"enemy/body/by_id/boss_giant_gate": {
			"movement": { "type": "bob", "amplitude": 0.08, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color("ff6a00"),
				"ambient": { "type": "embers", "color": Color("ff8c1a"), "count": 30 },
				"aura": Color("ff7a00"),
			},
		},
		## Blood-General XingTian 血将军·刑天 —— 无首血甲双斧,赤红。
		## 无首血甲:沉重左右摇摆(rock);周身赤红血烬飘散,蓄力为猩红。
		"enemy/body/by_id/boss_xing_tian": {
			"movement": { "type": "rock", "amplitude": 0.05, "speed": 1.4 },
			"vfx": {
				"windup_ember": Color("c80e1f"),
				"ambient": { "type": "embers", "color": Color("c4122a"), "count": 26 },
				"aura": Color("a60d1d"),
			},
		},
		## Jade-Faced Fox NineTails 玉面狐·九尾 —— 九尾玉狐,青绿狐火。
		## 九尾玉狐:大幅优雅浮动(float);青绿狐火光尘(motes)环绕,蓄力余烬为青蓝。
		"enemy/body/by_id/boss_nine_tails": {
			"movement": { "type": "float", "amplitude": 0.30, "speed": 2.2 },
			"vfx": {
				"windup_ember": Color("52ffd0"),
				"ambient": { "type": "motes", "color": Color("7fff9e"), "count": 28 },
				"aura": Color("5ee89c"),
			},
		},
		## 嗔念 WrathFragment —— 嗔怒化身,赤焰拳。
		## 嗔怒化身:急促躁动呼吸(bob);赤橙余烬随拳焰喷发,蓄力为炽烈橙红。
		"enemy/body/by_id/boss_xuan_xiao_wrath": {
			"movement": { "type": "bob", "amplitude": 0.06, "speed": 2.6 },
			"vfx": {
				"windup_ember": Color("ff4a00"),
				"ambient": { "type": "embers", "color": Color("ff6220"), "count": 28 },
				"aura": Color("ff5214"),
			},
		},
		## 执念 ObsessionFragment —— 执念法身,青蓝符文。
		## 执念法身:沉稳奥术漂浮(float);青蓝符文光尘(motes)流转,蓄力余烬为靛紫。
		"enemy/body/by_id/boss_xuan_xiao_obsession": {
			"movement": { "type": "float", "amplitude": 0.22, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("7a5cff"),
				"ambient": { "type": "motes", "color": Color("6aa0ff"), "count": 24 },
				"aura": Color("6a4ad6"),
			},
		},
		## Fallen Immortal XuanXiao 堕仙·玄霄 —— 白袍仙尊,光环天剑。
		## 白袍仙尊:庄严迟缓漂浮(float);圣洁蓝白光尘(motes)升腾,蓄力余烬为鎏金。
		"enemy/body/by_id/boss_xuan_xiao": {
			"movement": { "type": "float", "amplitude": 0.28, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color("ffd766"),
				"ambient": { "type": "motes", "color": Color("eaf4ff"), "count": 30 },
				"aura": Color("cfe6ff"),
			},
		},
		## Lord of the Ember Abyss ZhuYin 烬渊之主·烛阴 —— 最终BOSS,暗烬星辰长袍。
		## 暗烬星辰:缓慢沉重漂浮(float);暗烬余烬稀疏(count 18)垂落,星蓝 aura 光点映衬长袍,
		## 蓄力余烬由暗烬长袍爆出橙金。
		"enemy/body/by_id/boss_zhu_yin": {
			"movement": { "type": "float", "amplitude": 0.32, "speed": 1.2 },
			"vfx": {
				"windup_ember": Color("ff9a3a"),
				"ambient": { "type": "embers", "color": Color("8a4a2c"), "count": 18 },
				"aura": Color("8ab8ff"),
			},
		},
		## Blind Bell Hearer 盲钟·听烬 —— 悬垂青铜巨钟,钟舌摆荡。
		## 青铜巨钟:钟体左右摆荡(sway,振幅 0.05 如钟舌);古老铜尘(dust)弥漫,蓄力余烬鎏金。
		"enemy/body/by_id/boss_blind_bell": {
			"movement": { "type": "sway", "amplitude": 0.05, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("ffcf5e"),
				"ambient": { "type": "dust", "color": Color("b8a47a"), "count": 22 },
				"aura": Color("c9a860"),
			},
		},
	}
