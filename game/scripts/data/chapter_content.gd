class_name ChapterContentData
extends RefCounted
## Master content aggregator for all 5 chapters of 烬渊 (Ember Abyss).
## Delegates to per-chapter data classes — add a new enemy/boss/spell/weapon
## by editing only the relevant chapter file.
##
## Chapter files:
##   Chapter1Content — 灵墟·觉醒 (Spirit Ruins)
##   Chapter2Content — 血铁·战歌 (Blood & Iron)
##   Chapter3Content — 玉障·迷心 (Jade Veil)
##   Chapter4Content — 天崩·陨落 (Celestial Fall)
##   Chapter5Content — 烬座·归墟 (Throne of Ashes)


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 1 — 灵墟·觉醒 (Spirit Ruins · Awakening)
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_1_enemies() -> Array[Dictionary]:
	return Chapter1Content.enemies()

static func chapter_1_elites() -> Array[Dictionary]:
	return Chapter1Content.elites()

static func chapter_1_boss() -> Dictionary:
	return Chapter1Content.boss()

static func chapter_1_spells() -> Array[Dictionary]:
	return Chapter1Content.spells()

static func chapter_1_weapons() -> Array[Dictionary]:
	return Chapter1Content.weapons()

static func chapter_1_scene() -> Dictionary:
	return Chapter1Content.scene()


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 2 — 血铁·战歌 (Blood & Iron · Warsong)
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_2_enemies() -> Array[Dictionary]:
	return Chapter2Content.enemies()

static func chapter_2_elites() -> Array[Dictionary]:
	return Chapter2Content.elites()

static func chapter_2_boss() -> Dictionary:
	return Chapter2Content.boss()

static func chapter_2_spells() -> Array[Dictionary]:
	return Chapter2Content.spells()

static func chapter_2_weapons() -> Array[Dictionary]:
	return Chapter2Content.weapons()

static func chapter_2_scene() -> Dictionary:
	return Chapter2Content.scene()


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 3 — 玉障·迷心 (Jade Veil · Lost Mind)
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_3_enemies() -> Array[Dictionary]:
	return Chapter3Content.enemies()

static func chapter_3_elites() -> Array[Dictionary]:
	return Chapter3Content.elites()

static func chapter_3_boss() -> Dictionary:
	return Chapter3Content.boss()

static func chapter_3_spells() -> Array[Dictionary]:
	return Chapter3Content.spells()

static func chapter_3_weapons() -> Array[Dictionary]:
	return Chapter3Content.weapons()

static func chapter_3_scene() -> Dictionary:
	return Chapter3Content.scene()


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 4 — 天崩·陨落 (Celestial Fall)
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_4_enemies() -> Array[Dictionary]:
	return Chapter4Content.enemies()

static func chapter_4_elites() -> Array[Dictionary]:
	return Chapter4Content.elites()

static func chapter_4_bosses() -> Array[Dictionary]:
	return Chapter4Content.bosses()

static func chapter_4_spells() -> Array[Dictionary]:
	return Chapter4Content.spells()

static func chapter_4_weapons() -> Array[Dictionary]:
	return Chapter4Content.weapons()

static func chapter_4_scene() -> Dictionary:
	return Chapter4Content.scene()


# ═══════════════════════════════════════════════════════════════════════════
# CHAPTER 5 — 烬座·归墟 (Throne of Ashes · Return to Void)
# ═══════════════════════════════════════════════════════════════════════════

static func chapter_5_enemies() -> Array[Dictionary]:
	return Chapter5Content.enemies()

static func chapter_5_elites() -> Array[Dictionary]:
	return Chapter5Content.elites()

static func chapter_5_boss() -> Dictionary:
	return Chapter5Content.boss()

static func chapter_5_spells() -> Array[Dictionary]:
	return Chapter5Content.spells()

static func chapter_5_weapons() -> Array[Dictionary]:
	return Chapter5Content.weapons()

static func chapter_5_scene() -> Dictionary:
	return Chapter5Content.scene()
