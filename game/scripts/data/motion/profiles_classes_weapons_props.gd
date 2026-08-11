extends RefCounted
## 模型动效档案(职业 / 武器 / 装备 / 道具)——8 职业 + 12 武器 + 5 装备 + 8 道具,共 33 条。
## Schema(每条 = 一个 resolver id):
## {
##   "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": {
##     "windup_ember": Color,   # 蓄力余烬色(敌人/首领)
##     "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int },
##     "aura": Color,           # 可选:模型周围环境点光源
##   },
## }
static func profiles() -> Dictionary:
	return {
		# ───────────────────────── 玩家职业 ×8 (player/body/class_<id>) ─────────────────────────
		## Frenzied Warrior 狂战 —— 血赤怒意,低重心沉重呼吸。
		## 猩红披发 + 重剑:沉稳低频 bob + 血色光尘随行。
		"player/body/class_barbarian": {
			"movement": { "type": "bob", "amplitude": 0.06, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("e62323"),
				"ambient": { "type": "motes", "color": Color("e84040"), "count": 12 },
				"aura": Color("b32020"),
			},
		},
		## Divine Marksman 神射 —— 猎金猎装,弓弦蓄势,安静而敏锐。
		## 猎金装束:轻浅 bob(屏息)+ 金色光尘。
		"player/body/class_marksman": {
			"movement": { "type": "bob", "amplitude": 0.04, "speed": 1.9 },
			"vfx": {
				"windup_ember": Color("e8c34a"),
				"ambient": { "type": "motes", "color": Color("ffd76b"), "count": 10 },
			},
		},
		## Mystic Mage 玄法 —— 法袍玄蓝,灵识流转,星芒萦绕。
		## 玄法蓝袍:柔和 bob + 青蓝奥术光尘。
		"player/body/class_mystic": {
			"movement": { "type": "bob", "amplitude": 0.05, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("4a8bff"),
				"ambient": { "type": "motes", "color": Color("6fa8ff"), "count": 12 },
				"aura": Color("4a6dd8"),
			},
		},
		## Invocation Master 持戒 —— 僧侣金衣,戒珠持持,佛光庄严。
		## 持戒金衣:轻缓 bob + 温金微尘。
		"player/body/class_invoker": {
			"movement": { "type": "bob", "amplitude": 0.04, "speed": 1.7 },
			"vfx": {
				"windup_ember": Color("d9a835"),
				"ambient": { "type": "motes", "color": Color("e0b45c"), "count": 9 },
			},
		},
		## Yin-Yang Master 阴阳 —— 黑白道袍,阴阳二气交汇。
		## 双色道袍:bob + 银白微光(阴阳流转)。
		"player/body/class_yin_yang": {
			"movement": { "type": "bob", "amplitude": 0.05, "speed": 1.9 },
			"vfx": {
				"windup_ember": Color("cfd6e0"),
				"ambient": { "type": "motes", "color": Color("e8ecf2"), "count": 10 },
				"aura": Color("9aa4b8"),
			},
		},
		## War Shaman 战巫 —— 兽骨战衣,篝火巫祝,骨与火。
		## 战巫骨袍:厚重 bob + 暖骨火微尘。
		"player/body/class_war_shaman": {
			"movement": { "type": "bob", "amplitude": 0.06, "speed": 2.1 },
			"vfx": {
				"windup_ember": Color("ff7a1a"),
				"ambient": { "type": "motes", "color": Color("d9a862"), "count": 12 },
				"aura": Color("d97a2a"),
			},
		},
		## Arcane Archer 奥术弓 —— 符文紫弓,魔法猎手,紫电流转。
		## 符文紫衣:bob + 紫色奥术光尘。
		"player/body/class_arcane_archer": {
			"movement": { "type": "bob", "amplitude": 0.045, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("a34ae8"),
				"ambient": { "type": "motes", "color": Color("b45cff"), "count": 11 },
			},
		},
		## Asura 阿修罗 —— 暗红修罗,怒目凶煞,暗业之火。
		## 暗红修罗:沉重低频 bob + 深红暗火微尘。
		"player/body/class_asura": {
			"movement": { "type": "bob", "amplitude": 0.055, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("a1121f"),
				"ambient": { "type": "motes", "color": Color("c2272f"), "count": 13 },
				"aura": Color("8a1a1f"),
			},
		},

		# ───────────────────────── 武器 ×12 (weapon/<NN>-<name>) ─────────────────────────
		## WindHunter-Bow 追风弓 —— 风木长弓:持握静止 + 淡淡青风尘。
		"weapon/01-WindHunter-Bow": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("5fc95f"),
				"ambient": { "type": "dust", "color": Color("8fdc8f"), "count": 6 },
			},
		},
		## XingTian-Twin-Axes 刑天双斧 —— 血战双斧:持握静止 + 赤红余烬。
		"weapon/02-XingTian-Twin-Axes": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("d92626"),
				"ambient": { "type": "embers", "color": Color("e84848"), "count": 8 },
			},
		},
		## Mystic-Gate-Seal 玄门印 —— 奥术法印:持握静止 + 青蓝奥术微尘。
		"weapon/03-Mystic-Gate-Seal": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("3d7bff"),
				"ambient": { "type": "motes", "color": Color("5f9fff"), "count": 6 },
			},
		},
		## Sandalwood-Beads-Talisman 檀珠符 —— 檀香念珠符箓:持握静止 + 淡金微尘。
		"weapon/04-Sandalwood-Beads-Talisman": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("e0b23c"),
				"ambient": { "type": "motes", "color": Color("d8c87f"), "count": 5 },
			},
		},
		## Sun-Falling-Bow 落日弓 —— 落日神弓:持握静止 + 金黄日尘。
		"weapon/05-Sun-Falling-Bow": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("ffc34a"),
				"ambient": { "type": "dust", "color": Color("ffd76b"), "count": 6 },
			},
		},
		## Five-Elements-Seal 五行印 —— 五行法印:持握静止 + 五彩微尘(金)。
		"weapon/06-Five-Elements-Seal": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("ffb84a"),
				"ambient": { "type": "motes", "color": Color("e8d46b"), "count": 7 },
			},
		},
		## XingTian-Indomitable 刑天不屈 —— 刑天巨兵刃:持握静止 + 赤红余烬。
		"weapon/07-XingTian-Indomitable": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("c21919"),
				"ambient": { "type": "embers", "color": Color("d63030"), "count": 8 },
			},
		},
		## XuanXiao-Falling-Star 玄霄坠星 —— 玄霄长剑:持握静止 + 天蓝星光尘。
		"weapon/08-XuanXiao-Falling-Star": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("7fa8ff"),
				"ambient": { "type": "dust", "color": Color("a8c8ff"), "count": 6 },
			},
		},
		## ZhuYin-The-End 烛阴·终 —— 烬渊终末大刃:持握静止 + 暗赤余烬。
		"weapon/09-ZhuYin-The-End": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("e86a1a"),
				"ambient": { "type": "embers", "color": Color("c25a1a"), "count": 7 },
			},
		},
		## JuQue-Gatekeeper 句曲守门 —— 炉火门卫盾:持握静止 + 炽热余烬。
		"weapon/10-JuQue-Gatekeeper": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("ff8a26"),
				"ambient": { "type": "embers", "color": Color("ff7a2a"), "count": 8 },
			},
		},
		## NineTails-Illusion-Moon 九尾幻月 —— 九尾幻月扇:持握静止 + 紫蓝幻光微尘。
		"weapon/11-NineTails-Illusion-Moon": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("9a5cff"),
				"ambient": { "type": "motes", "color": Color("b46bff"), "count": 7 },
			},
		},
		## Weapon-Types 武器全类 —— 武器陈列架:持握静止 + 中性钢尘。
		"weapon/12-Weapon-Types": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("9aa0ab"),
				"ambient": { "type": "dust", "color": Color("b8bcc4"), "count": 5 },
			},
		},

		# ───────────────────────── 装备 ×5 (equipment/<NN>-<name>) ─────────────────────────
		## LightArmor 轻甲 —— 轻装皮甲:静止,无特效。
		"equipment/01-LightArmor": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("b8b4a8"),
				"ambient": { "type": "none", "color": Color("b8b4a8"), "count": 0 },
			},
		},
		## MediumArmor 中甲 —— 鳞甲链衫:静止,无特效。
		"equipment/02-MediumArmor": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("a8a4a0"),
				"ambient": { "type": "none", "color": Color("a8a4a0"), "count": 0 },
			},
		},
		## HeavyArmor 重甲 —— 玄铁重甲:静止,沉重无特效。
		"equipment/03-HeavyArmor": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("7a7e86"),
				"ambient": { "type": "none", "color": Color("7a7e86"), "count": 0 },
			},
		},
		## Accessories 饰物 —— 首饰挂件:静止 + 淡金微尘。
		"equipment/04-Accessories": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("d9b44a"),
				"ambient": { "type": "motes", "color": Color("e0c06b"), "count": 4 },
			},
		},
		## SoulVessels 魂器 —— 灵魂容器:静止 + 幽蓝魂光微尘。
		"equipment/05-SoulVessels": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("6fc3ff"),
				"ambient": { "type": "motes", "color": Color("8fd3ff"), "count": 6 },
				"aura": Color("4d9fd8"),
			},
		},

		# ───────────────────────── 道具 ×8 (prop/<NN>-<name>) ─────────────────────────
		## EmberShrine 余烬圣坛 —— 圣坛篝火:轻微 bob + 赤红余烬升腾。
		"prop/01-EmberShrine": {
			"movement": { "type": "bob", "amplitude": 0.03, "speed": 2.0 },
			"vfx": {
				"windup_ember": Color("ff8a26"),
				"ambient": { "type": "embers", "color": Color("ff7a26"), "count": 14 },
				"aura": Color("ff8a26"),
			},
		},
		## LostEcho 失落回响 —— 魂尘残响:轻缓 bob + 幽蓝光尘萦绕。
		"prop/02-LostEcho": {
			"movement": { "type": "bob", "amplitude": 0.04, "speed": 1.8 },
			"vfx": {
				"windup_ember": Color("6fd9ff"),
				"ambient": { "type": "motes", "color": Color("8fe0ff"), "count": 10 },
				"aura": Color("4db8e6"),
			},
		},
		## ForgeAndAnvil 熔炉铁砧 —— 锻炉火砧:静止(沉重)+ 赤红余烬喷发。
		"prop/03-ForgeAndAnvil": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("ff590d"),
				"ambient": { "type": "embers", "color": Color("ff731a"), "count": 16 },
				"aura": Color("ff6614"),
			},
		},
		## Traps 陷阱 —— 铁制陷阱:静止,无特效。
		"prop/04-Traps": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("a6aeb8"),
				"ambient": { "type": "none", "color": Color("a6aeb8"), "count": 0 },
			},
		},
		## PuzzleProps 解谜机关 —— 古机关:静止,无特效。
		"prop/05-PuzzleProps": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("9fa8c0"),
				"ambient": { "type": "none", "color": Color("9fa8c0"), "count": 0 },
			},
		},
		## AmbientProps 环境杂物 —— 坛罐陈设:静止 + 淡淡旧尘。
		"prop/06-AmbientProps": {
			"movement": { "type": "none", "amplitude": 0.0, "speed": 0.0 },
			"vfx": {
				"windup_ember": Color("c8c0b0"),
				"ambient": { "type": "dust", "color": Color("d8d0c0"), "count": 5 },
			},
		},
		## Pickups 拾取物 —— 魂火碎片:轻盈 bob + 金色微尘(闪光可拾)。
		"prop/07-Pickups": {
			"movement": { "type": "bob", "amplitude": 0.05, "speed": 2.4 },
			"vfx": {
				"windup_ember": Color("ffd76b"),
				"ambient": { "type": "motes", "color": Color("ffe08a"), "count": 8 },
				"aura": Color("e8c34a"),
			},
		},
		## BridgeTea 桥头茶摊 —— 茶具蒸腾:轻缓 bob + 温润茶雾尘。
		"prop/08-BridgeTea": {
			"movement": { "type": "bob", "amplitude": 0.03, "speed": 1.6 },
			"vfx": {
				"windup_ember": Color("e0b48a"),
				"ambient": { "type": "dust", "color": Color("e8c8a8"), "count": 6 },
			},
		},
	}
