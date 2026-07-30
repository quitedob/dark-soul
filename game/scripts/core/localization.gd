class_name AshenLocalization
extends RefCounted

const SUPPORTED_LOCALES := [&"en", &"zh_CN"]

const ZH_CN := {
	"ASHEN HOLLOW\nReach the sealed guardian beyond the ruins.": "灰烬空谷\n穿过遗迹，抵达被封印的守卫。",
	"ASHEN HOLLOW": "灰烬空谷",
	"A DELIBERATE ACTION JOURNEY": "一段审慎而致命的旅程",
	"Cross the moonlit reliquary, reclaim your embers, and break the cinder seal.": "穿越月光下的圣匣遗迹，寻回余烬，并击碎余火封印。",
	"BEGIN JOURNEY": "踏入空谷",
	"CONTINUE": "继续旅程",
	"EMBER RESTORED\nEnemies return to the hollow.": "余烬复燃\n敌人重新回到空谷。",
	"SHORTCUT OPENED": "捷径已开启",
	"LOST EMBERS RECOVERED  +%d": "失落余烬已回收  +%d",
	"RISE AGAIN": "再度起身",
	"EMBER CLAIMED  +%d": "获得余烬  +%d",
	"THE HOLLOW REMEMBERS": "空谷仍记得你",
	"CINDER GUARDIAN": "余火守卫",
	"Rest at %s": "在%s休整",
	"Kindle %s": "点燃%s",
	"Open shortcut": "开启捷径",
	"Recover lost echo": "回收失落余烬",
	"Ember Shrine": "余烬祭坛",
	"VIT": "生命",
	"END": "耐力",
	"BOSS": "首领",
	"Health": "生命值",
	"Stamina": "耐力",
	"THE RELIQUARY ENDURES": "圣匣仍在守望",
	"YOUR SCATTERED EMBERS AWAIT": "散落的余烬仍在等待",
	"ASHEN RELIQUARY UNSEALED": "灰烬圣匣已解封",
	"THE CINDER SEAL FALLS SILENT": "余火封印归于沉寂",
	"PAUSED": "已暂停",
	"THE HOLLOW WAITS": "空谷静待",
	"RESUME": "继续",
	"CONTROLS": "控制",
	"LANGUAGE": "语言",
	"ENGLISH": "English",
	"SIMPLIFIED CHINESE": "简体中文",
	"KEYBOARD & MOUSE": "键盘与鼠标",
	"MOVE": "移动",
	"LOOK": "视角",
	"MOUSE": "鼠标",
	"LIGHT ATTACK": "轻击",
	"HEAVY ATTACK": "重击",
	"DODGE": "闪避",
	"SPRINT": "疾跑",
	"INTERACT": "交互",
	"LOCK TARGET": "锁定目标",
	"CHANGE STYLE": "切换架势",
	"GUARD / PARRY": "防御 / 弹反",
	"STYLE SKILL": "架势战技",
	"CAST": "施法",
	"Esc  Pause     F1  Toggle controls": "Esc  暂停     F1  显示控制",
	"BACK": "返回",
	"LIGHT": "轻击",
	"HEAVY": "重击",
	"DODGE\nSPRINT": "闪避\n疾跑",
	"LOCK": "锁定",
	"USE": "交互",
	"FOC": "专注",
	"STYLE": "架势",
	"SKILL": "战技",
	"GUARD": "防御",
	"RELIQUARY GUARD": "圣匣守势",
	"TWIN COLOSSI": "双重巨刃",
	"CRESCENT PAIR": "双弧刃",
	"VEILCRAFT": "帷幕术法",
	"EMBER RITE": "余烬祷仪",
	"PARRY": "弹反",
	"GUARDED THRUST": "盾护突刺",
	"COLOSSAL LEAP": "双巨刃跳劈",
	"CRESCENT LEAP": "双弧刃跳劈",
	"VEIL BOLT": "帷幕飞矢",
	"EMBER RITE CAST": "余烬祷仪",
	"NOT ENOUGH FOCUS": "专注值不足",
	"NOT ENOUGH STAMINA": "耐力不足",
}


static func normalize_locale(locale: String) -> StringName:
	return &"zh_CN" if locale.to_lower().begins_with("zh") else &"en"


static func text(source: String, locale: String = "") -> String:
	# Resolve locale at call-time — default-param freezes at class-load otherwise.
	var effective_locale: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	if normalize_locale(effective_locale) == &"zh_CN":
		return String(ZH_CN.get(source, source))
	return source
