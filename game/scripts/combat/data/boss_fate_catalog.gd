extends RefCounted
class_name BossFateCatalog
## 五主 Boss 命运双选项，对齐 chapter-bridge-map

static func entry_for_flag(story_flag: StringName) -> Dictionary:
	var table := all_entries()
	return table.get(story_flag, {})


static func all_entries() -> Dictionary:
	return {
		&"ch1_guardian_fate": {
			"title": "巨阙 · 职责抉择",
			"subtitle": "守炉符文仍在跳动。释放，或保留核心。",
			"options": [
				{"id": "released", "label": "释放", "hint": "九位残影更信任你"},
				{"id": "preserved", "label": "保留", "hint": "终局提供一次防护"},
			],
		},
		&"ch2_xingtian_fate": {
			"title": "刑天 · 战烬终礼",
			"subtitle": "荣誉安放，或吸收战烬。",
			"options": [
				{"id": "honored", "label": "荣誉", "hint": "看台英魂援助"},
				{"id": "absorbed", "label": "吸收", "hint": "爆发增益，烛阴更狂"},
			],
		},
		&"ch3_nine_tails_fate": {
			"title": "九尾 · 镜中真身",
			"subtitle": "救赎残魂，或彻底封印。",
			"options": [
				{"id": "redeemed", "label": "救赎", "hint": "魂暴中安全幻身"},
				{"id": "sealed", "label": "封印", "hint": "可驱散一次幻象"},
			],
		},
		&"ch4_xuanxiao_fate": {
			"title": "玄霄 · 清醒窗",
			"subtitle": "送其飞升，或归忆人间。",
			"options": [
				{"id": "ascended", "label": "飞升", "hint": "强化重力操控"},
				{"id": "remembered", "label": "归忆", "hint": "战前提示烛阴弱点"},
			],
		},
		&"ending_state": {
			"title": "烛阴 · 终末裁决",
			"subtitle": "轮回将由你落笔。",
			"options": [
				{"id": "kindle", "label": "薪火相传", "hint": "吸收终烬，成为燃料"},
				{"id": "keeper", "label": "守炉人", "hint": "坐上烬座，永守炉心"},
				{"id": "void", "label": "大寂灭", "hint": "击碎烬座，结束轮回"},
			],
		},
		&"bridge_tea_fate": {
			"title": "桥头 · 月圆之判",
			"subtitle": "悼念的魂已围住茶摊，等你落笔。",
			"options": [
				{"id": "exposed", "label": "证伪", "hint": "揭穿贪烬鬼，渡茶救魂"},
				{"id": "mob", "label": "随波", "hint": "顺众怒封魂，吞下怒烬"},
			],
		},
	}


static func is_valid_choice(story_flag: StringName, value: String) -> bool:
	var entry: Dictionary = entry_for_flag(story_flag)
	if entry.is_empty():
		return false
	for opt in entry.get("options", []):
		if String(opt.get("id", "")) == value:
			return true
	return false
