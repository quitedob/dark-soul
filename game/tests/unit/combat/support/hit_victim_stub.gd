# game/tests/unit/combat/support/hit_victim_stub.gd
extends CharacterBody3D
## I-05 受击桩：供 CombatArea 去重测试 double()/spy，模拟敌人 receive_hit 边界

## 直接断言伤害计数时使用
var hit_count: int = 0
## 累计伤害（receive_hit / payload 路径）
var damage_taken: float = 0.0


## 兼容旧签名：无 payload 时由 CombatArea 回退调用
func receive_hit(damage_amount, _stagger, _hit_direction, _source) -> void:
	hit_count += 1
	damage_taken += float(damage_amount)


## 标准命中载荷入口（CombatArea 优先走此路径）
func receive_hit_payload(payload: Dictionary) -> void:
	hit_count += 1
	damage_taken += float(payload.get("damage", 0.0))
