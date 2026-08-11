extends RefCounted
## 召唤物与篝火神社 NPC 模型动效档案。
## Schema(每条 = 一个 resolver id):
## {
##   "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": {
##     "windup_ember": Color,   # 蓄力余烬色(仅召唤物/敌人;NPC 省略)
##     "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int },
##     "aura": Color,           # 可选:模型周围环境点光源
##   },
## }
static func profiles() -> Dictionary:
	return {
		## Summon: Dharma Child 护法灵童 —— 金身小童,手执法轮,通体金光。
		## 灵童悬浮盘坐,缓慢浮动 + 金色光尘随行;蓄力与周身均为明净金光。
		"summon/dharma_child": {
			"movement": { "type": "float", "amplitude": 0.12, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("ffd76b"),
				"ambient": { "type": "motes", "color": Color("ffe08a"), "count": 10 },
				"aura": Color("e6b84d"),
			},
		},
		## Summon: Golden Guardian 金甲力士 —— 金甲持盾握锤,沉稳厚重。
		## 厚重金甲:低频轻微 bob(甲胄呼吸)+ 金色尘埃缓缓洒落;蓄力为鎏金火。
		"summon/golden_guardian": {
			"movement": { "type": "bob", "amplitude": 0.06, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("f5b942"),
				"ambient": { "type": "motes", "color": Color("e6c06a"), "count": 8 },
				"aura": Color("c99a3d"),
			},
		},
		## Summon: Rebirth Lotus 往生莲 —— 圣洁莲花,莲心金粉飘散。
		## 圣洁莲台:缓慢轻盈浮动 + 金绿光尘(生与净的意象);蓄力为淡金青辉。
		"summon/rebirth_lotus": {
			"movement": { "type": "float", "amplitude": 0.15, "speed": 1.4 },
			"vfx": {
				"windup_ember": Color("d6e08a"),
				"ambient": { "type": "motes", "color": Color("b8c96a"), "count": 10 },
				"aura": Color("9cb04d"),
			},
		},
		## Summon: Resentful Spirit 怨灵 —— 青紫怨魂,戾气阴冷。
		## 怨魂虚体:幅度较大的飘浮 + 青紫怨尘翻涌;蓄力与周身均为幽紫怨火。
		"summon/resentful_spirit": {
			"movement": { "type": "float", "amplitude": 0.2, "speed": 2.6 },
			"vfx": {
				"windup_ember": Color("a26bff"),
				"ambient": { "type": "motes", "color": Color("7a4dc2"), "count": 10 },
				"aura": Color("6b3f9e"),
			},
		},
		## Summon: White Crane 白鹤童子 —— 白鹤持扇,风环缭绕。
		## 白鹤:轻盈起伏 float + 纯白光尘随风环旋舞;蓄力为圣洁白辉。
		"summon/white_crane": {
			"movement": { "type": "float", "amplitude": 0.12, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("e8f0ff"),
				"ambient": { "type": "motes", "color": Color("dce8ff"), "count": 9 },
				"aura": Color("b8c8e6"),
			},
		},
		## NPC: Cloud Wanderer 云游道人 —— 道袍持杖,仙风道骨。
		## 立定盘坐:极轻微 sway 呼吸起伏,素白微尘;无蓄力余烬。
		"npc/npc_cloud_wanderer": {
			"movement": { "type": "sway", "amplitude": 0.03, "speed": 1.4 },
			"vfx": {
				"ambient": { "type": "dust", "color": Color("d8d2c2"), "count": 4 },
			},
		},
		## NPC: Iron Heart 铁心 —— 铁匠,锤与熔炉,衣袍沾灰。
		## 沉稳低频 bob(重体力劳作后的呼吸);熔炉透出淡淡余烬暖光。
		"npc/npc_iron_heart": {
			"movement": { "type": "bob", "amplitude": 0.03, "speed": 1.5 },
			"vfx": {
				"ambient": { "type": "embers", "color": Color("ff7a3d"), "count": 3 },
				"aura": Color("b85a2e"),
			},
		},
		## NPC: Lady of Memories 忆姬 —— 玉簪书卷,静坐追忆。
		## 几乎静止,极轻 sway(翻阅书卷的微息);无光尘,静谧肃穆。
		"npc/npc_lady_of_memories": {
			"movement": { "type": "sway", "amplitude": 0.025, "speed": 1.3 },
			"vfx": {
				"ambient": { "type": "none", "color": Color("dfd8c8"), "count": 0 },
			},
		},
		## NPC: XuanXiao Remnant 玄霄残识 —— 残识法袍,一缕神识。
		## 残识:极轻 sway + 淡青微尘(一缕神识的气息);无蓄力余烬。
		"npc/npc_xuanxiao_remnant": {
			"movement": { "type": "sway", "amplitude": 0.035, "speed": 1.5 },
			"vfx": {
				"ambient": { "type": "dust", "color": Color("c8d6e6"), "count": 4 },
			},
		},
		## NPC: Silence Bringer 寂灭 —— 轮杖提灯,静立守寂。
		## 极致静止:仅极微 sway(提灯摇曳的呼吸);无光尘,一片寂灭。
		"npc/npc_silence_bringer": {
			"movement": { "type": "sway", "amplitude": 0.02, "speed": 1.2 },
			"vfx": {
				"ambient": { "type": "none", "color": Color("d8d0c0"), "count": 0 },
			},
		},
		## NPC: Tea Soul 茶魂 —— 桥头茶魂,一缕茶烟。
		## 茶魂:轻微 bob(茶烟升腾的节奏)+ 极淡茶褐微尘;无蓄力余烬。
		"npc/npc_bridge_tea_soul": {
			"movement": { "type": "bob", "amplitude": 0.04, "speed": 1.6 },
			"vfx": {
				"ambient": { "type": "dust", "color": Color("c8a878"), "count": 3 },
			},
		},
		## NPC: Ember Tea Keeper 烬茶倌 —— 烬烬茶倌,守一方残茶烬火。
		## 轻缓 bob + 极淡烬橙微尘(残留茶炉余温);无蓄力余烬。
		"npc/npc_ember_tea_keeper": {
			"movement": { "type": "bob", "amplitude": 0.03, "speed": 1.4 },
			"vfx": {
				"ambient": { "type": "dust", "color": Color("d9925b"), "count": 4 },
			},
		},
	}
